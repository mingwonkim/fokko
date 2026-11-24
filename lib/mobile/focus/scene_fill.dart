// lib/mobile/focus/scene_fill.dart
// 집중 중 화면 전체 변화: 바다 속 파도 · 숲이 물들며 자람 · 밤 해질녘에서 우주로 · 일상 아이스 아메리카노.
// 높이는 남은 시간(시계)에서만 나온다. 움직임은 약 24fps로 제한하고 앱이 안 보이면 멈춘다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_tokens.dart';

/// 수면 y. p=0이면 화면 바닥이라 시작하자마자 보이고, p=1이면 화면 위로 [overshoot]만큼
/// 넘겨 물결 골이 비지 않는다. [overshoot]는 물결 폭만큼만 — 크면 끝나기 전에 가득 찬다.
double fillSurfaceY(double height, double p, {double overshoot = 0}) =>
    height - p.clamp(0.0, 1.0) * (height + overshoot);

class SceneFill extends StatefulWidget {
  const SceneFill({
    super.key,
    required this.scene,
    required this.progress,
    this.animate = true,
  });

  final FocusScene scene;
  final double progress; // 0 비었음 → 1 가득
  final bool animate;

  @override
  State<SceneFill> createState() => _SceneFillState();
}

class _SceneFillState extends State<SceneFill> with WidgetsBindingObserver {
  final _time = ValueNotifier<double>(0);
  final _watch = clock.stopwatch();
  Timer? _timer;
  bool _visible = true;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(SceneFill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run = widget.animate && _visible && !_reduce;
    if (run && _timer == null) {
      _watch.start();
      _timer = Timer.periodic(FillMotion.frame, (_) {
        _time.value = _watch.elapsedMilliseconds / 1000;
      });
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _watch.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: SceneFillPainter(
                scene: widget.scene, progress: widget.progress, time: _time),
          ),
        ),
      );
}

class SceneFillPainter extends CustomPainter {
  SceneFillPainter(
      {required this.scene, required this.progress, required this.time})
      : super(repaint: time);

  final FocusScene scene;
  final double progress;
  final ValueListenable<double> time;

  // 별 고정 좌표 (x 비율, y 비율). 앞쪽 몇 개는 빛나는 큰 별.
  static final _stars = [
    for (var i = 0; i < FillMotion.starCount; i++)
      ((i * 0.754877 + 0.11) % 1.0, (i * 0.569840 + 0.05) % 1.0)
  ];

  // 물고기 (길이 1 기준, 머리가 오른쪽)
  static final _fish = Path()
    ..addOval(Rect.fromCenter(center: Offset.zero, width: 2, height: 0.9))
    ..addPolygon(
        const [Offset(-0.8, 0), Offset(-1.5, -0.5), Offset(-1.5, 0.5)], true);

  // 뾰족한 나무 (높이 1 기준, 뿌리가 원점). 오른쪽 절반은 그늘.
  static final _pine = Path()
    ..addPolygon(const [
      Offset(0, -1.06),
      Offset(0.2, -0.72),
      Offset(0.12, -0.72),
      Offset(0.28, -0.46),
      Offset(0.17, -0.46),
      Offset(0.36, -0.18),
      Offset(-0.36, -0.18),
      Offset(-0.17, -0.46),
      Offset(-0.28, -0.46),
      Offset(-0.12, -0.72),
      Offset(-0.2, -0.72),
    ], true);
  static final _pineShade = Path()
    ..addPolygon(const [
      Offset(0, -1.06),
      Offset(0.2, -0.72),
      Offset(0.12, -0.72),
      Offset(0.28, -0.46),
      Offset(0.17, -0.46),
      Offset(0.36, -0.18),
      Offset(0, -0.18),
    ], true);

  /// 0~1 고정 난수 (같은 나무는 항상 같은 값)
  static double _hash(int a, int b) {
    final v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final s = scene.style;
    switch (scene) {
      case FocusScene.ocean:
        _ocean(canvas, size, t, s);
      case FocusScene.forest:
        _forest(canvas, size, t, s);
      case FocusScene.night:
        _night(canvas, size, t, s);
      case FocusScene.daily:
        _coffee(canvas, size, t, s);
    }
  }

