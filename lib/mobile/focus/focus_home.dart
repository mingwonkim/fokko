// lib/mobile/focus/focus_home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../features/mini/widgets/focus_ring.dart' show formatClock;
import '../../services/session_notifier.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';
import '../lock/lock_page.dart';
import 'mobile_ring.dart';
import 'sheets.dart';
import 'stat_bar.dart';

/// 집중 홈 (docs/mobile/app-design-spec.md §2):
/// 지금 할 일 카드 → 도구 행(장면·소리·잠금) → 링 → 시간 → 친구·태그 → 시작 + 메모
class FocusHome extends StatefulWidget {
  const FocusHome({super.key});

  @override
  State<FocusHome> createState() => _FocusHomeState();
}

class _FocusHomeState extends State<FocusHome> {
  int _minutes = 25;
  bool _rewardShown = false;

  void _setMinutes(AppState s, int m) {
    if (m == _minutes) return;
    ringHaptic();
    setState(() => _minutes = m);
    s.setDurationMinutes(m);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final active = s.activeSession;
    final idle = active == null && s.phase != FocusPhase.breakTime;
    final h = MediaQuery.sizeOf(context).height;
    final tablet = isTablet(context);
    final small = !tablet && h < 700;
    final landscape = tablet && MediaQuery.sizeOf(context).aspectRatio > 1;
    final ringSize = landscape
        ? (h * 0.52).clamp(232.0, 360.0) // 가로: 높이에 맞춰 크게
        : tablet
        ? (MediaQuery.sizeOf(context).shortestSide * 0.42).clamp(232.0, 320.0)
        : (small ? MobileSize.ringSmall : (h > 900 ? 264.0 : MobileSize.ring));
    _minutes = idle ? s.totalSeconds ~/ 60 : _minutes;

    // 완료 직후 보상 시트 1회
    if (s.lastReward != null && !_rewardShown) {
      _rewardShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showRewardSheet(context);
        _rewardShown = false;
      });
    }

    // 진행 중엔 세션에 고정된 친구
    final companion =
        Companion.byId(active?.companionId) ?? s.selectedCompanion;
    // 집중 중 링은 배경과 같이 0에서 채워진다 (휴식은 남은 시간만큼 줄어듦)
    final progress = idle
        ? MobileRing.fractionOf(_minutes)
        : (active != null ? 1 - s.progress : s.progress);
    // 대기: 데려올 친구를 또렷하게 보여 주고, 시작하면 흐려졌다가 집중할수록 선명해짐
    final reveal = idle ? 1.0 : 0.25 + 0.75 * (1 - s.progress);

    final header = Column(children: [
      // 진행 중엔 숨기되 자리는 유지 — 시작해도 링 위치가 그대로다
      Visibility(
        visible: idle,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: StatBar(state: s),
      ),
      _TaskCard(state: s, enabled: idle),
      const SizedBox(height: 8),
      if (idle) _ToolRow(state: s) else _RunningBadge(state: s),
    ]);
    final ring = Column(children: [
      // 도구 행과 최소 24 (작은 폰은 시간이 가려지지 않게 8)
      SizedBox(height: small ? MobileSize.cardGap : MobileSize.sectionGap),
      MobileRing(
        scene: s.scene,
        companion: companion,
        progress: progress,
        reveal: reveal,
        size: ringSize,
        minutes: _minutes,
        onMinutes: idle ? (m) => _setMinutes(s, m) : null,
      ),
      const SizedBox(height: 8),
      // 차오름 위에서도 읽히게 진행 중엔 불투명 받침
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: idle ? null : style.rowBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          formatClock(idle ? _minutes * 60 : s.remainingSeconds),
          style: TextStyle(
            fontSize: tablet ? 64 : 56,
            fontWeight: FontWeight.w600,
            height: 64 / 56,
            color: style.textStrong,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const SizedBox(height: MobileSize.cardGap),
      if (idle)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
                state: s,
                label: companion.name,
                onTap: () => showCompanionSheet(context)),
            _Chip(
                state: s,
                dot: tagColor(style, s.currentTag?.colorIndex ?? 0),
                label: s.currentTag?.name ?? '태그',
                onTap: () => showTagSheet(context)),
          ],
        )
      else
        SizedBox(
          height: MobileSize.row,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: MobileSize.gridGap, vertical: MobileSize.labelGap),
              decoration: BoxDecoration(
                color: style.rowBg,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                s.phase == FocusPhase.breakTime
                    ? '잠깐 쉬어가요'
                    : (s.isRunning
                        ? '집중할수록 ${companion.name}이(가) 선명해져요'
                        : '잠시 멈춤'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: style.textMuted),
              ),
            ),
          ),
        ),
      SizedBox(height: small ? MobileSize.cardGap : 16),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MobileSize.gutter),
      child: LayoutBuilder(builder: (_, outer) {
        // iPad 가로: 왼쪽 링, 오른쪽 할 일·버튼
        if (outer.maxWidth >= MobileSize.twoPaneBreak && outer.maxWidth > outer.maxHeight) {
          return Row(children: [
            Expanded(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: outer.maxHeight),
                  child: Center(child: ring),
                ),
              ),
            ),
            const SizedBox(width: MobileSize.sectionGap),
            SizedBox(
              width: MobileSize.sidePane,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  header,
                  const SizedBox(height: MobileSize.sectionGap),
                  _Controls(state: s),
                  const SizedBox(height: MobileSize.contentBottomGap),
                ],
              ),
            ),
          ]);
        }
        // 본문은 스크롤(작은 화면·큰 글자에서도 넘침 없게), 버튼 행은 아래 고정.
        // 대기/진행의 윗부분 높이를 같게 둬서 시작해도 링 위치가 그대로다.
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MaxWidth(max: tablet ? 560 : double.infinity, child: header),
                        ring,
                        // 빈 자리 — spaceBetween이 링 묶음을 남는 공간 가운데에 둔다
                        const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // iPad 세로: 버튼 행은 폰 폭 정도로
            MaxWidth(max: tablet ? 560 : double.infinity, child: _Controls(state: s)),
            // 탭바 자리 (진행 중엔 탭바 숨김)
            const SizedBox(height: MobileSize.contentBottomGap),
          ],
        );
      }),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.state, required this.enabled});
  final AppState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    final a = state.activeSession;
    final title = a != null
        ? (a.taskTitle.isEmpty
            ? '${state.currentTag?.name ?? '태그'}로 집중 중'
            : a.taskTitle)
        : state.currentTask?.title;
    final card = Container(
          constraints: const BoxConstraints(minHeight: MobileSize.taskCard),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: MobileSize.cardPadding),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(style.rowShadow),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('지금 할 일',
                      style: TextStyle(fontSize: 13, color: style.textMuted)),
                  const SizedBox(height: MobileSize.labelGap),
                  Text(
                    (title == null || title.isEmpty) ? '하나만 골라볼까요?' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: style.textStrong),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right_rounded, color: style.textMuted),
          ]),
    );
    // 진행 중엔 차오름 위에서 읽혀야 하므로 눌림 비활성 흐림을 쓰지 않는다
    return enabled
        ? PressScale(onTap: () => showTaskSheet(context), child: card)
        : card;
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final style = s.scene.style;
    return SizedBox(
      height: MobileSize.row,
      child: Row(children: [
        _Chip(
          state: s,
          leading: SceneBullet(scene: s.scene, selected: true, moon: true),
          label: style.sceneLabel,
          onTap: () => s.setScene(s.scene.next),
        ),
        const Spacer(),
        RoundIconButton(
          size: MobileSize.touchMin,
          style: style,
          icon: s.soundEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: '집중 소리',
          onTap: () => showSoundSheet(context),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          size: MobileSize.touchMin,
          style: style,
          icon: !s.lockEnabled
              ? Icons.lock_open_rounded
              : (s.lockReady ? Icons.lock_rounded : Icons.no_encryption_rounded),
          tooltip: !s.lockEnabled
              ? '앱 잠금'
              : (s.lockReady ? '앱 잠금 켜짐' : '앱 잠금 꺼짐, 권한을 확인해 주세요'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LockPage())),
        ),
      ]),
    );
  }
}

