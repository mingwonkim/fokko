// lib/mobile/widgets/title_avatar.dart
// 칭호 테두리 아바타: 가운데 친구 그림 + 칭호별 링(색·빛·회전·별). 프로필·랭킹·승급·공유 카드 공통.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/design_tokens.dart';
import '../../models/focus_title.dart';

class TitleAvatar extends StatefulWidget {
  const TitleAvatar({
    super.key,
    required this.title,
    required this.asset,
    required this.background,
    this.size = MobileSize.avatar,
  });

  final FocusTitle title;
  final String asset; // 친구 그림 경로 ('' 이면 사람 아이콘)
  final Color background;
  final double size;

  @override
  State<TitleAvatar> createState() => _TitleAvatarState();
}

class _TitleAvatarState extends State<TitleAvatar>
    with SingleTickerProviderStateMixin {
  late final _spin =
      AnimationController(vsync: this, duration: AppDuration.titleSpin);

  TitleRing get _ring => TitleRings.all[widget.title.index];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TitleAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_ring.spin && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ring;
    final size = widget.size;
    // 링 두께는 기본 크기(56) 기준 → 큰 아바타에선 비례해 굵게
    final scale = size / MobileSize.avatar;
    final inset = (ring.width + 2) * scale;
    return Semantics(
      label: '칭호 ${widget.title.label}',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(ring, _spin, scale),
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: ClipOval(
              child: ColoredBox(
                color: widget.background,
                child: widget.asset.isEmpty
                    ? Icon(Icons.person_rounded,
                        size: size * 0.5, color: ring.colors.first)
                    : Padding(
                        padding: EdgeInsets.all(size * 0.08),
                        child: Image.asset(widget.asset, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ring, this.spin, this.scale) : super(repaint: spin);

  final TitleRing ring;
  final Animation<double> spin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = ring.width * scale;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - w / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final angle = spin.value * 2 * math.pi;
    final colors = ring.colors.length == 1
        ? ring.colors
        : [...ring.colors, ring.colors.first]; // 이음새 없이 한 바퀴
    Paint stroke(double width) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      if (colors.length == 1) {
        p.color = colors.first;
      } else {
        p.shader = SweepGradient(
          colors: colors,
          transform: GradientRotation(angle),
        ).createShader(rect);
      }
      return p;
    }

    if (ring.glow > 0) {
      canvas.drawCircle(
          c,
          r,
          stroke(w * 1.6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, ring.glow * scale));
    }
    canvas.drawCircle(c, r, stroke(w));
    if (ring.stars) {
      final star = Paint()..color = TitleRings.star;
      for (var i = 0; i < 3; i++) {
        final a = angle + i * 2 * math.pi / 3 - math.pi / 2;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r,
            w * 0.45, star);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring || old.scale != scale;
}

/// 지도 칭호 칸 테두리: 칭호별 장식 + 그라데이션 링. 닿기 전에는 흐리게 보여 준다.
class TitleFramePainter extends CustomPainter {
  const TitleFramePainter(
      {required this.ring, required this.reached, this.ornamentGap = 6});

  final TitleRing ring;
  final bool reached;
  final double ornamentGap; // 칸 가장자리에서 장식까지

  static final _leaf = Path()
    ..moveTo(0, 0.9)
    ..quadraticBezierTo(0.8, 0, 0, -1)
    ..quadraticBezierTo(-0.8, 0, 0, 0.9);
  static final _crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 1)),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(0.42, -0.2), radius: 0.8)));
  static final _star = Path()
    ..addPolygon(const [
      Offset(0, -1.2),
      Offset(0.26, -0.26),
      Offset(1.2, 0),
      Offset(0.26, 0.26),
      Offset(0, 1.2),
      Offset(-0.26, 0.26),
      Offset(-1.2, 0),
      Offset(-0.26, -0.26),
    ], true);
  static final _ray = Path()
    ..addPolygon(const [Offset(-0.5, 0.8), Offset(0, -1.1), Offset(0.5, 0.8)], true);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final u = size.shortestSide / MobileSize.mapNodeBig;
    final alpha = reached ? 1.0 : 0.7;
    Color tone(int i) => ring.colors[i % ring.colors.length].withValues(alpha: alpha);

    for (final o in ring.ornaments) {
      final far = radius + ornamentGap * u;
      for (var i = 0; i < o.count; i++) {
        final a = 2 * math.pi * i / o.count - math.pi / 2;
        final paint = Paint()..color = tone(i);
        final at = c + Offset(math.cos(a), math.sin(a)) * far;
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(a + math.pi / 2); // 바깥을 향한다
        switch (o.shape) {
          case TitleOrnamentShape.dot:
            canvas.drawCircle(Offset.zero, 2.2 * u, paint);
          case TitleOrnamentShape.leaf:
            canvas.scale(5.5 * u);
            canvas.drawPath(_leaf, paint);
          case TitleOrnamentShape.crescent:
            canvas.scale(6 * u);
            canvas.drawPath(_crescent, paint);
          case TitleOrnamentShape.star:
            canvas.scale(5.5 * u);
            canvas.drawPath(_star, paint);
          case TitleOrnamentShape.scallop:
            canvas.translate(0, 3 * u);
            canvas.drawCircle(Offset.zero, 7 * u, paint);
          case TitleOrnamentShape.bubble:
            canvas.drawCircle(
                Offset.zero,
                (i.isEven ? 3.2 : 1.8) * u,
                paint
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4 * u);
          case TitleOrnamentShape.ray:
            canvas.scale(5.5 * u);
            canvas.drawPath(_ray, paint);
        }
        canvas.restore();
      }
    }

    final w = ring.width * 1.3 * u;
    final r = radius - w / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint stroke(double width) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      if (ring.colors.length == 1) {
        p.color = tone(0);
      } else {
        p.shader = SweepGradient(colors: [
          for (final x in [...ring.colors, ring.colors.first])
            x.withValues(alpha: alpha)
        ]).createShader(rect);
      }
      return p;
    }

    if (reached && ring.glow > 0) {
      canvas.drawCircle(c, r,
          stroke(w * 1.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, ring.glow * u));
    }
    canvas.drawCircle(c, r, stroke(w));
  }

  @override
  bool shouldRepaint(TitleFramePainter o) =>
      o.ring != ring || o.reached != reached || o.ornamentGap != ornamentGap;
}