  Path _wave(Size size, double y, double amp, double phase, double k) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, y + amp * math.sin(phase));
    const step = 8.0;
    for (var x = step; x < size.width + step; x += step) {
      path.lineTo(x, y + amp * math.sin(k * x + phase));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  /// 바다·커피 공통 출렁임: 뒤 물결 + 앞 물결 + 앞 물결 머리의 밝은 선
  void _swell(Canvas c, Size size, double t, double y, Paint back, Paint front,
      Color crestColor) {
    final k = 2 * math.pi / size.width;
    final b = 2 * math.pi * t / FillMotion.waveBackPeriod;
    final f = 2 * math.pi * t / FillMotion.waveFrontPeriod;
    c.drawPath(_wave(size, y - 8, FillMotion.waveBackAmp, b, k * 1.2), back);
    c.drawPath(_wave(size, y + 6, FillMotion.waveFrontAmp, -f, k * 1.7), front);
    final crest = Path();
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      final py = y + 6 + FillMotion.waveFrontAmp * math.sin(k * 1.7 * x - f);
      x == 0 ? crest.moveTo(x, py) : crest.lineTo(x, py);
    }
    c.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = crestColor);
  }

  /// 위는 밝고 깊을수록 짙은 물 + 먼 물결 + 빛줄기 + 물고기 떼 + 올라오는 기포
  void _ocean(Canvas c, Size size, double t, SceneStyle s) {
    final y = fillSurfaceY(size.height, progress,
        overshoot: FillMotion.waveOvershoot);
    final k = 2 * math.pi / size.width;
    c.drawPath(
        _wave(size, y - 14, FillMotion.waveBackAmp * 0.7,
            2 * math.pi * t / FillMotion.waveFarPeriod, k * 0.8),
        Paint()..color = s.fill.withValues(alpha: 0.45));
    _swell(
        c,
        size,
        t,
        y,
        Paint()..color = s.fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.fillDeep, Color.lerp(s.fillDeep, s.fillShade, 0.75)!],
          ).createShader(Rect.fromLTRB(0, y, size.width, size.height + 1)),
        s.fillCrest);
    final depth = size.height - y;
    if (depth < 24) return;

    // 수면 아래에서만 보이게 앞 물결 모양으로 자른다
    c.save();
    c.clipPath(_wave(size, y + 6, FillMotion.waveFrontAmp,
        -2 * math.pi * t / FillMotion.waveFrontPeriod, k * 1.7));

    final rayEnd = y + depth * 0.7;
    final ray = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          s.fillCrest.withValues(alpha: 0.24),
          s.fillCrest.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(0, y, size.width, rayEnd));
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.14 + 0.25 * i) +
          18 * math.sin(2 * math.pi * t / FillMotion.rayPeriod + i * 1.7);
      c.drawPath(
          Path()
            ..addPolygon([
              Offset(x - 16, y),
              Offset(x + 16, y),
              Offset(x + 54, rayEnd),
              Offset(x - 26, rayEnd),
            ], true),
          ray);
    }

    final fish = Paint()..color = s.fillShade.withValues(alpha: 0.42);
    const schools = [(0.56, 1.0, 11.0), (0.34, -1.0, 8.0), (0.82, -1.0, 13.0)];
    final span = size.width + 120;
    for (var j = 0; j < schools.length; j++) {
      final (fy, dir, len) = schools[j];
      for (var i = 0; i < 5; i++) {
        final run = (t * FillMotion.fishSpeed * (1 + j * 0.2) + j * 137 + i * 26) % span;
        final x = dir > 0 ? run - 60 : size.width + 60 - run;
        final py = size.height * fy +
            (i.isOdd ? 12.0 : -10.0) * (1 + i * 0.3) +
            4 * math.sin(t * 0.7 + i + j);
        c.save();
        c.translate(x, py);
        c.scale(dir * len * (0.8 + 0.06 * i), len * (0.8 + 0.06 * i));
        c.drawPath(_fish, fish);
        c.restore();
      }
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = s.fillCrest.withValues(alpha: 0.6);
    final glint = Paint()..color = s.fillCrest.withValues(alpha: 0.85);
    for (var i = 0; i < FillMotion.bubbleCount; i++) {
      final speed = FillMotion.bubbleSpeed * (0.7 + 0.6 * _hash(i, 3));
      final rise = (t * speed + _hash(i, 1) * size.height) % depth;
      final r = 2.5 + 5 * _hash(i, 2);
      final at = Offset(
          _hash(i, 4) * size.width + 7 * math.sin(t * 0.9 + i),
          size.height - rise);
      c.drawCircle(at, r, ring);
      c.drawCircle(at + Offset(-r * 0.35, -r * 0.35), r * 0.22, glint);
    }
    c.restore();
  }

  /// 먼 언덕 + 땅 위로 먼 줄부터 그려 가까운 나무가 덮는다. 나무는 아래 줄부터 차례로,
  /// 연한 색에서 진한 색으로 물들며 자란다. 땅 위로 꽃가루와 낙엽이 떠다닌다.
  void _forest(Canvas c, Size size, double t, SceneStyle s) {
    final unit = size.width / 402;
    final sway = FillMotion.treeSwayDeg *
        math.pi /
        180 *
        math.sin(2 * math.pi * t / FillMotion.treeSwayPeriod);
    // 땅도 함께 차오르고 짙어진다
    final ground = fillSurfaceY(size.height, progress, overshoot: 8);
    final k = 2 * math.pi / size.width;
    c.drawPath(_wave(size, ground - 26, 14, 1.8, k * 0.7),
        Paint()..color = s.fill.withValues(alpha: 0.5));
    final soil = Color.lerp(s.fill, s.fillShade, progress)!;
    c.drawPath(
        _wave(size, ground, 8, 0.6, k),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(soil, s.fill, 0.45)!, soil],
          ).createShader(Rect.fromLTRB(0, ground, size.width, size.height + 1)));
    const rows = FillMotion.forestRows;
    for (var r = rows - 1; r >= 0; r--) {
      final fy = r / (rows - 1); // 0 맨 아래 → 1 맨 위
      final h = (FillMotion.treeNear +
              (FillMotion.treeFar - FillMotion.treeNear) * fy) *
          unit;
      final cols = 4 + (fy * 2).round();
      for (var i = 0; i <= cols; i++) {
        final jitter = _hash(r, i);
        // 마지막 줄도 진행 1에서 다 자란다
        final start = fy * (0.96 - FillMotion.treeGrow) + jitter * 0.04;
        final grow = ((progress - start) / FillMotion.treeGrow).clamp(0.0, 1.0);
        if (grow <= 0) continue;
        final x = (i + (r.isOdd ? 0.5 : 0.0) + (jitter - 0.5) * 0.4) /
            cols *
            size.width;
        // 먼 줄은 밝게, 가까운 줄은 짙게. 처음엔 연한 색으로 시작한다.
        final target = Color.lerp(
            s.fillDeep, s.fillShade, (1 - fy) * 0.75 + jitter * 0.25)!;
        // 맨 위 줄도 잎이 화면 안에 들어오도록 뿌리를 내린다
        final root = Offset(
            x,
            size.height * (1 - fy) +
                h * (0.12 + 0.6 * fy) +
                (jitter - 0.5) * 16 * unit);
        _tree(c, root, h * (0.25 + 0.75 * grow), sway * (0.6 + jitter),
            Color.lerp(s.fill, target, grow)!, s, grow, pine: _hash(i, r + 9) < 0.3);
      }
    }
    final depth = size.height - ground;
    if (depth < 40) return;
    final pollen = Paint();
    for (var i = 0; i < FillMotion.pollenCount; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(t * 1.3 + i * 2.1);
      pollen.color = s.fillCrest.withValues(alpha: 0.25 + 0.55 * twinkle);
      c.drawCircle(
          Offset(_hash(i, 5) * size.width + 16 * math.sin(t * 0.4 + i),
              ground + _hash(i, 6) * depth - 6 * math.sin(t * 0.3 + i * 2)),
          1.4 + 1.6 * _hash(i, 7),
          pollen);
    }
    final leaf = Paint()..color = Color.lerp(s.fillCrest, s.fillDeep, 0.35)!;
    for (var i = 0; i < FillMotion.leafCount; i++) {
      final fall = (t * FillMotion.leafSpeed * (0.8 + 0.4 * _hash(i, 8)) +
              _hash(i, 9) * size.height) %
          depth;
      c.save();
      c.translate(_hash(i, 10) * size.width + 22 * math.sin(t * 0.6 + i),
          ground + fall);
      c.rotate(math.sin(t * 0.9 + i) * 1.1 + i);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 11, height: 5), leaf);
      c.restore();
    }
  }

  void _tree(Canvas c, Offset root, double h, double sway, Color leaf,
      SceneStyle s, double grow, {required bool pine}) {
    final shade = Paint()..color = Color.lerp(leaf, s.fillShade, 0.3)!;
    final light = Paint()..color = Color.lerp(leaf, s.fillCrest, 0.1)!;
    c.save();
    c.translate(root.dx, root.dy);
    c.rotate(sway);
    final paint = Paint()..color = leaf;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-h * 0.06, -h * 0.5, h * 0.12, h * 0.5),
            Radius.circular(h * 0.04)),
        Paint()
          ..color = Color.lerp(
              Color.lerp(s.fill, s.fillShade, grow)!, s.textStrong, 0.28)!);
    if (pine) {
      c.scale(h);
      c.drawPath(_pine, paint);
      c.drawPath(_pineShade, shade);
    } else {
      c.drawCircle(Offset(0, -h * 0.68), h * 0.32, paint);
      c.drawCircle(Offset(-h * 0.2, -h * 0.48), h * 0.24, paint);
      c.drawCircle(Offset(h * 0.2, -h * 0.48), h * 0.24, shade);
      c.drawCircle(Offset(h * 0.1, -h * 0.6), h * 0.2, paint);
      c.drawCircle(Offset(-h * 0.07, -h * 0.75), h * 0.21, light);
    }
    c.restore();
  }

  /// 경계선 없이 화면 전체가 보라빛 해질녘에서 우주 검정으로. 어두워질수록 별이 늘어난다.
  void _night(Canvas c, Size size, double t, SceneStyle s) {
    final fade = (progress / FillMotion.nightFadeIn).clamp(0.0, 1.0);
    final dark =
        ((progress - FillMotion.nightFadeIn) / (1 - FillMotion.nightFadeIn))
            .clamp(0.0, 1.0);
    Color at(Color start) =>
        Color.lerp(Color.lerp(s.cardBg, start, fade), s.fillDeep, dark)!;
    final rect = Offset.zero & size;
    c.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [at(s.fill), at(s.fillGlow ?? s.fill)],
          ).createShader(rect));
    // 성운: 어두워져도 은은하게 남는다
    final haze = fade * (0.42 - 0.2 * dark);
    for (final (fx, fy, r, glow) in const [
      (0.18, 0.2, 0.62, true),
      (0.86, 0.42, 0.7, false),
      (0.3, 0.72, 0.66, true),
      (0.78, 0.88, 0.58, true),
    ]) {
      final center = Offset(fx * size.width, fy * size.height);
      final radius = r * size.width;
      final tint = glow ? (s.fillGlow ?? s.fill) : s.fill;
      c.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              tint.withValues(alpha: haze),
              tint.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: center, radius: radius)));
    }

    final star = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final show = ((progress - i / _stars.length * 0.9) / 0.1).clamp(0.0, 1.0);
      if (show <= 0) continue;
      final (fx, fy) = _stars[i];
      final twinkle =
          0.7 + 0.3 * math.sin(2 * math.pi * t / FillMotion.starPeriod + i);
      final at = Offset(fx * size.width, fy * size.height);
      final bright = i % FillMotion.brightStarEvery == 0;
      final color = i % 5 == 0 ? (s.fillGlow ?? s.fillCrest) : s.fillCrest;
      if (!bright) {
        c.drawCircle(at, FillMotion.starRadius * (0.3 + 0.55 * _hash(i, 7)),
            star..color = color.withValues(alpha: show * twinkle * 0.85));
        continue;
      }
      final r = FillMotion.starRadius * (1.0 + 0.5 * _hash(i, 7));
      c.drawCircle(at, r * 3.2,
          star..color = s.fillCrest.withValues(alpha: show * twinkle * 0.14));
      star.color = s.fillCrest.withValues(alpha: show * twinkle);
      c.drawCircle(at, r * 0.75, star);
      final arm = r * (2.6 + 1.2 * twinkle);
      c.drawPath(
          Path()
            ..addPolygon([
              at + Offset(0, -arm),
              at + Offset(r * 0.28, -r * 0.28),
              at + Offset(arm, 0),
              at + Offset(r * 0.28, r * 0.28),
              at + Offset(0, arm),
              at + Offset(-r * 0.28, r * 0.28),
              at + Offset(-arm, 0),
              at + Offset(-r * 0.28, -r * 0.28),
            ], true),
          star);
    }
    _planet(c, size, s);
    _shootingStar(c, size, t, s);
  }

  /// 후반에 떠오르는 고리 행성: 할 일 카드와 원 사이 오른쪽 빈자리
  void _planet(Canvas c, Size size, SceneStyle s) {
    final show = ((progress - 0.5) / 0.3).clamp(0.0, 1.0);
    if (show <= 0) return;
    final glow = s.fillGlow ?? s.fill;
    final r = 21 * size.width / 402;
    final at = Offset(size.width * 0.84, size.height * 0.325);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-0.42);
    final band = Rect.fromCenter(center: Offset.zero, width: r * 3.3, height: r * 0.86);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13
      ..color = s.fillCrest.withValues(alpha: 0.62 * show);
    c.drawArc(band, math.pi, math.pi, false, orbit); // 뒤쪽 고리
    final ball = Rect.fromCircle(center: Offset.zero, radius: r);
    c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(glow, s.fillCrest, 0.4)!.withValues(alpha: show),
              s.fill.withValues(alpha: show),
            ],
          ).createShader(ball));
    c.drawArc(band, 0, math.pi, false, orbit); // 앞쪽 고리
    c.restore();
  }

  /// 어두워진 뒤 가끔 지나가는 별똥별
  void _shootingStar(Canvas c, Size size, double t, SceneStyle s) {
    if (progress < 0.25) return;
    final round = (t / FillMotion.shootingPeriod).floor();
    final u = (t % FillMotion.shootingPeriod) / FillMotion.shootingDuration;
    if (u >= 1) return;
    final from = Offset(size.width * (0.2 + 0.6 * _hash(round, 11)),
        size.height * (0.04 + 0.26 * _hash(round, 12)));
    final dir = const Offset(0.82, 0.57) * (size.width * 0.55);
    final head = from + dir * u;
    final tail = from + dir * math.max(0, u - 0.35);
    final alpha = math.sin(u * math.pi);
    c.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [
            s.fillCrest.withValues(alpha: 0),
            s.fillCrest.withValues(alpha: alpha),
          ]).createShader(Rect.fromPoints(tail, head)));
  }

  // 얼음 큐브 면 (꼭짓점 거리 1 기준). 빛은 왼쪽 위에서 온다.
  static Path _face(List<Offset> p) => Path()..addPolygon(p, true);
  static const _cubeW = 0.87;
  static final _iceTop = _face(const [
    Offset(0, -1),
    Offset(_cubeW, -0.5),
    Offset(0, 0),
    Offset(-_cubeW, -0.5),
  ]);
  static final _iceLeft = _face(const [
    Offset(-_cubeW, -0.5),
    Offset(0, 0),
    Offset(0, 1),
    Offset(-_cubeW, 0.5),
  ]);
  static final _iceRight = _face(const [
    Offset(_cubeW, -0.5),
    Offset(0, 0),
    Offset(0, 1),
    Offset(_cubeW, 0.5),
  ]);
  static final _iceOutline = _face(const [
    Offset(0, -1),
    Offset(_cubeW, -0.5),
    Offset(_cubeW, 0.5),
    Offset(0, 1),
    Offset(-_cubeW, 0.5),
    Offset(-_cubeW, -0.5),
  ]);
  static final _iceInner = Path()
    ..moveTo(-_cubeW, -0.5)
    ..lineTo(0, 0)
    ..lineTo(_cubeW, -0.5)
    ..moveTo(0, 0)
    ..lineTo(0, 1);
  static final _iceGlint = _face(const [
    Offset(-0.1, -0.72),
    Offset(0.28, -0.53),
    Offset(0.1, -0.43),
    Offset(-0.28, -0.62),
  ]);

  // 얼음 (x 비율, 수면 아래 깊이, 크기, 기울기). 수면과 함께 올라온다.
  static const _ice = [
    (0.12, 14.0, 58.0, 0.22),
    (0.36, 6.0, 46.0, -0.3),
    (0.58, 16.0, 62.0, 0.12),
    (0.86, 8.0, 50.0, -0.18),
    (0.24, 92.0, 44.0, 0.42),
    (0.74, 104.0, 52.0, -0.36),
    (0.08, 190.0, 40.0, -0.1),
    (0.92, 214.0, 42.0, 0.3),
  ];

  /// 잔 안을 들여다본 모습: 바다처럼 출렁이는 커피 + 떠 있는 얼음
  void _coffee(Canvas c, Size size, double t, SceneStyle s) {
    final y = fillSurfaceY(size.height, progress,
        overshoot: FillMotion.waveOvershoot);
    _swell(
        c,
        size,
        t,
        y,
        Paint()..color = Color.lerp(s.fill, s.fillCrest, 0.28)!,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.fill, s.fillDeep],
          ).createShader(Rect.fromLTRB(0, y, size.width, size.height + 1)),
        Color.lerp(s.fill, s.fillCrest, 0.6)!);
    final bob = 2 * math.pi * t / FillMotion.iceBobPeriod;
    final shadow = Paint()..color = s.fillDeep.withValues(alpha: 0.45);
    final top = Paint()..color = s.fillCrest.withValues(alpha: 0.88);
    final left = Paint()..color = s.fillCrest.withValues(alpha: 0.5);
    final right = Paint()..color = s.fillCrest.withValues(alpha: 0.26);
    final glint = Paint()..color = s.fillCrest;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = s.fillCrest.withValues(alpha: 0.9);
    for (var i = 0; i < _ice.length; i++) {
      final (fx, depth, side, tilt) = _ice[i];
      final cy = y + depth + FillMotion.iceBob * math.sin(bob + i);
      if (cy - side > size.height) continue;
      c.save();
      c.translate(fx * size.width, cy);
      c.rotate(tilt + 0.03 * math.sin(bob + i * 2));
      final a = side * 0.58;
      c.scale(a);
      c.save();
      c.translate(0.14, 0.2);
      c.drawPath(_iceOutline, shadow);
      c.restore();
      c.drawPath(_iceTop, top);
      c.drawPath(_iceLeft, left);
      c.drawPath(_iceRight, right);
      c.drawPath(_iceOutline, edge..strokeWidth = 2 / a);
      c.drawPath(_iceInner, edge..strokeWidth = 1.5 / a);
      c.drawPath(_iceGlint, glint);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(SceneFillPainter o) =>
      o.scene != scene || o.progress != progress;
}
