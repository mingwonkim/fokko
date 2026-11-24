// lib/mobile/growth/companion_page.dart
// 친구 성장: 함께 끝까지 집중한 분으로 받침과 후광이 자란다. 새 그림 없이 기존 그림 + 코드.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../models/growth.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';

/// 단계별 친구 모습: 만남 = 그림만, 단짝 = 받침, 빛나는 단짝 = 받침 + 후광
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({
    super.key,
    required this.companion,
    required this.stage,
    this.size = MobileSize.companionLarge,
  });

  final Companion companion;
  final CompanionStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = companion.scene.style;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        if (stage == CompanionStage.glow)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                style.ringProgress.withValues(alpha: 0.45),
                style.ringProgress.withValues(alpha: 0),
              ]),
            ),
          ),
        if (stage != CompanionStage.basic)
          Positioned(
            bottom: size * 0.04,
            child: Container(
              width: size * 0.72,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: style.ringProgress,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: size * 0.08),
          child: Image.asset(companion.asset,
              width: size * 0.82, height: size * 0.82),
        ),
      ]),
    );
  }
}

class CompanionPage extends StatelessWidget {
  const CompanionPage({super.key, required this.companion});
  final Companion companion;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final c = companion;
    final minutes = s.companionMinutes(c.id);
    final stage = CompanionStage.of(minutes);
    final next = stage.next;
    return Scaffold(
      backgroundColor: style.cardBg,
      appBar: AppBar(
        backgroundColor: style.cardBg,
        foregroundColor: style.textStrong,
        surfaceTintColor: Colors.transparent,
        title: Text(c.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: MaxWidth(
          max: MobileSize.listMaxWidth,
          child: ListView(
            padding: const EdgeInsets.all(MobileSize.gutter),
            children: [
              Center(child: CompanionPortrait(companion: c, stage: stage)),
              const SizedBox(height: MobileSize.gridGap),
              Text(stage.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: style.textStrong)),
              const SizedBox(height: MobileSize.labelGap),
              Text(
                next == null
                    ? '함께 $minutes분 집중했어요'
                    : minutes == 0
                        ? '함께 집중하면 자라요'
                        : '${next.minMinutes - minutes}분 더 함께하면 ${next.label}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: style.textMuted),
              ),
              const SizedBox(height: MobileSize.sectionGap),
              Row(children: [
                for (final st in CompanionStage.values)
                  Expanded(
                    child: Opacity(
                      opacity: st.index <= stage.index ? 1 : 0.35,
                      child: Column(children: [
                        CompanionPortrait(
                            companion: c, stage: st, size: MobileSize.avatarLarge),
                        const SizedBox(height: MobileSize.labelGap),
                        Text(st.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: style.textStrong)),
                        Text('${st.minMinutes}분',
                            style: TextStyle(
                                fontSize: 12, color: style.textMuted)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: MobileSize.sectionGap),
              PillButton(
                style: style,
                width: double.infinity,
                height: MobileSize.cta,
                icon: Icons.play_arrow_rounded,
                label: '이 친구와 집중하기',
                onTap: s.isUnlocked(c)
                    ? () {
                        s.setScene(c.scene);
                        s.selectCompanion(c.id);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
