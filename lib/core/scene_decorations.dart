// lib/core/scene_decorations.dart
// 장면(숲/밤/바다)별 장식 요소 — 전부 시안(.dc.html)의 도형을 그대로 옮긴 것.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design_tokens.dart';

/// 타이머 다이얼 안의 풍경. 좌표는 전부 지름 대비 비율 — 88px/216px 양쪽에서 동작.
class SceneDialPainter extends CustomPainter {
  SceneDialPainter(this.scene, {this.withCreatures = true});

  final FocusScene scene;
  final bool withCreatures; // 폰은 친구 그림을 따로 올리므로 토끼·고래를 빼고 배경만

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // 배경 그라데이션
    final s = scene.style;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: s.dialColors,
          stops: s.dialStops,
        ).createShader(rect),
    );

    switch (scene) {
      case FocusScene.forest:
        _paintForest(canvas, d);
      case FocusScene.night:
        _paintNight(canvas, d);
      case FocusScene.ocean:
        _paintOcean(canvas, d);
      case FocusScene.daily:
        _paintDaily(canvas, d);
    }
    canvas.restore();
  }

  // css bottom/left/width/height % → 캔버스 rect
  Rect _r(double d,
      {double? left,
      double? right,
      required double bottom,
      required double w,
      required double h}) {
    final x = left != null ? left * d : d - right! * d - w * d;
    final y = d - bottom * d - h * d;
    return Rect.fromLTWH(x, y, w * d, h * d);
  }

  void _radial(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 0.72],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _paintForest(Canvas canvas, double d) {
    final p = Paint();
    // 태양 글로우
    _radial(canvas, Offset(0.38 * d, 0.21 * d), 0.17 * d,
        const Color.fromRGBO(255, 246, 196, 0.95));
    // 먼 수풀 언덕
    p.color = const Color.fromRGBO(94, 199, 124, 0.8);
    canvas.drawOval(_r(d, left: -0.14, bottom: 0.26, w: 0.62, h: 0.44), p);
    p.color = const Color.fromRGBO(74, 184, 106, 0.8);
    canvas.drawOval(_r(d, right: -0.16, bottom: 0.24, w: 0.68, h: 0.48), p);
    // 나무 기둥
    p.color = const Color.fromRGBO(168, 121, 79, 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(d, left: 0.30, bottom: 0.13, w: 0.038, h: 0.17),
            Radius.circular(0.016 * d)),
        p);
    p.color = const Color.fromRGBO(150, 104, 64, 0.85);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(d, right: 0.27, bottom: 0.09, w: 0.043, h: 0.215),
            Radius.circular(0.021 * d)),
        p);
    // 가까운 수풀 언덕
    p.color = const Color.fromRGBO(48, 168, 86, 0.9);
    canvas.drawOval(_r(d, left: -0.20, bottom: -0.20, w: 0.78, h: 0.62), p);
    p.color = const Color.fromRGBO(36, 148, 72, 0.9);
    canvas.drawOval(_r(d, right: -0.18, bottom: -0.24, w: 0.84, h: 0.66), p);
  }

  void _paintNight(Canvas canvas, double d) {
    final p = Paint();
    // 달 (글로우 → 본체 → 크레이터) — v2: 작은 링(60px)에서도 보이게 중앙·확대
    final moonC = Offset(0.5 * d, 0.48 * d);
    final moonR = 0.2 * d;
    _radial(
        canvas, moonC, moonR * 1.5, const Color.fromRGBO(242, 217, 140, 0.28));
    canvas.drawCircle(
      moonC,
      moonR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.24, -0.32),
          colors: [Color(0xFFFDF3D0), Color(0xFFE0C47E)],
          stops: [0, 0.75],
        ).createShader(Rect.fromCircle(center: moonC, radius: moonR)),
    );
    p.color = const Color.fromRGBO(190, 158, 90, 0.45);
    canvas.drawCircle(moonC + Offset(-0.06 * d, 0.07 * d), 0.032 * d, p);
    p.color = const Color.fromRGBO(190, 158, 90, 0.4);
    canvas.drawCircle(moonC + Offset(0.07 * d, 0.02 * d), 0.022 * d, p);
    if (withCreatures) {
      // 달 위의 토끼 (귀 2 + 머리 + 몸통) — 달 윗변 기준 k배
      const k = 1.8;
      final anchor = moonC + Offset(-0.015 * d, -moonR);
      Offset at(double x, double y) => anchor + Offset(x * d * k, y * d * k);
      final rp = Paint()..color = const Color(0xFFF5F2EA);
      canvas.drawPath(
          _rotRRect(at(-0.02, -0.055), 0.013 * d * k, 0.042 * d * k, -12), rp);
      canvas.drawPath(
          _rotRRect(at(0.015, -0.058), 0.013 * d * k, 0.045 * d * k, 8), rp);
      rp.color = const Color(0xFFFAF7EF);
      canvas.drawOval(
          Rect.fromCenter(
              center: at(0, -0.008),
              width: 0.043 * d * k,
              height: 0.035 * d * k),
          rp);
      rp.color = const Color(0xFFF0EBDD);
      canvas.drawOval(
          Rect.fromCenter(
              center: at(-0.015, 0.014),
              width: 0.07 * d * k,
              height: 0.04 * d * k),
          rp);
    }
    // 별
    for (final (x, y, r, a) in [
      (0.80, 0.24, 0.016, 0.95),
      (0.82, 0.46, 0.01, 0.8),
      (0.24, 0.20, 0.013, 0.85),
      (0.16, 0.50, 0.01, 0.7),
    ]) {
      p.color = Color.fromRGBO(255, 244, 208, a);
      canvas.drawCircle(Offset(x * d, y * d), r * d, p);
    }
    // 어두운 언덕 실루엣
    p.color = const Color(0xFF0A0E1A);
    canvas.drawOval(_r(d, left: -0.16, bottom: -0.18, w: 0.74, h: 0.46), p);
    p.color = const Color(0xFF070A13);
    canvas.drawOval(_r(d, right: -0.14, bottom: -0.22, w: 0.80, h: 0.50), p);
  }

  /// 일상: 창가 햇살 + 테이블 + 김 나는 머그 (작은 링 60px에서도 머그 실루엣이 보이게 크게)
  void _paintDaily(Canvas canvas, double d) {
    final p = Paint();
    // 창문 빛
    _radial(canvas, Offset(0.68 * d, 0.22 * d), 0.3 * d,
        const Color.fromRGBO(255, 244, 222, 0.9));
    p.color = const Color.fromRGBO(255, 255, 255, 0.35);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0.52 * d, 0.08 * d, 0.3 * d, 0.36 * d),
            Radius.circular(0.04 * d)),
        p);
    // 테이블
    p.color = const Color(0xFFD9826A);
    canvas.drawRect(Rect.fromLTWH(0, 0.7 * d, d, 0.3 * d), p);
    p.color = const Color(0xFFE99B82);
    canvas.drawRect(Rect.fromLTWH(0, 0.68 * d, d, 0.04 * d), p);
    if (!withCreatures) return; // 폰은 친구 그림을 따로 올림 — 머그는 생략
    // 머그
    final mug = RRect.fromRectAndRadius(
        Rect.fromLTWH(0.33 * d, 0.46 * d, 0.3 * d, 0.26 * d),
        Radius.circular(0.06 * d));
    p.color = const Color(0xFFFFFBF8);
    canvas.drawRRect(mug, p);
    canvas.drawArc(
        Rect.fromLTWH(0.56 * d, 0.5 * d, 0.14 * d, 0.14 * d),
        -1.4,
        2.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035 * d
          ..color = const Color(0xFFFFFBF8));
    // 김
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.022 * d
      ..strokeCap = StrokeCap.round
      ..color = const Color.fromRGBO(255, 255, 255, 0.8);
    for (final x in [0.42, 0.52]) {
      final path = Path()
        ..moveTo(x * d, 0.42 * d)
        ..quadraticBezierTo((x - 0.04) * d, 0.36 * d, x * d, 0.31 * d)
        ..quadraticBezierTo((x + 0.04) * d, 0.26 * d, x * d, 0.21 * d);
      canvas.drawPath(path, steam);
    }
  }

  void _paintOcean(Canvas canvas, double d) {
    final p = Paint();
    // 수면 빛줄기
    canvas.save();
    canvas.translate(0.42 * d, -0.1 * d);
    canvas.rotate(14 * math.pi / 180);
    final shaft = Rect.fromLTWH(0, 0, 0.14 * d, 0.7 * d);
    canvas.drawRect(
      shaft,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.55),
            Color.fromRGBO(255, 255, 255, 0),
          ],
        ).createShader(shaft),
    );
    canvas.restore();
    if (withCreatures) {
      // 고래 (몸통 상/하 투톤 + 꼬리 + 눈)
      final body = _r(d, left: 0.24, bottom: 0.30, w: 0.47, h: 0.215);
      canvas.drawOval(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2B7DB4),
              Color(0xFF2B7DB4),
              Color(0xFFCFEAF8),
              Color(0xFFCFEAF8),
            ],
            stops: [0, 0.58, 0.585, 1],
          ).createShader(body),
      );
      p.color = const Color(0xFF2B7DB4);
      canvas.drawPath(
          _rotRRect(
              Offset(0.20 * d, body.top + 0.02 * d), 0.07 * d, 0.024 * d, 24,
              horizontal: true),
          p);
      canvas.drawPath(
          _rotRRect(
              Offset(0.20 * d, body.top + 0.075 * d), 0.065 * d, 0.024 * d, -14,
              horizontal: true),
          p);
      p.color = const Color(0xFF0E2F47);
      canvas.drawCircle(
          Offset(body.right - 0.03 * d, body.top + 0.11 * d), 0.011 * d, p);
    }
    // 물방울
    final bubble = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.011 * d;
    for (final (x, y, r, a) in [
      (0.78, 0.20, 0.021, 0.75),
      (0.70, 0.30, 0.013, 0.65),
      (0.72, 0.12, 0.016, 0.7),
    ]) {
      bubble.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(Offset(x * d, y * d), r * d, bubble);
    }
    // 바닥 (청록 틴트)
    p.style = PaintingStyle.fill;
    p.color = const Color.fromRGBO(150, 210, 214, 0.55);
    canvas.drawOval(_r(d, left: -0.10, bottom: -0.14, w: 0.70, h: 0.34), p);
    p.color = const Color.fromRGBO(112, 186, 196, 0.5);
    canvas.drawOval(_r(d, right: -0.12, bottom: -0.16, w: 0.76, h: 0.36), p);
  }

  /// 회전된 알약(rrect) 경로 — 토끼 귀, 고래 꼬리 등
  Path _rotRRect(Offset topLeft, double w, double h, double deg,
      {bool horizontal = false}) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h), Radius.circular(math.min(w, h) / 2));
    final m = Matrix4.identity()
      ..translateByDouble(topLeft.dx, topLeft.dy, 0, 1)
      ..rotateZ(deg * math.pi / 180);
    return (Path()..addRRect(r)).transform(m.storage);
  }

  @override
  bool shouldRepaint(SceneDialPainter old) =>
      old.scene != scene || old.withCreatures != withCreatures;
}

