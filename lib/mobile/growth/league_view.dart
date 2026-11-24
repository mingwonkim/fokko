// lib/mobile/growth/league_view.dart
// 성장 탭 → 리그: 참여 안내, 등급, 이번 주 조 순위, 지난 주 결과.
import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../models/focus_title.dart';
import '../../models/growth.dart';
import '../../models/league.dart';
import '../../services/ranking_service.dart';
import '../../state/app_state.dart';
import '../records/ranking_page.dart';
import '../widgets/title_avatar.dart';

class LeagueView extends StatefulWidget {
  const LeagueView({super.key});

  @override
  State<LeagueView> createState() => _LeagueViewState();
}

class _LeagueViewState extends State<LeagueView> {
  late Future<LeagueStatus> _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = _fetch();
  }

  Future<LeagueStatus> _fetch() async {
    final s = context.read<AppState>();
    if (s.rankNickname == null) return const LeagueStatus(joined: false);
    final status = await context.read<RankingService>().leagueStatus();
    s.setLeagueJoined(status.joined); // 서버가 원본
    return status;
  }

  void _reload() => setState(() {
        _status = _fetch();
      });

  Future<void> _join() async {
    if (_busy) return;
    final s = context.read<AppState>();
    final svc = context.read<RankingService>();
    setState(() => _busy = true);
    try {
      await svc.joinLeague();
      s.setLeagueJoined(true);
      if (mounted) _reload();
    } catch (e) {
      debugPrint('league join: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연결이 안 돼요. 잠시 뒤 다시 해 주세요.')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리그에서 나갈까요?'),
        content: const Text('등급이 처음으로 돌아가요. 내 기록과 물방울은 그대로예요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('아니요')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('나가기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final s = context.read<AppState>();
    try {
      await context.read<RankingService>().leaveLeague();
      s.setLeagueJoined(false);
      if (mounted) _reload();
    } catch (e) {
      debugPrint('league leave: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연결이 안 돼요. 잠시 뒤 다시 해 주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    return FutureBuilder<LeagueStatus>(
      future: _status,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: TextButton(
                onPressed: _reload,
                child: Text('연결이 안 돼요. 다시 시도',
                    style: TextStyle(color: style.accent))),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final status = snap.data!;
        if (!status.joined) return _intro(context, s, style);
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: _board(context, status, style),
        );
      },
    );
  }

  Widget _intro(BuildContext context, AppState s, SceneStyle style) {
    final named = s.rankNickname != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 0, MobileSize.gutter,
          MobileSize.sectionGap),
      children: [
        Container(
          padding: const EdgeInsets.all(MobileSize.cardPadding),
          decoration: _card(style),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('주간 리그',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: style.textStrong)),
            const SizedBox(height: MobileSize.cardGap),
            for (final line in const [
              '비슷한 등급의 최대 10명과 이번 주 집중 시간을 겨뤄요.',
              '잘하면 다음 주에 등급이 오르고, 산책·탐험·항해 3등급이에요.',
              '앱에서 시작해 끝까지 마친 집중만 들어가요.',
              '다른 참여자에게 닉네임과 친구 그림, 이번 주 시간이 보여요.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: MobileSize.labelGap),
                child: Text(line,
                    style: TextStyle(fontSize: 14, color: style.textMuted)),
              ),
            const SizedBox(height: MobileSize.gridGap),
            PillButton(
              style: style,
              width: double.infinity,
              height: MobileSize.cta,
              icon: Icons.emoji_events_rounded,
              label: named ? '리그 참여하기' : '명예의 전당에 먼저 참여하기',
              onTap: _busy
                  ? null
                  : named
                      ? _join
                      : () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const RankingPage()));
                          if (mounted) _reload();
                        },
            ),
          ]),
        ),
      ],
    );
  }

  Widget _board(BuildContext context, LeagueStatus st, SceneStyle style) {
    final now = clock.now();
    final left = DateTime.sunday - now.weekday + 1;
    final last = st.lastResult;
    final showLast = last != null &&
        st.week != null &&
        last.week == addDays(st.week!, -7);
    final rows = st.board;
    return ListView(
      padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 0, MobileSize.gutter,
          MobileSize.sectionGap),
      children: [
        Container(
          padding: const EdgeInsets.all(MobileSize.cardPadding),
          decoration: _card(style),
          child: Column(children: [
            Row(children: [
              for (final t in LeagueTier.values)
                Expanded(
                  child: Semantics(
                    selected: t == st.tier,
                    label: '${t.label} 등급',
                    excludeSemantics: true,
                    child: Column(children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: t == st.tier
                            ? MobileSize.leagueIconLarge
                            : MobileSize.leagueIcon,
                        color: t.index <= st.tier.index
                            ? style.accent
                            : style.divider,
                      ),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  t == st.tier ? FontWeight.w700 : FontWeight.w400,
                              color: t == st.tier
                                  ? style.textStrong
                                  : style.textMuted)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: MobileSize.cardGap),
            Text('이번 주 $left일 남음',
                style: TextStyle(fontSize: 13, color: style.textMuted)),
          ]),
        ),
        if (showLast) ...[
          const SizedBox(height: MobileSize.cardGap),
          Container(
            padding: const EdgeInsets.all(MobileSize.cardPadding),
            decoration: _card(style),
            child: Text(
              '지난 주 ${last.rank}위 · ${last.minutes}분 · ${_resultText(last)}',
              style: TextStyle(fontSize: 14, color: style.textStrong),
            ),
          ),
        ],
        const SizedBox(height: MobileSize.cardGap),
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(MobileSize.cardPadding),
            decoration: _card(style),
            child: Text('이번 주 첫 집중을 끝내면 조가 정해져요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: style.textMuted)),
          )
        else ...[
          if (st.smallGroup)
            Padding(
              padding: const EdgeInsets.only(bottom: MobileSize.cardGap),
              child: Text(
                  st.tier == LeagueTier.voyage
                      ? '가장 높은 등급이에요'
                      : '이번 주 ${LeagueStatus.smallGroupGoal}분을 채우면 등급이 올라요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: style.textMuted)),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            _LeagueRowTile(row: rows[i], style: style),
            if (i + 1 == st.promoteCount)
              _ZoneLine(
                  style: style,
                  icon: Icons.keyboard_arrow_up_rounded,
                  text: '여기까지 승급'),
            if (st.demoteCount > 0 && i + 1 == rows.length - st.demoteCount)
              _ZoneLine(
                  style: style,
                  icon: Icons.keyboard_arrow_down_rounded,
                  text: '아래는 한 등급 내려가요'),
          ],
        ],
        const SizedBox(height: MobileSize.gridGap),
        Center(
          child: TextButton(
            onPressed: _leave,
            child: Text('리그에서 나가기', style: TextStyle(color: style.textMuted)),
          ),
        ),
      ],
    );
  }

  String _resultText(LeagueResult r) {
    if (r.to.index > r.from.index) return '${r.to.label} 등급으로 올라갔어요';
    if (r.to.index < r.from.index) return '${r.to.label} 등급에서 다시 시작해요';
    return '${r.to.label} 등급 유지';
  }
}

BoxDecoration _card(SceneStyle style) => BoxDecoration(
      color: style.rowBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: AppShadow.card(style.rowShadow),
    );

class _ZoneLine extends StatelessWidget {
  const _ZoneLine({required this.style, required this.icon, required this.text});
  final SceneStyle style;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: MobileSize.cardGap),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: MobileSize.zoneIcon, color: style.accent),
          const SizedBox(width: MobileSize.labelGap),
          Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: style.accent)),
          ),
        ]),
      );
}

class _LeagueRowTile extends StatelessWidget {
  const _LeagueRowTile({required this.row, required this.style});
  final LeagueRow row;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: MobileSize.cardGap),
        child: Semantics(
          container: true,
          label: '${row.rank}위 ${row.nickname}${row.isMe ? ' 나' : ''}, ${row.minutes}분',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MobileSize.cardPadding, vertical: MobileSize.gridGap),
            decoration: _card(style).copyWith(
              border: row.isMe ? Border.all(color: style.accent, width: 2) : null,
            ),
            child: Row(children: [
              SizedBox(
                width: MobileSize.leagueRank,
                child: Text('${row.rank}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: style.textMuted)),
              ),
              TitleAvatar(
                title: FocusTitle.of(row.totalMinutes),
                asset: Companion.byId(row.avatar)?.asset ?? '',
                background: style.cardBg,
                size: MobileSize.avatarRow,
              ),
              const SizedBox(width: MobileSize.gridGap),
              Expanded(
                child: Text(row.isMe ? '${row.nickname} (나)' : row.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.textStrong)),
              ),
              Text('${row.minutes}분',
                  style: TextStyle(
                      fontSize: 15,
                      color: style.textStrong,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      );
}
