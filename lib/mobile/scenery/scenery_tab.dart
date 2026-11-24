// lib/mobile/scenery/scenery_tab.dart
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/collection.dart';
import '../../state/app_state.dart';
import '../adaptive.dart';
import 'collection_pages.dart';

/// 풍경 탭 (spec §2): 헤더(장면·물방울) → 정사각 풍경 → 편집 / 보관함·도감·상점.
/// 편집: 아래 재고에서 하나 고르고 빈 칸을 탭해 놓기, 놓인 것을 탭하면 회수. 완료=저장, 취소=원복.
class SceneryTab extends StatefulWidget {
  const SceneryTab({super.key});

  @override
  State<SceneryTab> createState() => _SceneryTabState();
}

class _SceneryTabState extends State<SceneryTab> {
  List<Placement>? _draft; // 편집 중 사본 (null = 보기)
  String? _picked; // 놓을 아이템
  bool _decorTab = false;

  void _tapCell(AppState s, int x, int y) {
    final draft = _draft!;
    final i = draft.indexWhere((p) => p.x == x && p.y == y);
    setState(() {
      if (i >= 0) {
        draft.removeAt(i); // 회수
        HapticFeedback.selectionClick();
      } else if (_picked != null && _left(s, _picked!) > 0) {
        draft.add(Placement(_picked!, x, y));
        HapticFeedback.lightImpact();
        if (_left(s, _picked!) == 0) _picked = null;
      }
    });
  }

  /// 편집 사본 기준 남은 수 = 보유 − 사본 배치
  int _left(AppState s, String id) =>
      s.ownedCount(id) -
      (_draft ?? s.placements).where((p) => p.itemId == id).length;

