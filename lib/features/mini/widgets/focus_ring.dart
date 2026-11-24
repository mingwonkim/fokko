// lib/features/mini/widgets/focus_ring.dart
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/design_tokens.dart';
import '../../../core/scene_decorations.dart';
import '../../../state/app_state.dart';

/// v2 타이머 링 (Tiimo식): 굵은 진행 링 + 안쪽 원에 장면 일러스트.
/// 시간 글자는 링 밖(아래)에 둔다 — 일러스트를 가리지 않게.
/// 미니(88/12/14) · 확장(160/24/28) · 소형(40/6/6).
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.progress, // 1.0(시작) → 0.0(종료)
    required this.scene,
    this.size = AppSize.ringMini,
    this.stroke = 12,
    this.inset = 14,
  });

  final double progress;
  final FocusScene scene;
  final double size;
  final double stroke;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final style = scene.style;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 링 안 장면 일러스트 — 장면 전환 시 크로스페이드
          Positioned.fill(
            left: inset,
            top: inset,
            right: inset,
            bottom: inset,
            child: AnimatedSwitcher(
              duration: reduce ? Duration.zero : AppDuration.transition,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: CustomPaint(
                key: ValueKey(scene),
                size: Size.infinite,
                painter: SceneDialPainter(scene),
              ),
            ),
          ),
          // 진행 링 — 매초 변화는 300ms 선형 보간, 리셋 등 큰 점프는 즉시
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: target),
              duration: reduce ? Duration.zero : AppDuration.tick,
              curve: Curves.linear,
              builder: (_, value, __) => CustomPaint(
                painter: _RingPainter(
                  progress: (value - target).abs() > 0.05 ? target : value,
                  stroke: stroke,
                  progressColor: style.ringProgress,
                  track: style.ringTrack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.progressColor,
    required this.track,
  });

  final double progress;
  final double stroke;
  final Color progressColor;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, paint);

    final sweep = 2 * math.pi * progress;
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12시 방향 시작
      sweep,
      false,
      paint
        ..strokeCap = StrokeCap.round
        ..color = progressColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.track != track ||
      old.stroke != stroke;
}

/// "25:00"
String formatClock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

/// 타이머 상태별 표시·주 동작 (spec §2 상태 표). 휴식 판정 최우선.
/// 미니·확장·소형 타이머 줄이 같은 규칙을 쓰도록 한 곳에 둔다.
class TimerView {
  TimerView(AppState s)
      : status = s.phase == FocusPhase.breakTime
            ? '휴식'
            : s.currentTask == null
                ? (s.pendingTasks.isEmpty ? '할 일을 추가하세요' : '할 일을 선택하세요')
                : s.isRunning
                    ? '집중하는 중'
                    : (s.remainingSeconds < s.totalSeconds ? '일시정지됨' : '준비됨'),
        icon = s.phase == FocusPhase.breakTime
            ? Icons.skip_next_rounded
            : (s.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
        label = s.phase == FocusPhase.breakTime
            ? '건너뛰기'
            : s.isRunning
                ? '일시정지'
                : (s.remainingSeconds < s.totalSeconds ? '계속' : '시작'),
        onTap = s.phase == FocusPhase.breakTime
            ? s.skipBreak
            : s.currentTask == null
                ? null
                : (s.isRunning ? s.pauseTimer : s.startTimer);

  final String status;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}
