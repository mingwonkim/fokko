// lib/mobile/growth/growth_pages.dart
// 상단 스탯에서 들어가는 목표 설정 · 연속일 화면 (docs/v3/app-design-spec.md §3)
import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/growth.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';

BoxDecoration _card(SceneStyle style) => BoxDecoration(
      color: style.rowBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: AppShadow.card(style.rowShadow),
    );

Widget _page(BuildContext context, String title, List<Widget> children) {
  final style = context.watch<AppState>().scene.style;
  return Scaffold(
    backgroundColor: style.cardBg,
    appBar: AppBar(
      backgroundColor: style.cardBg,
      foregroundColor: style.textStrong,
      surfaceTintColor: Colors.transparent,
      title: Text(title,
          style: const TextStyle(fontSize: 20, )),
    ),
    body: SafeArea(
      top: false,
      child: MaxWidth(
        max: MobileSize.listMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 8, MobileSize.gutter, MobileSize.sectionGap),
          children: children,
        ),
      ),
    ),
  );
}

class GoalPage extends StatelessWidget {
  const GoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return _page(context, '목표', [
      _GoalCard(
        title: '일일 목표',
        reward: '달성하면 물방울 ${Growth.dailyRewardDrops}개',
        done: s.todayMinutes,
        goal: s.dailyGoal,
        plan: s.dailyPlan,
        period: s.todayKey,
        later: '내일부터',
        min: Growth.dailyMin,
        max: Growth.dailyMax,
        onChange: s.setDailyGoal,
      ),
      const SizedBox(height: MobileSize.gridGap),
      _GoalCard(
        title: '주간 목표',
        reward: '달성하면 물방울 ${Growth.weeklyRewardDrops}개와 얼음 1개',
        done: s.thisWeekMinutes,
        goal: s.weeklyGoal,
        plan: s.weeklyPlan,
        period: s.thisWeekKey,
        later: '다음 주부터',
        min: Growth.weeklyMin,
        max: Growth.weeklyMax,
        onChange: s.setWeeklyGoal,
      ),
      const SizedBox(height: MobileSize.gridGap),
      Text('올린 목표는 바로, 낮춘 목표는 다음 기간부터 적용돼요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: s.scene.style.textMuted)),
    ]);
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.title,
    required this.reward,
    required this.done,
    required this.goal,
    required this.plan,
    required this.period,
    required this.later,
    required this.min,
    required this.max,
    required this.onChange,
  });

  final String title;
  final String reward;
  final int done;
  final int goal;
  final GoalPlan plan;
  final String period; // 오늘 또는 이번 주 월요일
  final String later;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  Future<void> _input(BuildContext context, int value) async {
    final c = TextEditingController(text: '$value');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: '분', helperText: '$min~$max분, 5분 단위'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
              child: const Text('확인')),
        ],
      ),
    );
    c.dispose();
    if (v != null) onChange(v);
  }

  @override
  Widget build(BuildContext context) {
    final style = context.watch<AppState>().scene.style;
    final value = plan.nextMinutes ?? goal;
    final reached = done >= goal;
    return Container(
      padding: const EdgeInsets.all(MobileSize.cardPadding),
      decoration: _card(style),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.textStrong)),
          ),
          Text(reached ? '달성' : '$done / $goal분',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: style.accent)),
        ]),
        const SizedBox(height: MobileSize.cardGap),
        _Bar(style: style, value: goal == 0 ? 0 : done / goal),
        const SizedBox(height: MobileSize.cardGap),
        Text(reward, style: TextStyle(fontSize: 13, color: style.textMuted)),
        const SizedBox(height: MobileSize.cardPadding),
        Row(children: [
          RoundIconButton(
            style: style,
            size: MobileSize.touchMin,
            icon: Icons.remove_rounded,
            tooltip: '$title 5분 줄이기',
            onTap: value <= min ? null : () => onChange(value - Growth.goalStep),
          ),
          Expanded(
            child: Semantics(
              button: true,
              onTap: () => _input(context, value),
              label: '$title $value분, 직접 입력',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _input(context, value),
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: MobileSize.touchMin),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$value분',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: style.textStrong)),
                  if (plan.pendingOn(period))
                    Text('$later 적용',
                        style: TextStyle(fontSize: 13, color: style.textMuted)),
                  ]),
                ),
              ),
            ),
          ),
          RoundIconButton(
            style: style,
            size: MobileSize.touchMin,
            icon: Icons.add_rounded,
            tooltip: '$title 5분 늘리기',
            onTap: value >= max ? null : () => onChange(value + Growth.goalStep),
          ),
        ]),
      ]),
    );
  }
}

