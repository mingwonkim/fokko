// lib/mobile/focus/sheets.dart
// 집중 홈의 하단 시트들: 할 일 / 태그 / 친구 / 딴생각 메모 / 보상
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../models/growth.dart';
import '../../models/focus_title.dart';
import '../../state/app_state.dart';
import '../share/share_card.dart';
import '../widgets/title_avatar.dart';

Future<T?> showFocusSheet<T>(
    BuildContext context, String title, WidgetBuilder body) {
  final style = context.read<AppState>().scene.style;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: style.rowBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(MobileSize.sheetRadius))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                    color: style.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 8, 8, 12), // 제목–본문 16
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: style.textStrong)),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: Icon(Icons.close_rounded, color: style.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(child: body(ctx)),
          ],
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.child, this.selected = false, this.onTap});
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = context.watch<AppState>().scene.style;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: style.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: selected ? style.accent : Colors.transparent, width: 2),
        ),
        child: child,
      ),
    );
  }
}

class _AddField extends StatefulWidget {
  const _AddField({required this.hint, required this.onSubmit});
  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = context.watch<AppState>().scene.style;
    return TextField(
      controller: _c,
      onSubmitted: (v) {
        widget.onSubmit(v);
        _c.clear();
      },
      style: TextStyle(fontSize: 16, color: style.textStrong),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(Icons.add_rounded, color: style.textMuted),
        filled: true,
        fillColor: style.cardBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 18), // 행 56과 같은 높이
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none),
      ),
    );
  }
}

/// 할 일 선택: 미완료 목록 + 추가 + 선택 없이
Future<void> showTaskSheet(BuildContext context) =>
    showFocusSheet(context, '지금 할 일', (ctx) {
      return Consumer<AppState>(builder: (_, s, __) {
        final style = s.scene.style;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 4, MobileSize.gutter, 24),
          children: [
            for (final t in s.pendingTasks)
              _Row(
                selected: s.currentTask?.id == t.id,
                onTap: () {
                  s.selectTask(t.id);
                  Navigator.pop(ctx);
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: style.textStrong)),
                ),
              ),
            _AddField(
              hint: '할 일 추가',
              onSubmit: (v) {
                s.addTask(v, setAsCurrent: true);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: AppSpacing.s16),
            TextButton(
              onPressed: () {
                s.clearCurrentTask();
                Navigator.pop(ctx);
              },
              child: Text('할 일 없이 태그만으로 집중',
                  style: TextStyle(color: style.textMuted)),
            ),
          ],
        );
      });
    });

/// 태그 선택·추가
Future<void> showTagSheet(BuildContext context) =>
    showFocusSheet(context, '태그', (ctx) {
      return Consumer<AppState>(builder: (_, s, __) {
        final style = s.scene.style;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 4, MobileSize.gutter, 24),
          children: [
            for (final t in s.tags)
              _Row(
                selected: s.currentTag?.id == t.id,
                onTap: () {
                  s.selectTag(t.id);
                  Navigator.pop(ctx);
                },
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: tagColor(style, t.colorIndex),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Text(t.name,
                      style: TextStyle(fontSize: 16, color: style.textStrong)),
                ]),
              ),
            _AddField(hint: '새 태그', onSubmit: s.addTag),
          ],
        );
      });
    });

/// 태그 색: 장면 링 색 기준 명도 변화 (강조색 하나 원칙)
Color tagColor(SceneStyle style, int i) {
  const k = [1.0, 0.7, 0.45, 0.85, 0.6];
  return Color.lerp(style.cardBg, style.ringProgress, k[i % k.length])!;
}

/// 데려올 친구: 현재 장면 2열, 잠김은 실루엣 + 남은 분
Future<void> showCompanionSheet(BuildContext context) =>
    showFocusSheet(context, '데려올 친구', (ctx) {
      return Consumer<AppState>(builder: (_, s, __) {
        final style = s.scene.style;
        final done = s.sceneMinutes(s.scene);
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 169 / 156,
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 4, MobileSize.gutter, 24),
          children: [
            for (final c in Companion.of(s.scene))
              PressScale(
                onTap: s.isUnlocked(c)
                    ? () {
                        s.selectCompanion(c.id);
                        Navigator.pop(ctx);
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: style.cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: s.selectedCompanion.id == c.id
                            ? style.accent
                            : Colors.transparent,
                        width: 2),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Expanded(
                      child: s.isUnlocked(c)
                          ? Image.asset(c.asset)
                          : ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  style.divider, BlendMode.srcIn),
                              child: Image.asset(c.asset)),
                    ),
                    Text(c.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: style.textStrong)),
                    if (!s.isUnlocked(c))
                      Text('${c.unlockMinutes - done}분 더',
                          style:
                              TextStyle(fontSize: 12, color: style.textMuted)),
                  ]),
                ),
              ),
          ],
        );
      });
    });

