// lib/mobile/focus/mobile_ring.dart
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';

/// 폰 집중 링: 장면 풍경 + 데려올 친구 + 굵은 링.
/// 대기 중엔 링을 드래그해 시간 선택(12시=10분, 한 바퀴=180분, 5분 단위, 단계마다 햅틱).
/// 집중 중엔 지난 비율만큼 링이 차고 친구가 점점 선명해진다.
class MobileRing extends StatelessWidget {
  const MobileRing({
    super.key,
    required this.scene,
    required this.companion,
    required this.progress, // 집중: 지난 비율 0→1 / 휴식: 남은 비율 / 대기: 설정 위치 0~1
    required this.reveal, // 친구 불투명도 0~1
    this.onMinutes, // null이면 드래그 불가(진행 중)
    this.minutes = 25, // 대기 중 현재 설정 (12시 경계 넘김 방지·스크린리더 값)
    this.size = MobileSize.ring,
  });

  final FocusScene scene;
  final Companion companion;
  final double progress;
  final double reveal;
  final ValueChanged<int>? onMinutes;
  final int minutes;
  final double size;

  static double fractionOf(int minutes) =>
      (minutes - MobileSize.minMinutes) /
      (MobileSize.maxMinutes - MobileSize.minMinutes);

  void _drag(Offset local) {
    final c = Offset(size / 2, size / 2);
    final v = local - c;
    // 12시 기준 시계방향 각도 0~2π
    var a = math.atan2(v.dx, -v.dy);
    if (a < 0) a += 2 * math.pi;
    const span = MobileSize.maxMinutes - MobileSize.minMinutes;
    final raw = MobileSize.minMinutes + a / (2 * math.pi) * span;
    var snapped =
        ((raw / MobileSize.stepMinutes).round() * MobileSize.stepMinutes)
            .clamp(MobileSize.minMinutes, MobileSize.maxMinutes);
    // 12시를 가로질러 180↔10으로 튀지 않게: 반 바퀴 이상 점프면 가까운 끝에 멈춘다
    if ((snapped - minutes).abs() > span / 2) {
      snapped = minutes > MobileSize.minMinutes + span / 2
          ? MobileSize.maxMinutes
          : MobileSize.minMinutes;
    }
    onMinutes!(snapped);
  }

  void _step(int d) => onMinutes!((minutes + d * MobileSize.stepMinutes)
      .clamp(MobileSize.minMinutes, MobileSize.maxMinutes));

  @override
  Widget build(BuildContext context) {
    final style = scene.style;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const inset = MobileSize.ringInset;
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 링 안쪽은 불투명 — 집중 중 차오르는 배경이 비치지 않게
          Positioned.fill(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(color: style.cardBg, shape: BoxShape.circle),
            ),
          ),
          Positioned.fill(
            left: inset,
            top: inset,
            right: inset,
            bottom: inset,
            // 장면·친구가 바뀌면 280ms 크로스페이드
            child: AnimatedSwitcher(
              duration: reduce ? Duration.zero : AppDuration.transition,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: ClipOval(
                key: ValueKey('${scene.name}/${companion.id}'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                        painter: SceneDialPainter(scene, withCreatures: false)),
                    Padding(
                      padding: EdgeInsets.all(size * 0.08),
                      child: AnimatedOpacity(
                        opacity: reveal.clamp(0.0, 1.0),
                        duration: reduce ? Duration.zero : AppDuration.tick,
                        child:
                            Image.asset(companion.asset, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress.clamp(0.0, 1.0),
                track: style.ringTrack,
                color: style.ringProgress,
                knob: onMinutes != null ? style.rowBg : null,
              ),
            ),
          ),
        ],
      ),
    );
    if (onMinutes == null) return ring;
    return Semantics(
      label: '집중 시간',
      value: '$minutes분',
      increasedValue:
          '${(minutes + MobileSize.stepMinutes).clamp(MobileSize.minMinutes, MobileSize.maxMinutes)}분',
      decreasedValue:
          '${(minutes - MobileSize.stepMinutes).clamp(MobileSize.minMinutes, MobileSize.maxMinutes)}분',
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: GestureDetector(
        onPanStart: (d) => _drag(d.localPosition),
        onPanUpdate: (d) => _drag(d.localPosition),
        child: ring,
      ),
    );
  }
}

/// 5분 단계가 바뀔 때마다 가벼운 햅틱
void ringHaptic() => HapticFeedback.selectionClick();

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.progress,
      required this.track,
      required this.color,
      this.knob});

  final double progress;
  final Color track;
  final Color color;
  final Color? knob;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = MobileSize.ringStroke;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(c, r, p);
    final sweep = 2 * math.pi * progress;
    if (sweep > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep,
          false, p..color = color);
    }
    if (knob != null) {
      final a = -math.pi / 2 + sweep;
      final k = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(k, stroke / 2 + 4, Paint()..color = knob!);
      canvas.drawCircle(
          k,
          stroke / 2 + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress ||
      o.color != color ||
      o.track != track ||
      o.knob != knob;
}
