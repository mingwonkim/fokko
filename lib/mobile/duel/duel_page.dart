// lib/mobile/duel/duel_page.dart
// 친구 1:1 대결: 이번 주(월~일, KST) 집중 시간 승부. 기록 탭 요약 카드 + 전체 화면(초대·코드 입력·끊기).
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../models/focus_title.dart';
import '../../services/ranking_service.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';
import '../records/ranking_page.dart';
import '../share/share_card.dart' show hm;
import '../widgets/title_avatar.dart';
import 'invite.dart';

/// 이번 주 남은 날 (일요일이면 0 = 오늘 끝)
int daysLeft(DateTime now) => DateTime.sunday - now.weekday;

String _deadline(DateTime now) =>
    daysLeft(now) == 0 ? '오늘 밤 12시 마감' : '일요일 마감 · ${daysLeft(now)}일 남음';

String acceptError(Object e) {
  final m = '$e';
  if (m.contains('bad code')) return '없는 초대 코드예요';
  if (m.contains('own code')) return '내 초대 코드예요';
  if (m.contains('join first')) return '명예의 전당에 먼저 참여해 주세요';
  if (m.contains('too many')) return '친구는 30명까지예요';
  return '연결하지 못했어요. 잠시 뒤 다시 해 주세요';
}

/// 기록 탭 요약: 대결 최대 3개 + 카톡 초대
class DuelCard extends StatefulWidget {
  const DuelCard({super.key});

  @override
  State<DuelCard> createState() => _DuelCardState();
}

class _DuelCardState extends State<DuelCard> {
  Future<List<Duel>>? _duels;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final joined = context.read<AppState>().rankNickname != null;
    final f = joined ? context.read<RankingService>().duels() : null;
    setState(() {
      _duels = f;
    });
  }

  Future<void> _open() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DuelPage()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: MobileSize.cardGap),
      padding: const EdgeInsets.all(MobileSize.cardPadding),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: _open,
          child: Row(children: [
            Icon(Icons.sports_kabaddi_rounded, color: style.accent),
            const SizedBox(width: MobileSize.iconGap),
            Text('이번 주 1:1 대결',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: style.textStrong)),
            const Spacer(),
            Text(_deadline(now),
                style: TextStyle(fontSize: 12, color: style.textMuted)),
            Icon(Icons.chevron_right_rounded, color: style.textMuted),
          ]),
        ),
        const SizedBox(height: MobileSize.cardGap),
        if (s.rankNickname == null)
          _Hint(
              style: style,
              text: '명예의 전당에 참여하면 친구와 이번 주 집중 시간으로 겨룰 수 있어요',
              action: '참여하러 가기',
              onTap: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RankingPage()));
                if (mounted) _load();
              })
        else
          FutureBuilder<List<Duel>>(
            future: _duels,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: MobileSize.row,
                    child: Center(child: CircularProgressIndicator()));
              }
              final duels = snap.data ?? const [];
              if (snap.hasError) {
                return _Hint(
                    style: style,
                    text: '대결을 불러오지 못했어요',
                    action: '다시',
                    onTap: _load);
              }
              return Column(children: [
                if (duels.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: MobileSize.cardGap),
                    child: Text(
                        '카톡으로 친구를 불러 이번 주 누가 더 오래 집중하는지 겨뤄 보세요.',
                        style:
                            TextStyle(fontSize: 14, color: style.textMuted)),
                  ),
                for (final d in duels.take(3)) DuelRow(duel: d),
                InviteButton(onDone: _load),
              ]);
            },
          ),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(
      {required this.style,
      required this.text,
      required this.action,
      required this.onTap});
  final SceneStyle style;
  final String text, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, color: style.textMuted))),
        TextButton(
            onPressed: onTap,
            child: Text(action, style: TextStyle(color: style.accent))),
      ]);
}