/// 딴생각 메모: 저장하면 바로 닫히고 타이머는 그대로
Future<void> showMemoSheet(BuildContext context) =>
    showFocusSheet(context, '딴생각 메모', (ctx) => const _MemoBody());

class _MemoBody extends StatefulWidget {
  const _MemoBody();

  @override
  State<_MemoBody> createState() => _MemoBodyState();
}

class _MemoBodyState extends State<_MemoBody> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    if (_c.text.trim().isEmpty) return;
    context.read<AppState>().addToInbox(_c.text);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final style = context.watch<AppState>().scene.style;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MobileSize.gutter, 4, MobileSize.gutter, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _c,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          style: TextStyle(fontSize: 16, color: style.textStrong),
          decoration: InputDecoration(
            hintText: '떠오른 생각을 적고 다시 집중',
            filled: true,
            fillColor: style.cardBg,
            contentPadding: const EdgeInsets.all(MobileSize.cardPadding),
            constraints: const BoxConstraints(minHeight: MobileSize.fieldMinHeight),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        PillButton(
          style: style,
          width: double.infinity,
          height: MobileSize.cta,
          icon: Icons.check_rounded,
          label: '저장하고 돌아가기',
          onTap: _c.text.trim().isEmpty ? null : _save,
        ),
      ]),
    );
  }
}

/// 보상: 친구 팝(.85→1 easeOutBack) + 햅틱, 물방울
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.style, required this.text});
  final SceneStyle style;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: MobileSize.row),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: style.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: style.textStrong)),
      );
}

Future<void> showRewardSheet(BuildContext context) {
  final s = context.read<AppState>();
  final r = s.lastReward;
  if (r == null) return Future.value();
  final c = Companion.byId(r.companionId);
  final drops = (r.focusedSec ?? 0) ~/ 60;
  final promoted = s.lastPromotion;
  promoted != null || s.lastStreakExtended != null
      ? HapticFeedback.heavyImpact()
      : HapticFeedback.mediumImpact();
  return showFocusSheet(context, '집중 완료', (ctx) {
    final style = s.scene.style;
    final reduce = MediaQuery.maybeDisableAnimationsOf(ctx) ?? false;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          MobileSize.gutter, 0, MobileSize.gutter, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${r.minutes}분 동안 집중했어요',
            style: TextStyle(fontSize: 13, color: style.textMuted)),
        const SizedBox(height: 12),
        if (s.lastStreakExtended case final days?) ...[
          _StreakBanner(
              days: days, asset: c?.asset ?? '', state: s, reduce: reduce),
          const SizedBox(height: 12),
        ],
        if (promoted != null) ...[
          _Promotion(style: style, title: promoted, asset: c?.asset ?? ''),
          const SizedBox(height: 12),
        ],
        if (c != null && promoted == null) // 승급이면 친구는 새 테두리 안에 보인다
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduce ? 1 : 0.85, end: 1),
            duration:
                reduce ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Image.asset(c.asset, width: 144, height: 144),
          ),
        if (c != null)
          Text(c.isStarter ? '${c.name}와(과) 함께 집중했어요' : '${c.name}이(가) 왔어요',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: style.textStrong)),
        const SizedBox(height: 12),
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: style.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Text('💧 물방울 +$drops',
              style: TextStyle(fontSize: 16, color: style.textStrong)),
        ),
        if (MapNode.levelOf(s.xp - r.minutes) != s.level) ...[
          const SizedBox(height: 8),
          _RewardRow(style: style, text: '레벨 업! 이제 Lv.${s.level}'),
        ],
        for (final g in s.lastQuestRewards) ...[
          const SizedBox(height: 8),
          _RewardRow(
            style: style,
            text: switch (g.kind) {
              QuestKind.firstSession => '오늘 첫 집중 · 물방울 +${g.drops}',
              QuestKind.dailyGoal => '오늘 목표 달성 · 물방울 +${g.drops}',
              QuestKind.dailyLong =>
                '오늘 ${g.kind.minutes}분 달성 · 물방울 +${g.drops}',
              QuestKind.weeklyGoal =>
                '이번 주 목표 달성 · 물방울 +${g.drops}${g.ice > 0 ? ' · 얼음 +${g.ice}' : ''}',
              QuestKind.weeklyHalf || QuestKind.weeklyFull =>
                '이번 주 ${g.kind.minutes}분 달성 · 물방울 +${g.drops}',
            },
          ),
        ],
        if (s.lastStreakExtended == null) ...[
          const SizedBox(height: 8),
          _RewardRow(style: style, text: '연속 ${s.streakDays}일'),
        ],
        if (c != null &&
            CompanionStage.of(s.companionMinutes(c.id) - r.minutes) !=
                s.companionStage(c.id)) ...[
          const SizedBox(height: 8),
          _RewardRow(
              style: style,
              text: '${c.name}이(가) ${s.companionStage(c.id).label}이 됐어요'),
        ],
        if (r.taskId.isNotEmpty &&
            s.pendingTasks.any((t) => t.id == r.taskId)) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              s.completeTask(r.taskId);
              HapticFeedback.lightImpact();
            },
            icon: Icon(Icons.check_circle_outline_rounded, color: style.accent),
            label: Text('"${r.taskTitle}" 끝냈어요',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: style.accent)),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: PillButton(
              style: style,
              width: double.infinity,
              height: MobileSize.cta,
              icon: Icons.local_cafe_rounded,
              label: '5분 휴식',
              onTap: () {
                s.startBreak();
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(width: 12),
          RoundIconButton(
            style: style,
            size: MobileSize.cta,
            icon: Icons.close_rounded,
            tooltip: '닫기',
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ]),
    );
  }).whenComplete(s.clearLastReward);
}

