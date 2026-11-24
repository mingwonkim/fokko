// lib/mobile/scenery/collection_pages.dart
// 풍경 탭에서 들어가는 보관함 · 도감 · 상점
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';
import '../growth/companion_page.dart';

Widget _page(BuildContext context, String title, Widget body) {
  final style = context.watch<AppState>().scene.style;
  return Scaffold(
    backgroundColor: style.cardBg,
    appBar: AppBar(
      backgroundColor: style.cardBg,
      foregroundColor: style.textStrong,
      surfaceTintColor: Colors.transparent,
      title: Text(title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    ),
    body: SafeArea(top: false, child: MaxWidth(max: 900, child: body)),
  );
}

BoxDecoration _card(SceneStyle style, {bool selected = false}) => BoxDecoration(
      color: style.rowBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
          color: selected ? style.accent : Colors.transparent, width: 2),
      boxShadow: AppShadow.card(style.rowShadow),
    );

/// 보관함: 보유/배치/남음 → 전체·친구·장식 → 3열
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  int _filter = 0; // 0 전체, 1 친구, 2 장식

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final all = [
      if (_filter != 2)
        for (final c in Companion.all) (c.id, c.name),
      if (_filter != 1)
        for (final d in Decor.all) (d.id, d.name),
    ].where((e) => s.ownedCount(e.$1) > 0).toList();
    final owned = [
      ...Companion.all.map((c) => c.id),
      ...Decor.all.map((d) => d.id)
    ].fold(0, (a, id) => a + s.ownedCount(id));
    final placed = s.placements.length;

    Widget stat(String label, int n) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: _card(style),
            child: Column(children: [
              Text('$n',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: style.textStrong)),
              Text(label,
                  style: TextStyle(fontSize: 13, color: style.textMuted)),
            ]),
          ),
        );

    return _page(
      context,
      '보관함',
      ListView(padding: const EdgeInsets.all(MobileSize.gutter), children: [
        Row(children: [
          stat('보유', owned),
          const SizedBox(width: 10),
          stat('놓음', placed),
          const SizedBox(width: 10),
          stat('남음', owned - placed),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('전체')),
            ButtonSegment(value: 1, label: Text('친구')),
            ButtonSegment(value: 2, label: Text('장식')),
          ],
          selected: {_filter},
          onSelectionChanged: (v) => setState(() => _filter = v.first),
        ),
        const SizedBox(height: 16),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('집중을 끝내면 친구가 여기 모여요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: style.textMuted)),
          )
        else
          GridView.count(
            crossAxisCount: isTablet(context) ? 5 : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MobileSize.gridGap,
            crossAxisSpacing: MobileSize.gridGap,
            childAspectRatio: 0.85,
            children: [
              for (final (id, name) in all)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _card(style),
                  child: Column(children: [
                    Expanded(child: Image.asset(itemAsset(id))),
                    Text(name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: style.textStrong)),
                    Text('×${s.ownedCount(id)}',
                        style: TextStyle(fontSize: 12, color: style.textMuted)),
                  ]),
                ),
            ],
          ),
      ]),
    );
  }
}

/// 도감: 장면별 n/4, 2열. 만남 = 그림 / 해금됐지만 못 만남 = 흐림 / 잠김 = 실루엣 + 남은 분
class DexPage extends StatelessWidget {
  const DexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    return _page(
      context,
      '도감',
      ListView(padding: const EdgeInsets.all(MobileSize.gutter), children: [
        for (final scene in FocusScene.values) ...[
          Row(children: [
            SceneBullet(scene: scene, selected: true, moon: true),
            const SizedBox(width: 8),
            Text(scene.style.sceneLabel,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: style.textStrong)),
            const SizedBox(width: 6),
            Text(
                '${Companion.of(scene).where((c) => s.ownedCount(c.id) > 0).length}/${Companion.of(scene).length}',
                style: TextStyle(fontSize: 13, color: style.textMuted)),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isTablet(context) ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MobileSize.gridGap,
            crossAxisSpacing: MobileSize.gridGap,
            childAspectRatio: 169 / 156,
            children: [
              for (final c in Companion.of(scene))
                PressScale(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CompanionPage(companion: c))),
                  child: Container(
                  padding: const EdgeInsets.all(MobileSize.cardPadding),
                  decoration: _card(style),
                  child: Column(children: [
                    Expanded(
                      child: s.ownedCount(c.id) > 0
                          ? CompanionPortrait(
                              companion: c, stage: s.companionStage(c.id))
                          : s.isUnlocked(c)
                              ? Opacity(
                                  opacity: 0.35, child: Image.asset(c.asset))
                              : ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                      style.divider, BlendMode.srcIn),
                                  child: Image.asset(c.asset)),
                    ),
                    Text(s.isUnlocked(c) ? c.name : '???',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: style.textStrong)),
                    Text(
                      s.ownedCount(c.id) > 0
                          ? s.companionStage(c.id).label
                          : s.isUnlocked(c)
                              ? '${scene.style.sceneLabel}에서 집중하면 만나요'
                              : '${scene.style.sceneLabel}에서 ${c.unlockMinutes - s.sceneMinutes(scene)}분 더',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: style.textMuted),
                    ),
                  ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MobileSize.sectionGap),
        ],
      ]),
    );
  }
}

/// 상점: 잔액 → 장면별 장식 2열(그림·가격), 구매 확인, 부족하면 부족량 표시
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  Future<void> _buy(BuildContext context, AppState s, Decor d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${d.name}을(를) 살까요?'),
        content: Text('물방울 ${d.price}개를 써요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('아니요')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('살게요')),
        ],
      ),
    );
    if (ok == true && s.buyDecor(d.id)) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    return _page(
      context,
      '상점',
      ListView(padding: const EdgeInsets.all(MobileSize.gutter), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(style),
          child: Row(children: [
            Text('내 물방울', style: TextStyle(color: style.textMuted)),
            const Spacer(),
            Text('💧 ${s.drops}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: style.textStrong)),
          ]),
        ),
        const SizedBox(height: 6),
        Text('집중 1분에 물방울 1개',
            style: TextStyle(fontSize: 12, color: style.textMuted)),
        const SizedBox(height: 16),
        for (final scene in FocusScene.values) ...[
          Text(scene.style.sceneLabel,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: style.textStrong)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isTablet(context) ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: MobileSize.gridGap,
            crossAxisSpacing: MobileSize.gridGap,
            childAspectRatio: 169 / 170,
            children: [
              for (final d in Decor.all.where((d) => d.scene == scene))
                Semantics(
                  button: true,
                  label: '${d.name} 물방울 ${d.price}개',
                  child: PressScale(
                    onTap:
                        s.drops >= d.price ? () => _buy(context, s, d) : null,
                    child: Container(
                      padding: const EdgeInsets.all(MobileSize.cardPadding),
                      decoration: _card(style),
                      child: Column(children: [
                        Expanded(child: Image.asset(d.asset)),
                        Text(d.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: style.textStrong)),
                        Text(
                          s.drops >= d.price
                              ? '💧 ${d.price}'
                              : '💧 ${d.price} · ${d.price - s.drops}개 부족',
                          style:
                              TextStyle(fontSize: 12, color: style.textMuted),
                        ),
                        if (s.ownedCount(d.id) > 0)
                          Text('보유 ${s.ownedCount(d.id)}',
                              style:
                                  TextStyle(fontSize: 11, color: style.accent)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MobileSize.sectionGap),
        ],
      ]),
    );
  }
}
