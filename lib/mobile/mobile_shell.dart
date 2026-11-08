// lib/mobile/mobile_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../state/app_state.dart';
import 'adaptive.dart';
import 'duel/duel_page.dart';
import 'duel/invite.dart';
import 'focus/focus_home.dart';
import 'focus/scene_fill.dart';
import 'growth/growth_tab.dart';
import 'records/records_tab.dart';
import 'scenery/scenery_tab.dart';
import 'tasks/tasks_tab.dart';

enum MobileTab { focus, growth, scenery, records, tasks }

/// 폰 셸: 탭 4개 + 떠 있는 캡슐 탭바. 화면은 P4부터 채운다.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> with WidgetsBindingObserver {
  /// 다른 탭에서 "바로 집중" 등으로 탭을 바꿀 수 있게 Provider로 내려준다
  final _tabs = ValueNotifier(MobileTab.focus);

  @override
  void initState() {
    super.initState();
    pendingInvite.addListener(_onInvite);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 앱을 켜 둔 채 날짜가 바뀌었을 수 있다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().settleGrowth();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingInvite.removeListener(_onInvite);
    _tabs.dispose();
    super.dispose();
  }

  void _onInvite() => setState(() {});

  /// 카톡 초대로 열렸으면 대결 화면으로 (집중·휴식 중이면 끝난 뒤에)
  void _openInvite() {
    final code = pendingInvite.value;
    if (code == null) return;
    pendingInvite.value = null;
    _tabs.value = MobileTab.records;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DuelPage(initialCode: code)));
  }

  static const _labels = {
    MobileTab.focus: ('집중', Icons.timer_outlined),
    MobileTab.growth: ('성장', Icons.route_rounded),
    MobileTab.scenery: ('꾸미기', Icons.park_outlined),
    MobileTab.records: ('경쟁', Icons.emoji_events_rounded),
    MobileTab.tasks: ('할 일', Icons.check_circle_outline),
  };

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: _tabs,
        child: Builder(builder: _build),
      );

  Widget _build(BuildContext context) {
    final state = context.watch<AppState>();
    final style = state.scene.style;
    // 진행·휴식 중엔 탭바를 숨긴다 (집중 화면에서 다른 데로 새지 않게)
    final hideBar = state.phase != FocusPhase.idle;
    final tab = context.watch<ValueNotifier<MobileTab>>().value;
    final current = hideBar ? MobileTab.focus : tab;
    if (!hideBar && pendingInvite.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite());
    }
    return Scaffold(
      backgroundColor: style.cardBg,
      body: Stack(fit: StackFit.expand, children: [
        // 집중 중 화면 전체 차오름 (SafeArea 밖). 휴식은 가득 찬 채 멈춘다.
        if (hideBar)
          SceneFill(
            scene: FocusScene.values.asNameMap()[state.activeSession?.scene] ??
                state.scene,
            progress:
                state.phase == FocusPhase.breakTime ? 1 : 1 - state.progress,
            animate: state.isRunning,
          ),
        SafeArea(
        // 탭 전환 페이드 120ms (동작 줄이기면 즉시)
        child: AnimatedSwitcher(
          duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
              ? Duration.zero
              : AppDuration.tab,
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(current),
            child: MaxWidth(
              max: current == MobileTab.focus || current == MobileTab.scenery
                  ? MobileSize.wideMaxWidth
                  : MobileSize.listMaxWidth,
              child: switch (current) {
                MobileTab.focus => const FocusHome(),
                MobileTab.growth => const GrowthTab(),
                MobileTab.tasks => const TasksTab(),
                MobileTab.records => const RecordsTab(),
                MobileTab.scenery => const SceneryTab(),
              },
            ),
          ),
        ),
      ),
      ]),
      extendBody: true,
      bottomNavigationBar: hideBar
          ? null
          : SafeArea(
              child: MaxWidth(
                max: 480,
                child: Padding(
                padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 0, MobileSize.gutter, 8),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: style.rowBg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadow.card(style.rowShadow),
                  ),
                  child: Row(
                    children: [
                      for (final t in MobileTab.values)
                        Expanded(
                          // 스크린리더: "집중 탭, 버튼, 선택됨"
                          child: Semantics(
                            button: true,
                            selected: t == current,
                            label: '${_labels[t]!.$1} 탭',
                            excludeSemantics: true,
                            onTap: () => _tabs.value = t,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _tabs.value = t,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: t == current ? style.divider : null,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(clipBehavior: Clip.none, children: [
                                      Icon(_labels[t]!.$2,
                                          size: 22,
                                          color: t == current
                                              ? style.accent
                                              : style.textMuted),
                                      // 안 연 상자 표시
                                      if (t == MobileTab.growth &&
                                          state.unopenedChests.isNotEmpty)
                                        Positioned(
                                          top: 0,
                                          right: -2,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                                color: style.accent,
                                                shape: BoxShape.circle),
                                          ),
                                        ),
                                    ]),
                                    Text(
                                      _labels[t]!.$1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: t == current
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: t == current
                                            ? style.textStrong
                                            : style.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ),
            ),
    );
  }
}