/// 잎사귀 (border-radius: 0 62% 0 62% 회전) — 숲 장식/불릿
class Leaf extends StatelessWidget {
  const Leaf({
    super.key,
    required this.size,
    required this.colorA,
    required this.colorB,
    this.angle = 0,
    this.opacity = 1,
  });

  final double size;
  final Color colorA;
  final Color colorB;
  final double angle; // degrees
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorA, colorB],
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(size * 0.62),
              bottomLeft: Radius.circular(size * 0.62),
            ),
          ),
        ),
      ),
    );
  }
}

/// 십자 반짝이 별 — 밤 장식/불릿
class StarCross extends StatelessWidget {
  const StarCross({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.16;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: (size - bar) / 2,
            child: Container(
              width: size,
              height: bar,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Positioned(
            left: (size - bar) / 2,
            child: Container(
              width: bar,
              height: size,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 파도 아치 (위쪽 반원 테두리) — 바다 장식/불릿
class WaveArc extends StatelessWidget {
  const WaveArc({
    super.key,
    required this.width,
    required this.color,
    this.strokeWidth = 3,
  });

  final double width;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width / 2),
      painter: _WaveArcPainter(color, strokeWidth),
    );
  }
}

class _WaveArcPainter extends CustomPainter {
  _WaveArcPainter(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawArc(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth,
          size.height * 2 - strokeWidth),
      math.pi,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_WaveArcPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// 작업 리스트 행의 불릿 — 잎 / 별 / 파도
class SceneBullet extends StatelessWidget {
  const SceneBullet(
      {super.key,
      required this.scene,
      required this.selected,
      this.moon = false});

  final FocusScene scene;
  final bool selected;
  final bool moon; // 폰: 밤을 별(+처럼 보임) 대신 달로

  @override
  Widget build(BuildContext context) {
    if (moon && scene == FocusScene.night) {
      return Icon(Icons.nightlight_round,
          size: 14,
          color: selected
              ? const Color(0xFFE6C766)
              : const Color.fromRGBO(230, 199, 102, 0.5));
    }
    return switch (scene) {
      FocusScene.forest => Leaf(
          size: 10,
          angle: 45,
          colorA: selected ? const Color(0xFF5CD484) : const Color(0xFFA8DCB6),
          colorB: selected ? const Color(0xFF1F9E4C) : const Color(0xFF6BBD85),
        ),
      FocusScene.night => StarCross(
          size: 11,
          color: selected
              ? const Color.fromRGBO(242, 217, 140, 0.95)
              : const Color.fromRGBO(242, 217, 140, 0.5),
        ),
      FocusScene.ocean => WaveArc(
          width: 14,
          strokeWidth: 2,
          color: selected
              ? const Color.fromRGBO(31, 122, 181, 0.85)
              : const Color.fromRGBO(120, 190, 228, 0.8),
        ),
      FocusScene.daily => _MugBullet(
          color: selected ? const Color(0xFFE08A6E) : const Color(0xFFF2B9A6),
        ),
    };
  }
}

/// 일상 불릿: 작은 머그
class _MugBullet extends StatelessWidget {
  const _MugBullet({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 13,
        height: 11,
        child: Stack(children: [
          Positioned(
            left: 0,
            top: 1,
            child: Container(
              width: 9,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 3,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
        ]),
      );
}

/// 누름 피드백: 0.97 스케일 (80ms 누름 / 120ms 해제). 동작 줄이기 설정이면 즉시.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: reduce
              ? Duration.zero
              : (_down ? AppDuration.press : AppDuration.release),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: widget.onTap == null ? 0.45 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 주 동작 알약 버튼 (Tiimo의 검은 알약): 아이콘 + 라벨
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    this.width = 144,
    this.height = AppSize.control,
    this.onTap,
  });

  final SceneStyle style;
  final IconData icon;
  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true, // 안쪽 글자와 겹쳐 두 번 읽히지 않게
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: style.pillBg,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: height * 0.5, color: style.pillFg),
              if (width >= 96) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: style.pillFg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 보조 원형 버튼 (리셋·완료·패널 열기): 카드색 원 + 아이콘
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.style,
    required this.icon,
    required this.tooltip,
    this.size = AppSize.control,
    this.onTap,
  });

  final SceneStyle style;
  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.rowBg,
              boxShadow: AppShadow.card(style.rowShadow),
            ),
            child: Icon(icon, size: size * 0.45, color: style.textStrong),
          ),
        ),
      ),
    );
  }
}