/// 연속 집중 배너 (듀오링고 연속 화면 참고): 친구가 세 번 뛰고 불꽃이 커진다.
/// 오늘 첫 완료로 연속일이 이어졌을 때만 보상 시트 맨 위에 뜬다.
class _StreakBanner extends StatelessWidget {
  const _StreakBanner(
      {required this.days,
      required this.asset,
      required this.state,
      required this.reduce});
  final int days;
  final String asset;
  final AppState state;
  final bool reduce;

  static const _milestones = {3, 7, 14, 30, 50, 100, 180, 365};

  @override
  Widget build(BuildContext context) {
    final milestone = _milestones.contains(days);
    final today = dayKey(clock.now());
    const text = AppColors.onPrimary;
    return Semantics(
      label: '$days일 연속 집중',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MobileSize.cardPadding),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.streakTop, AppColors.streakBottom]),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: reduce ? Duration.zero : AppDuration.streakHop,
          builder: (_, v, __) {
            // 점점 낮아지는 세 번 뛰기 + 착지 때 살짝 눌림
            final hop = (math.sin(v * 3 * math.pi)).abs() * (1 - v);
            final squash = 1 + 0.08 * (1 - hop) * (1 - v);
            return Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (asset.isNotEmpty)
                  Transform.translate(
                    offset: Offset(0, -MobileSize.streakHop * hop),
                    child: Transform.scale(
                      scaleX: squash,
                      scaleY: 2 - squash,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(asset,
                          width: MobileSize.streakBannerFriend,
                          height: MobileSize.streakBannerFriend),
                    ),
                  ),
                Transform.scale(
                  scale: Curves.easeOutBack.transform(v.clamp(0, 1)),
                  child: const Icon(Icons.local_fire_department_rounded,
                      size: MobileSize.streakIcon, color: text),
                ),
                Text('$days',
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: text,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              Text(milestone ? '$days일 연속 달성!' : '$days일 연속 집중!',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: text)),
              const SizedBox(height: MobileSize.labelGap),
              Text('내일도 집중하면 ${days + 1}일이 돼요',
                  style: const TextStyle(fontSize: 14, color: text)),
              const SizedBox(height: MobileSize.cardGap),
              // 최근 7일: 집중한 날·얼음 쓴 날은 채움, 오늘은 굵게
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 6; i >= 0; i--)
                  Builder(builder: (_) {
                    final d = addDays(today, -i);
                    final on = state.activeDays.contains(d) ||
                        state.iceDays.contains(d);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: MobileSize.streakDot,
                        height: MobileSize.streakDot,
                        decoration: BoxDecoration(
                          color: on ? text : AppColors.streakDim,
                          shape: BoxShape.circle,
                          border: i == 0
                              ? Border.all(color: text, width: 2)
                              : null,
                        ),
                        child: on
                            ? Icon(
                                state.iceDays.contains(d)
                                    ? Icons.ac_unit_rounded
                                    : Icons.check_rounded,
                                size: 16,
                                color: AppColors.streakBottom)
                            : null,
                      ),
                    );
                  }),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