/// 칭호 배지: 메달 아이콘 + 칭호 이름을 칭호 링 색 그라데이션 알약에 담는다.
/// 숫자 레벨 대신 "이건 칭호다"가 한눈에 보이게. 행·프로필·승급·대결 공통.
class TitleBadge extends StatelessWidget {
  const TitleBadge(
      {super.key,
      required this.title,
      required this.textColor,
      this.height = MobileSize.badge,
      this.weight = FontWeight.w800});

  final FocusTitle title;
  final Color textColor;
  final double height;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final ring = TitleRings.all[title.index];
    final colors = ring.colors.length == 1
        ? [ring.colors.first, ring.colors.first]
        : ring.colors;
    final u = height / MobileSize.badge;
    return Semantics(
      label: '칭호 ${title.label}',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 8 * u),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          gradient: LinearGradient(
              colors: [for (final c in colors) c.withValues(alpha: 0.28)]),
          border: Border.all(color: colors.first, width: 1.2 * u),
          boxShadow: ring.glow > 0
              ? [
                  BoxShadow(
                      color: colors.last.withValues(alpha: 0.45),
                      blurRadius: ring.glow * u)
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ring.stars ? Icons.auto_awesome_rounded : Icons.military_tech_rounded,
              size: 15 * u, color: colors.first),
          SizedBox(width: 3 * u),
          Text(title.label,
              style: TextStyle(
                  fontSize: 12.5 * u,
                  fontWeight: weight,
                  height: 1.1,
                  color: textColor)),
        ]),
      ),
    );
  }
}

/// 칭호 사다리: 10단계 점. 지난 단계는 채움, 지금 단계는 크게 링 색, 남은 단계는 빈 점.
class TitleLadder extends StatelessWidget {
  const TitleLadder({super.key, required this.title, required this.track});
  final FocusTitle title;
  final Color track;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '칭호 ${FocusTitle.values.length}단계 중 ${title.index + 1}단계',
        excludeSemantics: true,
        child: Row(children: [
          for (final t in FocusTitle.values) ...[
            if (t.index > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: t.index <= title.index
                      ? TitleRings.all[t.index].colors.first
                      : track,
                ),
              ),
            Container(
              width: t == title ? MobileSize.ladderDot * 1.75 : MobileSize.ladderDot,
              height: t == title ? MobileSize.ladderDot * 1.75 : MobileSize.ladderDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.index <= title.index
                    ? TitleRings.all[t.index].colors.first
                    : track,
                border: t == title
                    ? Border.all(color: TitleRings.all[t.index].colors.last, width: 2)
                    : null,
              ),
            ),
          ],
        ]),
      );
}
