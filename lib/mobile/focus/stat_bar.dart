// lib/mobile/focus/stat_bar.dart
// 상단 스탯: 레벨 / 연속일 / 물방울 / 오늘 집중·목표. 누르면 연속일·목표 화면으로.
import 'package:material_ui/material_ui.dart';

import '../../core/design_tokens.dart';
import '../../state/app_state.dart';
import '../growth/growth_pages.dart';

class StatBar extends StatelessWidget {
  const StatBar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    Widget item(IconData icon, String value, String label, {Widget? page}) =>
        Semantics(
          button: page != null,
          onTap: page == null
              ? null
              : () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => page)),
          label: '$label $value',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: page == null
                ? null
                : () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => page)),
            child: Container(
              constraints: const BoxConstraints(minHeight: MobileSize.touchMin),
              padding: const EdgeInsets.symmetric(horizontal: MobileSize.iconGap),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: MobileSize.statIcon, color: style.accent),
                const SizedBox(width: MobileSize.labelGap),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.textStrong,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
        );
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: MobileSize.iconGap,
        children: [
          item(Icons.military_tech_rounded, 'Lv.${state.level}', '현재 레벨'),
          item(Icons.local_fire_department_rounded, '${state.streakDays}',
              '연속 집중일',
              page: const StreakPage()),
          item(Icons.water_drop_rounded, '${state.drops}', '물방울'),
          item(Icons.timer_rounded, '${state.todayMinutes}/${state.dailyGoal}분',
              '오늘 목표',
              page: const GoalPage()),
        ],
      ),
    );
  }
}