/// 카톡으로 초대 (코드 받아서 카드 전송)
class InviteButton extends StatefulWidget {
  const InviteButton({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  State<InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<InviteButton> {
  bool _busy = false;

  Future<void> _invite() async {
    if (_busy) return;
    final s = context.read<AppState>();
    final svc = context.read<RankingService>();
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final code = await svc.inviteCode();
      await sendInvite(s.rankNickname ?? '친구', code, origin: origin);
      widget.onDone?.call();
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('초대를 만들지 못했어요. 잠시 뒤 다시 해 주세요')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = context.watch<AppState>().scene.style;
    return PillButton(
      style: style,
      width: double.infinity,
      height: MobileSize.cta,
      icon: Icons.chat_bubble_rounded,
      label: _busy ? '초대 만드는 중…' : '카톡으로 친구 초대',
      onTap: _invite,
    );
  }
}

/// 나 vs 친구: 양쪽 아바타·이번 주 분·줄다리기 막대·상태 한 줄
class DuelRow extends StatelessWidget {
  const DuelRow(
      {super.key, required this.duel, this.onLongPress, this.onPage = false});
  final Duel duel;
  final VoidCallback? onLongPress;
  final bool onPage; // 전체 화면(배경이 cardBg)이면 행을 rowBg로

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final d = duel;
    final theirTitle = FocusTitle.of(d.totalMinutes);
    final theirColor = TitleRings.all[theirTitle.index].colors.first;
    final gap = d.myWeek - d.theirWeek;
    final (status, statusColor) = gap > 0
        ? ('${hm(gap)} 앞서는 중', style.accent)
        : gap < 0
            ? ('${hm(-gap)} 뒤처짐 · 지금 집중하면 따라잡아요', style.textStrong)
            : (d.myWeek == 0 ? '아직 0:0, 먼저 집중하면 앞서요' : '동점!', style.textStrong);
    Widget minutes(int m, TextAlign align) => Text(hm(m),
        textAlign: align,
        style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: style.textStrong));
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: MobileSize.cardGap),
        padding: const EdgeInsets.all(MobileSize.cardPadding - 4),
        decoration: BoxDecoration(
          color: onPage ? style.rowBg : style.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: onPage ? AppShadow.card(style.rowShadow) : null,
          border: gap > 0 ? Border.all(color: style.accent, width: 1.5) : null,
        ),
        child: Column(children: [
          Row(children: [
            TitleAvatar(
                title: s.title,
                asset: s.selectedCompanion.asset,
                background: style.rowBg,
                size: MobileSize.avatarRow + 4),
            const SizedBox(width: MobileSize.iconGap),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('나',
                        style: TextStyle(fontSize: 12, color: style.textMuted)),
                    minutes(d.myWeek, TextAlign.start),
                  ]),
            ),
            Text('VS',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: style.textMuted)),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(d.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: style.textMuted)),
                    minutes(d.theirWeek, TextAlign.end),
                  ]),
            ),
            const SizedBox(width: MobileSize.iconGap),
            TitleAvatar(
                title: theirTitle,
                asset: Companion.byId(d.avatar)?.asset ?? '',
                background: style.rowBg,
                size: MobileSize.avatarRow + 4),
          ]),
          const SizedBox(height: MobileSize.cardGap),
          // 줄다리기 막대: 내 몫(왼쪽) vs 친구 몫(오른쪽)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                Expanded(
                    flex: d.myWeek + 1, child: Container(color: style.accent)),
                const SizedBox(width: 2),
                Expanded(
                    flex: d.theirWeek + 1, child: Container(color: theirColor)),
              ]),
            ),
          ),
          const SizedBox(height: MobileSize.labelGap + 2),
          Row(children: [
            Expanded(
              child: Text(status,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            if (d.wins + d.losses + d.draws > 0)
              Text(
                  '전적 ${d.wins}승 ${d.losses}패${d.draws > 0 ? ' ${d.draws}무' : ''}',
                  style: TextStyle(fontSize: 12, color: style.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

/// 전체 대결 화면. [initialCode]가 있으면 열자마자 초대 수락.
class DuelPage extends StatefulWidget {
  const DuelPage({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends State<DuelPage> {
  Future<List<Duel>>? _duels;
  String? _pending; // 참여 전에 받은 초대

  @override
  void initState() {
    super.initState();
    _pending = widget.initialCode;
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptPending());
  }

  void _load() {
    final joined = context.read<AppState>().rankNickname != null;
    final f = joined ? context.read<RankingService>().duels() : null;
    setState(() {
      _duels = f;
    });
  }

  Future<void> _acceptPending() async {
    final code = _pending;
    if (code == null || !mounted) return;
    if (context.read<AppState>().rankNickname == null) return; // 참여 안내가 보임
    _pending = null;
    await _accept(code);
  }

  Future<void> _accept(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nick = await context.read<RankingService>().acceptInvite(code);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(content: Text('$nick님과 대결 시작!')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(acceptError(e))));
    }
  }

  Future<void> _enterCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대 코드 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '예: K7M2QX'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('대결 시작')),
        ],
      ),
    );
    ctrl.dispose();
    if (code != null && code.trim().isNotEmpty) await _accept(code);
  }

  Future<void> _remove(Duel d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${d.nickname}님과 대결을 그만할까요?'),
        content: const Text('전적도 함께 사라져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('그만하기')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<RankingService>().removeFriend(d.code);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    return Scaffold(
      backgroundColor: style.cardBg,
      appBar: AppBar(
        backgroundColor: style.cardBg,
        title: Text('1:1 대결',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: style.textStrong)),
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 8,
              MobileSize.gutter, MobileSize.contentBottomGap),
          children: [
            Text('월요일부터 일요일까지 끝까지 마친 집중 시간으로 겨뤄요. ${_deadline(DateTime.now())}',
                style: TextStyle(fontSize: 14, color: style.textMuted)),
            const SizedBox(height: MobileSize.sectionGap - 8),
            if (s.rankNickname == null)
              _Hint(
                style: style,
                text: _pending == null
                    ? '대결하려면 명예의 전당 닉네임이 필요해요'
                    : '초대를 받았어요! 닉네임을 정하면 바로 대결이 시작돼요',
                action: '참여하기',
                onTap: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RankingPage()));
                  if (!mounted) return;
                  _load();
                  await _acceptPending();
                },
              )
            else ...[
              FutureBuilder<List<Duel>>(
                future: _duels,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                        padding: EdgeInsets.all(MobileSize.sectionGap),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return _Hint(
                        style: style,
                        text: '대결을 불러오지 못했어요',
                        action: '다시',
                        onTap: _load);
                  }
                  final duels = snap.data!;
                  final ahead = duels.where((d) => d.myWeek > d.theirWeek).length;
                  return Column(children: [
                    if (duels.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: MobileSize.cardGap),
                        child: Row(children: [
                          Text('${duels.length}명 중 $ahead명에게 앞서는 중',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: style.textStrong)),
                        ]),
                      ),
                    for (final d in duels)
                      DuelRow(
                          duel: d, onPage: true, onLongPress: () => _remove(d)),
                    if (duels.isNotEmpty)
                      Text('길게 누르면 대결을 그만할 수 있어요',
                          style:
                              TextStyle(fontSize: 12, color: style.textMuted)),
                  ]);
                },
              ),
              const SizedBox(height: MobileSize.sectionGap - 8),
              InviteButton(onDone: _load),
              const SizedBox(height: MobileSize.cardGap),
              Center(
                child: TextButton.icon(
                  onPressed: _enterCode,
                  icon: Icon(Icons.keyboard_rounded, color: style.accent),
                  label: Text('받은 초대 코드 입력',
                      style: TextStyle(color: style.accent)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