  Widget _friendCard(AppState s, SceneStyle style, Companion c) {
    final left = _left(s, c.id);
    if (s.ownedCount(c.id) == 0) {
      final open = s.isUnlocked(c);
      return _StockCard(
        style: style,
        id: c.id,
        name: open ? c.name : '???',
        note: open
            ? '집중하면 만나요'
            : '${c.scene.style.sceneLabel} ${c.unlockMinutes - s.sceneMinutes(c.scene)}분 더',
        locked: true,
        picked: false,
      );
    }
    return _StockCard(
      style: style,
      id: c.id,
      name: c.name,
      note: left <= 0 ? '놓음' : (c.isStarter ? null : '×$left'),
      picked: _picked == c.id,
      onTap: left > 0
          ? () => setState(() => _picked = _picked == c.id ? null : c.id)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final editing = _draft != null;
    final placed = _draft ?? s.placements;
    final decor = [
      for (final d in Decor.all)
        if (s.ownedCount(d.id) > 0) d
    ];

    final kids = <Widget>[
        Row(children: [
          Text('꾸미기',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: style.textStrong)),
          const Spacer(),
          _Pill(
            style: style,
            child: Text('💧 ${s.drops}',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: style.textStrong)),
          ),
        ]),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (_, box) {
            final cell = box.maxWidth / Placement.grid;
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Stack(children: [
                Positioned.fill(
                    child: CustomPaint(
                        painter: _BoardPainter(style: style, grid: editing))),
                if (placed.isEmpty && !editing)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        '배치 바꾸기를 눌러\n친구와 장식을 놓아 보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, height: 1.5, color: style.textStrong),
                      ),
                    ),
                  ),
                // 위쪽 줄부터 그려 아래 줄이 앞에 오게
                for (final p in [...placed]..sort((a, b) => a.y.compareTo(b.y)))
                  Positioned(
                    // 그림이 칸보다 커도 풍경 밖으로 잘리지 않게
                    left: (p.x * cell - cell * 0.1)
                        .clamp(0.0, box.maxWidth - cell * 1.2),
                    top: (p.y * cell - cell * 0.25)
                        .clamp(0.0, box.maxWidth - cell * 1.2),
                    width: cell * 1.2,
                    height: cell * 1.2,
                    child: IgnorePointer(
                        child: Image.asset(itemAsset(p.itemId),
                            fit: BoxFit.contain)),
                  ),
                if (editing)
                  for (var y = 0; y < Placement.grid; y++)
                    for (var x = 0; x < Placement.grid; x++)
                      Positioned(
                        left: x * cell,
                        top: y * cell,
                        width: cell,
                        height: cell,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _tapCell(s, x, y),
                        ),
                      ),
              ]),
            );
          }),
        ),
        const SizedBox(height: MobileSize.sectionGap),
        if (!editing) ...[
          PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.edit_rounded,
            label: '배치 바꾸기',
            onTap: () => setState(() {
              _draft = List.of(s.placements);
              _picked = null;
            }),
          ),
        ] else ...[
          // 친구가 많아 목록이 길다 → 완료는 풍경 바로 아래
          Row(children: [
            Expanded(
              child: _Pill(
                style: style,
                height: MobileSize.cta,
                onTap: () => setState(() => _draft = null),
                child: Center(
                  child: Text('취소',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: style.textStrong)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PillButton(
                style: style,
                width: double.infinity,
                height: MobileSize.cta,
                icon: Icons.check_rounded,
                label: '완료',
                onTap: () {
                  s.setPlacements(_draft!);
                  setState(() => _draft = null);
                },
              ),
            ),
          ]),
          const SizedBox(height: MobileSize.gridGap),
          Row(children: [
            Expanded(
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('친구')),
                  ButtonSegment(value: true, label: Text('장식')),
                ],
                selected: {_decorTab},
                onSelectionChanged: (v) => setState(() => _decorTab = v.first),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            _picked == null
                ? '놓을 것을 고르고 빈 칸을 누르세요. 놓인 것을 누르면 돌아와요.'
                : '빈 칸을 눌러 놓기',
            style: TextStyle(fontSize: 13, color: style.textMuted),
          ),
          const SizedBox(height: 8),
          if (_decorTab && decor.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '상점에서 물방울로 장식을 살 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: style.textMuted),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                if (_decorTab)
                  for (final d in decor)
                    _StockCard(
                      style: style,
                      id: d.id,
                      name: d.name,
                      note: '×${_left(s, d.id)}',
                      picked: _picked == d.id,
                      onTap: _left(s, d.id) > 0
                          ? () => setState(
                              () => _picked = _picked == d.id ? null : d.id)
                          : null,
                    )
                else
                  for (final c in Companion.forScenery)
                    _friendCard(s, style, c),
              ],
            ),
        ],
    ];
    // 보관함·도감·상점: 탭바 바로 위 고정 (편집 중엔 숨김)
    final shortcuts = Padding(
      padding: const EdgeInsets.fromLTRB(MobileSize.gutter, MobileSize.cardGap,
          MobileSize.gutter, MobileSize.cardGap),
      child: Row(children: [
        for (final (label, icon, page) in [
          ('보관함', Icons.inventory_2_outlined, const StoragePage()),
          ('도감', Icons.menu_book_outlined, const DexPage()),
          ('상점', Icons.storefront_outlined, const ShopPage()),
        ]) ...[
          Expanded(
            child: _Pill(
              style: style,
              height: MobileSize.cta,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => page)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: style.textStrong),
                    const SizedBox(width: MobileSize.iconGap),
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: style.textStrong)),
                  ]),
            ),
          ),
          if (label != '상점') const SizedBox(width: 8),
        ],
      ]),
    );
    const pad = EdgeInsets.fromLTRB(
        MobileSize.gutter, 8, MobileSize.gutter, MobileSize.contentBottomGap);
    return LayoutBuilder(builder: (_, box) {
      // 폰·iPad 세로: 한 열 (iPad는 가운데 720)
      if (box.maxWidth < MobileSize.twoPaneBreak || box.maxWidth < box.maxHeight) {
        final list = MaxWidth(child: ListView(padding: pad, children: kids));
        if (editing) return list;
        return Column(children: [
          Expanded(child: list),
          MaxWidth(child: shortcuts),
        ]);
      }
      // iPad 가로: 왼쪽 풍경(높이에 맞춘 정사각), 오른쪽 조작부
      return Padding(
        padding: pad,
        child: Column(children: [
          kids[0], // 제목 행은 전체 폭
          kids[1],
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              kids[2], // 높이에 맞춘 정사각
              const SizedBox(width: MobileSize.sectionGap),
              Expanded(
                child: Column(children: [
                  Expanded(
                      child: ListView(
                          padding: EdgeInsets.zero, children: kids.sublist(4))),
                  if (!editing) shortcuts,
                ]),
              ),
            ]),
          ),
        ]),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.style, required this.child, this.onTap, this.height = 40});
  final SceneStyle style;
  final Widget child;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      constraints: BoxConstraints(minHeight: math.max(height, MobileSize.row)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Center(widthFactor: 1, child: child),
    );
    return onTap == null ? box : PressScale(onTap: onTap, child: box);
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.style,
    required this.id,
    required this.name,
    required this.picked,
    this.note,
    this.locked = false,
    this.onTap,
  });
  final SceneStyle style;
  final String id, name;
  final String? note;
  final bool locked; // 아직 못 만남: 그림자로 보여 준다
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      enabled: onTap != null,
      onTap: onTap,
      label: note == null ? name : '$name, $note',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: picked ? style.accent : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            Expanded(
              child: locked
                  ? ColorFiltered(
                      colorFilter:
                          ColorFilter.mode(style.divider, BlendMode.srcIn),
                      child: Image.asset(itemAsset(id)))
                  : Image.asset(itemAsset(id)),
            ),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: style.textStrong)),
            if (note != null)
              Text(note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: style.textMuted)),
          ]),
        ),
      ),
    );
  }
}

/// 풍경 바닥: 지금 장면의 두 색 그라데이션. 편집 중엔 격자.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.style, required this.grid});
  final SceneStyle style;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.boardTop, style.boardBottom],
          ).createShader(r));
    if (!grid) return;
    final line = Paint()
      ..color = style.textStrong.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final cell = size.width / Placement.grid;
    for (var i = 1; i < Placement.grid; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter o) => o.style != style || o.grid != grid;
}
