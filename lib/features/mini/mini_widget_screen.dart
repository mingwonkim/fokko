// lib/features/mini/mini_widget_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../services/window_service.dart';
import '../../state/app_state.dart';
import 'widgets/focus_ring.dart';

/// 미니 위젯 (320×128, spec §1):
/// [링 88 + 시간] | [상태 · 현재 작업 · (알약 + 패널 열기 40)]
class MiniWidgetScreen extends StatelessWidget {
  const MiniWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final windowService = context.read<WindowService>();
    final style = state.scene.style;
    final view = TimerView(state);
    final isBreak = state.phase == FocusPhase.breakTime;
    final idleWithTask =
        state.currentTask != null && !isBreak && !state.isRunning;

    return DragToMoveArea(
      child: Container(
        width: WindowSizes.mini.width,
        height: WindowSizes.mini.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: style.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: style.cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Column(
              children: [
                FocusRing(progress: state.progress, scene: state.scene),
                Text(
                  formatClock(state.remainingSeconds),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1, // 128 - 테두리2 - 패딩16 = 110 = 링88 + 22
                    color: style.textStrong,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idleWithTask && view.status == '준비됨'
                          ? '지금 집중할 일'
                          : view.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: style.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBreak
                          ? '잠깐 쉬어가세요'
                          : (state.currentTask?.title ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: style.textStrong,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            style: style,
                            icon: view.icon,
                            label: view.label,
                            width: double.infinity,
                            onTap: view.onTap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        RoundIconButton(
                          style: style,
                          icon: Icons.open_in_full_rounded,
                          tooltip: '패널 열기',
                          onTap: windowService.toggleMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
