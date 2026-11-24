// lib/features/expanded/expanded_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../services/window_service.dart';
import '../../state/app_state.dart';
import '../mini/widgets/focus_ring.dart';
import 'widgets/blocker_settings_view.dart';
import 'widgets/inbox_list.dart';
import 'widgets/task_list.dart';

enum _PanelView { tasks, inbox, blocker }

/// 확장 패널 (400×560, spec §1 표):
/// 헤더 → 현재 작업·세션 칩 → 링 160 → 시간 → 컨트롤 → 탭 → 목록 → 푸터
class ExpandedScreen extends StatefulWidget {
  const ExpandedScreen({super.key});

  @override
  State<ExpandedScreen> createState() => _ExpandedScreenState();
}

class _ExpandedScreenState extends State<ExpandedScreen> {
  _PanelView _view = _PanelView.tasks;

  static const _durations = [5, 15, 25, 45];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final windowService = context.read<WindowService>();
    final style = state.scene.style;
    final task = state.currentTask;
    final view = TimerView(state);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Container(
      width: WindowSizes.expanded.width,
      height: WindowSizes.expanded.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: style.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: style.cardBorder),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      // 카드가 배경색을 직접 칠하므로, 내부 잉크/리스트타일용 투명 Material을 깐다
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            // ── 헤더: 타이틀 · 사운드 · 장면 · 접기 ──
            SizedBox(
              height: 32,
              child: DragToMoveArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fokko',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: style.textStrong,
                        ),
                      ),
                    ),
                    _SoundControl(state: state, style: style),
                    const SizedBox(width: 8),
                    _SceneChip(state: state, style: style),
                    const SizedBox(width: 8),
                    RoundIconButton(
                      style: style,
                      size: AppSize.controlSm,
                      icon: Icons.close_fullscreen_rounded,
                      tooltip: '미니 위젯으로',
                      onTap: windowService.collapse,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── 현재 작업 · 세션 길이 ──
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.phase == FocusPhase.breakTime
                          ? '잠깐 쉬어가세요'
                          : (task?.title ?? view.status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: task == null ? style.textMuted : style.textStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SessionChip(state: state, style: style),
                ],
              ),
            ),

            // ── 링 + 시간 + 컨트롤 (작업 뷰) / 소형 타이머 줄 (인박스·차단) ──
            if (_view == _PanelView.tasks) ...[
              const SizedBox(height: 8),
              FocusRing(
                progress: state.progress,
                scene: state.scene,
                size: AppSize.ringLarge,
                stroke: 24,
                inset: 28,
              ),
              SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    formatClock(state.remainingSeconds),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: style.textStrong,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundIconButton(
                    style: style,
                    icon: Icons.replay_rounded,
                    tooltip: '리셋',
                    onTap: state.stopTimer,
                  ),
                  const SizedBox(width: 12),
                  PillButton(
                    style: style,
                    icon: view.icon,
                    label: view.label,
                    onTap: view.onTap,
                  ),
                  const SizedBox(width: 12),
                  RoundIconButton(
                    style: style,
                    icon: Icons.check_rounded,
                    tooltip: '완료',
                    onTap: task == null ? null : state.completeCurrentTask,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 8),
              _CompactTimerStrip(state: state, style: style),
              const SizedBox(height: 12),
            ],

            // ── 오늘의 작업 / 인박스 / 차단 ──
            _SectionTabs(
              style: style,
              view: _view,
              inboxCount: state.inbox.length,
              onSelect: (v) => setState(() => _view = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : AppDuration.tab,
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey(_view),
                  child: switch (_view) {
                    _PanelView.tasks => const TaskList(),
                    _PanelView.inbox => const InboxList(),
                    _PanelView.blocker => const BlockerSettingsView(),
                  },
                ),
              ),
            ),

            // ── 푸터 통계 ──
            const SizedBox(height: 8),
            Text(
              '${style.footerLabel} · ${state.todaySessionCount}${style.footerUnit}',
              style: TextStyle(fontSize: 12, color: style.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더 장면 칩: [장면 불릿] 숲 — 탭하면 숲→밤→바다 순환
class _SceneChip extends StatelessWidget {
  const _SceneChip({required this.state, required this.style});

  final AppState state;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '장면 전환 (사운드도 바뀜)',
      child: PressScale(
        onTap: () => state.setScene(state.scene.next),
        child: Container(
          height: AppSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadow.card(style.rowShadow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SceneBullet(scene: state.scene, selected: true),
              const SizedBox(width: 6),
              Text(
                style.sceneLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: style.textStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 앰비언트 사운드 컨트롤: 아이콘 탭 → on/off 토글 + 볼륨 슬라이더 팝업
class _SoundControl extends StatelessWidget {
  const _SoundControl({required this.state, required this.style});

  final AppState state;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) {
    // 기본 PopupMenuButton은 헤더 Row를 키운다 — 32px 원형으로 고정
    return SizedBox(
      width: AppSize.controlSm,
      height: AppSize.controlSm,
      child: PopupMenuButton<void>(
        tooltip: '사운드 설정',
        position: PopupMenuPosition.under,
        padding: EdgeInsets.zero,
        child: RoundIconButton(
          style: style,
          size: AppSize.controlSm,
          icon: state.soundEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: '사운드 설정',
        ),
        itemBuilder: (_) => [
          PopupMenuItem<void>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // 팝업 안에서도 상태 변화가 바로 보이게 Consumer로 구독
            child: Consumer<AppState>(
              builder: (_, s, __) => SizedBox(
                width: 220,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: s.soundEnabled ? '소리 끄기' : '소리 켜기',
                      icon: Icon(
                        s.soundEnabled ? Icons.volume_up : Icons.volume_off,
                        size: 20,
                        color: s.soundEnabled ? style.accent : style.textFaint,
                      ),
                      onPressed: () => s.setSoundEnabled(!s.soundEnabled),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: style.accent,
                          inactiveTrackColor: style.ringTrack,
                          thumbColor: style.accent,
                          overlayColor: style.ringTrack,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: s.soundVolume,
                          onChanged: s.soundEnabled
                              ? (v) => s.setSoundVolume(v, persist: false)
                              : null,
                          onChangeEnd: (v) => s.setSoundVolume(v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 인박스·차단 뷰용 소형 타이머 줄 (spec §2):
/// 링 40 → 시간·상태 → 리셋 32 · 알약 80 · 완료 32
class _CompactTimerStrip extends StatelessWidget {
  const _CompactTimerStrip({required this.state, required this.style});

  final AppState state;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) {
    final view = TimerView(state);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Row(
        children: [
          FocusRing(
            progress: state.progress,
            scene: state.scene,
            size: AppSize.ringCompact,
            stroke: 6,
            inset: 6,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatClock(state.remainingSeconds),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: style.textStrong,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  view.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: style.textMuted),
                ),
              ],
            ),
          ),
          RoundIconButton(
            style: style,
            size: AppSize.controlSm,
            icon: Icons.replay_rounded,
            tooltip: '리셋',
            onTap: state.stopTimer,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: view.label,
            child: PillButton(
              style: style,
              width: 80,
              height: AppSize.controlSm,
              icon: view.icon,
              label: view.label,
              onTap: view.onTap,
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            style: style,
            size: AppSize.controlSm,
            icon: Icons.check_rounded,
            tooltip: '완료',
            onTap: state.currentTask == null ? null : state.completeCurrentTask,
          ),
        ],
      ),
    );
  }
}

/// 세션 길이 칩 "25분 ▾" — 대기·일시정지 중 탭하면 5/15/25/45분 메뉴
class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.state, required this.style});

  final AppState state;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) {
    final isBreak = state.phase == FocusPhase.breakTime;
    final minutes = state.totalSeconds ~/ 60;
    final canEdit = !state.isRunning && !isBreak;

    final chip = Container(
      height: AppSize.controlSm,
      padding: EdgeInsets.only(left: 12, right: canEdit ? 8 : 12),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isBreak ? '휴식 $minutes분' : '$minutes분',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.textStrong,
            ),
          ),
          if (canEdit)
            Icon(Icons.expand_more_rounded, size: 16, color: style.textMuted),
        ],
      ),
    );
    if (!canEdit) return chip;

    return PopupMenuButton<int>(
      tooltip: '세션 길이 변경',
      position: PopupMenuPosition.under,
      onSelected: state.setDurationMinutes,
      itemBuilder: (_) => _ExpandedScreenState._durations
          .map((m) => PopupMenuItem(value: m, child: Text('$m분')))
          .toList(),
      child: chip,
    );
  }
}

/// 탭: 오늘의 작업 · 인박스 n · 차단 — 선택은 카드색 알약 (Tiimo 섹션 칩)
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.style,
    required this.view,
    required this.inboxCount,
    required this.onSelect,
  });

  final SceneStyle style;
  final _PanelView view;
  final int inboxCount;
  final void Function(_PanelView) onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, _PanelView v) {
      final selected = view == v;
      return Expanded(
        child: PressScale(
          onTap: () => onSelect(v),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? style.rowBg : null,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: selected ? AppShadow.card(style.rowShadow) : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? style.textStrong : style.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: style.divider,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          item('오늘의 작업', _PanelView.tasks),
          item(inboxCount > 0 ? '인박스 $inboxCount' : '인박스', _PanelView.inbox),
          item('차단', _PanelView.blocker),
        ],
      ),
    );
  }
}
