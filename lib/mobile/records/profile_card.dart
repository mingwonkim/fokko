// lib/mobile/records/profile_card.dart
// 기록 탭 맨 위 프로필: 칭호 테두리 아바타 · 닉네임 · 칭호 · 다음 칭호까지 · 명예의 전당 · 자랑하기.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../state/app_state.dart';
import '../share/share_card.dart';
import '../widgets/title_avatar.dart';
import 'ranking_page.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final title = s.title;
    final total = s.focusMinutesTotal;
    final next = title.next;
    return Container(
      margin: const EdgeInsets.only(bottom: MobileSize.cardGap),
      padding: const EdgeInsets.all(MobileSize.cardPadding),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TitleAvatar(
            title: title,
            asset: s.selectedCompanion.asset,
            background: style.cardBg,
            size: MobileSize.avatar + 8,
          ),
          const SizedBox(width: MobileSize.cardPadding - 4),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.rankNickname ?? '나',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: style.textStrong)),
              const SizedBox(height: MobileSize.labelGap),
              TitleBadge(
                  title: title,
                  textColor: style.textStrong,
                  height: MobileSize.badgeLarge),
            ]),
          ),
          IconButton(
            tooltip: '자랑하기',
            icon: Icon(Icons.ios_share_rounded, color: style.accent),
            onPressed: () => showShareSheet(context),
          ),
        ]),
        const SizedBox(height: MobileSize.cardGap + 4),
        // 칭호 여정 10단계
        TitleLadder(title: title, track: style.ringTrack),
        const SizedBox(height: MobileSize.cardGap + 4),
        // 다음 목표
        Container(
          padding: const EdgeInsets.all(MobileSize.cardPadding - 4),
          decoration: BoxDecoration(
            color: style.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: next == null
              ? Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: TitleRings.all[title.index].colors.first),
                  const SizedBox(width: MobileSize.iconGap),
                  Expanded(
                    child: Text('가장 높은 칭호에 올랐어요',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: style.textStrong)),
                  ),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(children: [
                        TitleAvatar(
                          title: next,
                          asset: s.selectedCompanion.asset,
                          background: style.rowBg,
                          size: MobileSize.avatarRow + 4,
                        ),
                        const SizedBox(width: MobileSize.iconGap + 4),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('다음 목표',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: style.textMuted)),
                                Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                        text: '${hm(title.remaining(total))} 더 집중하면 ',
                                        style: TextStyle(color: style.textMuted)),
                                    TextSpan(
                                        text: '\'${next.label}\'',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: style.textStrong)),
                                  ]),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ]),
                        ),
                        Text('${(title.progress(total) * 100).floor()}%',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: style.textStrong)),
                      ]),
                      const SizedBox(height: MobileSize.cardGap),
                      _GradientBar(
                        value: title.progress(total),
                        colors: TitleRings.all[next.index].colors,
                        track: style.ringTrack,
                      ),
                    ]),
        ),
        Divider(height: MobileSize.sectionGap, color: style.divider),
        InkWell(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankingPage())),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: MobileSize.touchMin - 8),
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: style.accent),
              const SizedBox(width: MobileSize.iconGap),
              Text('명예의 전당',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: style.textStrong)),
              const Spacer(),
              Text(s.rankNickname == null ? '참여하기' : '이번 주 · 이번 달',
                  style: TextStyle(fontSize: 13, color: style.textMuted)),
              Icon(Icons.chevron_right_rounded, color: style.textMuted),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 다음 칭호 링 색으로 채우는 진행 막대
class _GradientBar extends StatelessWidget {
  const _GradientBar(
      {required this.value, required this.colors, required this.track});
  final double value;
  final List<Color> colors;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: 8,
          color: track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.02, 1),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: colors.length == 1 ? [colors.first, colors.first] : colors),
              ),
            ),
          ),
        ),
      );
}