/// 시작. 잠금을 켜 뒀는데 걸 수 없거나, 잠금 화면 남은 시간(실시간 현황)이 꺼져 있으면
/// 집중은 시작하되 바로 알려 준다.
Future<void> _startFocus(BuildContext context, AppState s) async {
  s.startTimer(allowNoTask: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void show(String text, [SnackBarAction? action]) => messenger?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      // 시작 10초 동안만 있는 취소 버튼을 가리지 않게 위로 띄운다
      margin: const EdgeInsets.only(
          left: MobileSize.gutter,
          right: MobileSize.gutter,
          bottom: MobileSize.cta * 2),
      content: Text(text),
      action: action));
  if (s.lockEnabled && !s.lockReady) {
    show('앱 잠금이 꺼져 있어요. 자물쇠에서 권한을 확인해 주세요');
    return;
  }
  // 잠금 화면의 '허용 안 함'은 다시 묻지 않아 iOS 설정에서만 켤 수 있다
  if (!await SessionNotifier.liveActivitiesEnabled()) {
    show('잠금 화면에 남은 시간 보기가 꺼져 있어요',
        SnackBarAction(label: '켜기', onPressed: () => launchUrl(Uri.parse('app-settings:'))));
  }
}

class _RunningBadge extends StatelessWidget {
  const _RunningBadge({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    return SizedBox(
      height: MobileSize.row,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _Chip(
          state: state,
          dot: style.ringProgress,
          label: state.phase == FocusPhase.breakTime
              ? '휴식 중'
              : (state.isRunning ? '집중 중' : '일시정지'),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.state,
      required this.label,
      this.leading,
      this.dot,
      this.onTap});
  final AppState state;
  final String label;
  final Widget? leading;
  final Color? dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: MobileSize.row),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        if (dot != null) ...[
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: style.textStrong)),
        if (onTap != null && leading == null) ...[
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 18, color: style.textMuted),
        ],
      ]),
    );
    return onTap == null ? chip : PressScale(onTap: onTap, child: chip);
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});
  final AppState state;

  Future<void> _confirmAbandon(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여기서 그만둘까요?'),
        content: const Text('10초가 지나면 끝날 때까지 그만둘 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('그만두기')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
        ],
      ),
    );
    if (ok == true) state.abandonSession();
  }

  Future<void> _confirmEscape(BuildContext context) async {
    final cost = state.escapeCost;
    final short = cost - state.drops;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(short > 0
            ? '물방울이 $short개 부족해요'
            : '물방울 $cost개로 지금 끝낼까요?'),
        content: Text(short > 0
            ? '남은 1분마다 2개가 필요해요. 지금 ${state.drops}개 있어요.'
            : '남은 1분마다 2개예요. 집중한 시간은 기록되지만 친구는 오지 않아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('계속하기')),
          if (short <= 0)
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('끝내기')),
        ],
      ),
    );
    if (ok == true && state.escapeSession()) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final style = s.scene.style;
    // 핵심 기능이라 아이콘만 두지 않고 라벨을 붙인다
    final memo = Semantics(
      button: true,
      label: '딴생각 메모',
      onTap: () => showMemoSheet(context),
      excludeSemantics: true,
      child: PressScale(
        onTap: () => showMemoSheet(context),
        child: Container(
          height: MobileSize.cta,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadow.card(style.rowShadow),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_note_rounded, size: 22, color: style.textStrong),
            const SizedBox(width: 4),
            Text('메모',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: style.textStrong)),
          ]),
        ),
      ),
    );
    if (s.phase == FocusPhase.breakTime) {
      return Row(children: [
        Expanded(
          child: PillButton(
              style: style,
              width: double.infinity,
              height: MobileSize.cta,
              icon: Icons.skip_next_rounded,
              label: '휴식 건너뛰기',
              onTap: s.skipBreak),
        ),
      ]);
    }
    if (s.activeSession == null) {
      return Row(children: [
        Expanded(
          child: PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.play_arrow_rounded,
            label: '시작',
            onTap: () => _startFocus(context, s),
          ),
        ),
        const SizedBox(width: 12),
        memo,
      ]);
    }
    // 그만두기도 막는다(사용자 결정 2026-10-11) — 10초 안엔 취소, 그 뒤엔 물방울로 비상 탈출.
    // 예전 버전에서 일시정지해 둔 세션은 갇히지 않게 그대로 그만둘 수 있다.
    final canCancel =
        !s.isRunning || s.totalSeconds - s.remainingSeconds < 10;
    return Row(children: [
      RoundIconButton(
        style: style,
        size: MobileSize.cta,
        icon: canCancel ? Icons.close_rounded : Icons.water_drop_outlined,
        tooltip: canCancel ? '그만두기' : '물방울로 끝내기',
        onTap: () => canCancel
            ? _confirmAbandon(context)
            : _confirmEscape(context),
      ),
      const SizedBox(width: 12),
      // 폰은 일시정지 없음(집중 강제, 사용자 결정 2026-10-11) — 딴생각은 메모로 던지고 계속.
      // 예전 버전에서 일시정지해 둔 세션만 '계속'으로 이어갈 수 있다.
      Expanded(
        child: s.isRunning
            ? PillButton(
                style: style,
                width: double.infinity,
                height: MobileSize.cta,
                icon: Icons.edit_note_rounded,
                label: '딴생각 메모',
                onTap: () => showMemoSheet(context),
              )
            : PillButton(
                style: style,
                width: double.infinity,
                height: MobileSize.cta,
                icon: Icons.play_arrow_rounded,
                label: '계속',
                onTap: () => _startFocus(context, s),
              ),
      ),
      if (!s.isRunning) ...[const SizedBox(width: 12), memo],
    ]);
  }
}