class StreakPage extends StatelessWidget {
  const StreakPage({super.key});

  String _message(AppState s) {
    final n = s.streakDays;
    if (n == 0) return s.bestStreak > 0 ? '오늘부터 다시 이어가요' : '첫 집중으로 시작해요';
    return s.focusedToday ? '오늘도 이어갔어요' : '오늘 집중하면 ${n + 1}일이 돼요';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final canBuy = s.iceCount < Growth.iceMax && s.drops >= Growth.icePrice;
    return _page(context, '연속일', [
      const SizedBox(height: MobileSize.cardGap),
      Center(
        child: Icon(Icons.local_fire_department_rounded,
            size: MobileSize.streakIcon,
            color: s.streakDays > 0 ? style.accent : style.textFaint),
      ),
      Text('${s.streakDays}일',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: style.textStrong)),
      const SizedBox(height: MobileSize.labelGap),
      Text(_message(s),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: style.textMuted)),
      const SizedBox(height: MobileSize.sectionGap),
      Container(
        padding: const EdgeInsets.all(MobileSize.cardPadding),
        decoration: _card(style),
        child: _Week(state: s),
      ),
      const SizedBox(height: MobileSize.gridGap),
      Container(
        padding: const EdgeInsets.all(MobileSize.cardPadding),
        decoration: _card(style),
        child: Row(children: [
          Icon(Icons.emoji_events_rounded, color: style.accent),
          const SizedBox(width: MobileSize.iconGap),
          Expanded(
            child: Text('최고 기록',
                style: TextStyle(fontSize: 16, color: style.textStrong)),
          ),
          Text('${s.bestStreak}일',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: style.textStrong)),
        ]),
      ),
      const SizedBox(height: MobileSize.gridGap),
      Container(
        padding: const EdgeInsets.all(MobileSize.cardPadding),
        decoration: _card(style),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('얼음',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: style.textStrong)),
            ),
            for (var i = 0; i < Growth.iceMax; i++)
              Padding(
                padding: const EdgeInsets.only(left: MobileSize.labelGap),
                child: Icon(Icons.ac_unit_rounded,
                    size: 24,
                    color: i < s.iceCount ? style.accent : style.divider),
              ),
          ]),
          const SizedBox(height: MobileSize.labelGap),
          Text('하루 빠져도 얼음이 연속일을 지켜줘요. 자동으로 쓰여요.',
              style: TextStyle(fontSize: 13, color: style.textMuted)),
          const SizedBox(height: MobileSize.gridGap),
          PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.water_drop_rounded,
            label: s.iceCount >= Growth.iceMax
                ? '얼음이 가득 찼어요'
                : '물방울 ${Growth.icePrice}개로 얼음 사기',
            onTap: canBuy ? s.buyIce : null,
          ),
        ]),
      ),
    ]);
  }
}

/// 이번 주 월~일. 집중한 날 불꽃, 얼음으로 지킨 날 얼음, 아직 안 온 날 빈 칸.
class _Week extends StatelessWidget {
  const _Week({required this.state});
  final AppState state;

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    final today = dayKey(clock.now());
    final monday = weekKey(today);
    final active = state.activeDays;
    return Row(children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Builder(builder: (_) {
            final d = addDays(monday, i);
            final on = active.contains(d);
            final iced = state.iceDays.contains(d);
            return Column(children: [
              Text(_labels[i],
                  style: TextStyle(fontSize: 13, color: style.textMuted)),
              const SizedBox(height: MobileSize.labelGap),
              Container(
                width: MobileSize.weekCell,
                height: MobileSize.weekCell,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? style.ringProgress : style.divider,
                  border: d == today
                      ? Border.all(color: style.accent, width: 2)
                      : null,
                ),
                child: on || iced
                    ? Icon(
                        on
                            ? Icons.local_fire_department_rounded
                            : Icons.ac_unit_rounded,
                        size: 20,
                        color: on ? AppColors.onPrimary : style.accent,
                        semanticLabel: on ? '집중함' : '얼음으로 지킴')
                    : null,
              ),
            ]);
          }),
        ),
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.style, required this.value});
  final SceneStyle style;
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: MobileSize.goalBar,
          color: style.ringTrack,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: style.ringProgress),
          ),
        ),
      );
}