/// 승급 축하: 새 테두리 아바타 팝 + 새 칭호 + 자랑하기
class _Promotion extends StatelessWidget {
  const _Promotion(
      {required this.style, required this.title, required this.asset});
  final SceneStyle style;
  final FocusTitle title;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MobileSize.cardPadding),
      decoration: BoxDecoration(
          color: style.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0.6, end: 1),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 480),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: TitleAvatar(
              title: title,
              asset: asset,
              background: style.rowBg,
              size: MobileSize.avatarLarge),
        ),
        const SizedBox(height: MobileSize.iconGap),
        Text('승급! 이제 \'${title.label}\'예요',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: style.textStrong)),
        const SizedBox(height: MobileSize.labelGap + 2),
        TitleBadge(
            title: title,
            textColor: style.textStrong,
            height: MobileSize.badgeLarge),
        if (title.next case final next?) ...[
          const SizedBox(height: MobileSize.labelGap + 2),
          Text(
              '다음 목표 \'${next.label}\'까지 ${hm(title.remaining(context.read<AppState>().focusMinutesTotal))}',
              style: TextStyle(fontSize: 13, color: style.textMuted)),
        ],
        TextButton.icon(
          onPressed: () => showShareSheet(context),
          icon: Icon(Icons.ios_share_rounded, color: style.accent),
          label: Text('자랑하기', style: TextStyle(color: style.accent)),
        ),
      ]),
    );
  }
}

/// 소리: 장면별 소리·백색·갈색·끄기 + 볼륨. 즉시 적용, 다음 집중에도 기억.
Future<void> showSoundSheet(BuildContext context) =>
    showFocusSheet(context, '집중 소리', (ctx) {
      return Consumer<AppState>(builder: (_, s, __) {
        final style = s.scene.style;
        // 지금 장면의 소리 · 집중 소음(공통) — 아이디는 assets/sounds/<id>.m4a ('scene' = 장면 기본)
        const labels = {
          'birds': ('새소리', Icons.flutter_dash_rounded),
          'stream': ('시냇물', Icons.waves_rounded),
          'rain': ('빗소리', Icons.water_drop_outlined),
          'crickets': ('풀벌레', Icons.bug_report_outlined),
          'wind': ('바람', Icons.air_rounded),
          'harbor': ('항구', Icons.sailing_outlined),
          'rocky': ('바위 해변', Icons.landscape_outlined),
          'library': ('도서관', Icons.menu_book_outlined),
          'train': ('기차 안', Icons.train_outlined),
          'fire': ('모닥불', Icons.local_fire_department_outlined),
        };
        final sceneSounds = [
          switch (s.scene) {
            FocusScene.forest => ('scene', '숲 소리', Icons.park_outlined),
            FocusScene.night => ('scene', '밤 소리', Icons.nightlight_round),
            FocusScene.ocean => ('scene', '파도 소리', Icons.water),
            FocusScene.daily => ('scene', '카페', Icons.local_cafe_outlined),
          },
          for (final id in s.scene.situationSounds)
            (id, labels[id]!.$1, labels[id]!.$2),
        ];
        final groups = [
          (style.sceneLabel, sceneSounds),
          ('집중 소음', [
            ('white', '백색소음', Icons.blur_on_rounded),
            ('brown', '갈색소음', Icons.graphic_eq_rounded),
          ]),
        ];
        Widget row(String label, IconData icon, bool selected, VoidCallback onTap) => _Row(
              selected: selected,
              onTap: onTap,
              child: Row(children: [
                Icon(icon, color: style.textStrong),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: style.textStrong))),
                if (selected) Icon(Icons.check_rounded, color: style.accent),
              ]),
            );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 4, MobileSize.gutter, 24),
          children: [
            for (final (title, options) in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(title, style: TextStyle(fontSize: 13, color: style.textMuted)),
              ),
              for (final (id, label, icon) in options)
                row(label, icon, s.soundEnabled && s.soundId == id, () {
                  s.setSoundEnabled(true);
                  s.setSoundId(id);
                }),
            ],
            row('끄기', Icons.volume_off_outlined, !s.soundEnabled,
                () => s.setSoundEnabled(false)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.volume_down_rounded, color: style.textMuted),
              Expanded(
                child: Slider(
                  value: s.soundVolume,
                  activeColor: style.ringProgress,
                  onChanged: s.soundEnabled
                      ? (v) => s.setSoundVolume(v, persist: false)
                      : null,
                  onChangeEnd: s.setSoundVolume,
                ),
              ),
              Icon(Icons.volume_up_rounded, color: style.textMuted),
            ]),
            Text('집중하는 동안에만 들려요. 다음 집중에도 기억돼요.',
                style: TextStyle(fontSize: 12, color: style.textMuted)),
          ],
        );
      });
    });
