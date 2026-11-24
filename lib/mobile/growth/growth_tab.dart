// lib/mobile/growth/growth_tab.dart
// 성장 탭: 지도 · 퀘스트 · 리그 · 업적. 값은 전부 기록에서 계산하고, 저장되는 건 안 연 상자뿐이다.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/focus_title.dart';
import '../../models/growth.dart';
import '../../state/app_state.dart';
import '../focus/sheets.dart';
import '../widgets/title_avatar.dart';
import 'growth_pages.dart';
import 'league_view.dart';

enum _Section { map, quests, league, achievements }

class GrowthTab extends StatefulWidget {
  const GrowthTab({super.key});

  @override
  State<GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends State<GrowthTab> {
  _Section _section = _Section.map;
  final _mapScroll = ValueNotifier<double>(0);

  @override
  void dispose() {
    _mapScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Stack(children: [
      if (_section == _Section.map)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _MapBackgroundPainter(
                  style: s.scene.style, scroll: _mapScroll),
            ),
          ),
        ),
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              MobileSize.gutter, 8, MobileSize.gutter, MobileSize.cardGap),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_Section>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(value: _Section.map, label: Text('지도')),
                ButtonSegment(
                    value: _Section.quests,
                    label: Text(s.unopenedChests.isEmpty
                        ? '퀘스트'
                        : '퀘스트 ${s.unopenedChests.length}')),
                const ButtonSegment(value: _Section.league, label: Text('리그')),
                const ButtonSegment(
                    value: _Section.achievements, label: Text('업적')),
              ],
              selected: {_section},
              onSelectionChanged: (v) => setState(() => _section = v.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_section) {
            _Section.map => _MapView(scroll: _mapScroll),
            _Section.quests => const _QuestsView(),
            _Section.league => const LeagueView(),
            _Section.achievements => const _AchievementsView(),
          },
        ),
      ]),
    ]);
  }
}

BoxDecoration _card(SceneStyle style) => BoxDecoration(
      color: style.rowBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: AppShadow.card(style.rowShadow),
    );

// ---- 지도 ----

/// 칭호 칸의 줄 번호
final List<int> _titleRows = [
  for (var i = 0; i < MapNode.all.length; i++)
    if (MapNode.all[i].title != null) i
];

/// [row]번째 줄 높이의 배경색. 칭호 구간마다 그 칭호의 색을 깔고, 다음 칭호 직전에 서서히 넘어간다.
Color mapBackgroundAt(SceneStyle style, double row) {
  Color tint(int k) => Color.lerp(style.cardBg,
      TitleRings.all[k].colors.first, MobileSize.mapZoneTint)!;
  var k = 0;
  while (k + 1 < _titleRows.length && _titleRows[k + 1] <= row) {
    k++;
  }
  if (k + 1 >= _titleRows.length) return tint(k);
  final next = _titleRows[k + 1];
  final span = math.min(
      MobileSize.mapZoneBlendRows, (next - _titleRows[k]).toDouble());
  final blend = ((row - (next - span)) / span).clamp(0.0, 1.0);
  return Color.lerp(tint(k), tint(k + 1), blend)!;
}

/// 스크롤에 따라 바뀌는 배경. 상태바·탭바 뒤까지 이어지도록 자기 영역 밖까지 칠한다.
class _MapBackgroundPainter extends CustomPainter {
  _MapBackgroundPainter({required this.style, required this.scroll})
      : super(repaint: scroll);
  final SceneStyle style;
  final ValueListenable<double> scroll;

  static const _listTop = 170.0; // 구간 선택 + 머리 카드 높이 (색 번짐이라 대략이면 된다)
  static const _bleed = 2000.0;

  @override
  void paint(Canvas canvas, Size size) {
    const row = MobileSize.mapRowHeight;
    final steps = (size.height / row).ceil() + 1;
    double rowAt(double y) => (scroll.value + y - _listTop) / row;
    canvas.drawRect(
      Rect.fromLTRB(-_bleed, -_bleed, size.width + _bleed, size.height + _bleed),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            for (var i = 0; i <= steps; i++)
              mapBackgroundAt(style, rowAt(size.height * i / steps))
          ],
          [for (var i = 0; i <= steps; i++) i / steps],
        ),
    );
  }

  @override
  bool shouldRepaint(_MapBackgroundPainter o) =>
      o.style != style || o.scroll != scroll;
}

class _MapView extends StatefulWidget {
  const _MapView({required this.scroll});
  final ValueNotifier<double> scroll;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  late final ScrollController _scroll;

  double _offsetOf(int row) => math.max(0, row - 2) * MobileSize.mapRowHeight;

  @override
  void initState() {
    super.initState();
    final current = MapNode.currentIndex(context.read<AppState>().xp);
    _scroll = ScrollController(initialScrollOffset: _offsetOf(current))
      ..addListener(_report);
    widget.scroll.value = _scroll.initialScrollOffset;
  }

  void _report() => widget.scroll.value = _scroll.offset;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goToCurrent(int row) {
    final to = math.min(_offsetOf(row), _scroll.position.maxScrollExtent);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(to,
          duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  void _describe(BuildContext context, AppState s, MapNode n) {
    final style = s.scene.style;
    final left = n.xp - s.xp;
    showFocusSheet(context, 'Lv.${n.level}', (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            MobileSize.gutter, 4, MobileSize.gutter, MobileSize.sectionGap),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (n.title != null) ...[
            TitleBadge(
                title: n.title!,
                textColor: style.textStrong,
                height: MobileSize.badgeLarge),
            const SizedBox(height: MobileSize.gridGap),
          ],
          Text(
            left <= 0 ? '이미 지나온 자리예요' : '$left분 더 집중하면 닿아요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: style.textStrong),
          ),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final xp = s.xp;
    final current = MapNode.currentIndex(xp);
    final title = s.title;
    final level = s.level;
    final reached = MapNode.all[level - 1];
    final next = level < MapNode.all.length ? MapNode.all[level] : null;
    final ring = TitleRings.all[title.index];
    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: MobileSize.gutter),
        padding: EdgeInsets.all(ring.width),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(colors: [
            ring.colors.first,
            ring.colors.last,
          ]),
          boxShadow: AppShadow.card(style.rowShadow),
        ),
        child: Container(
          padding: const EdgeInsets.all(MobileSize.cardPadding),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.lg - ring.width),
          ),
          child: Row(children: [
            TitleBadge(
                title: title,
                textColor: style.textStrong,
                height: MobileSize.badgeLarge),
            const SizedBox(width: MobileSize.gridGap),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lv.$level',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: style.textStrong)),
                    const SizedBox(height: MobileSize.labelGap),
                    _LevelBar(
                        style: style,
                        progress: next == null
                            ? 1
                            : (xp - reached.xp) / (next.xp - reached.xp)),
                    const SizedBox(height: MobileSize.labelGap),
                    Text(
                      next == null
                          ? '최고 레벨이에요'
                          : '다음 레벨까지 ${next.xp - xp}분'
                              '${title.next == null ? '' : ' · ${title.next!.label}까지 ${title.remaining(xp)}분'}',
                      style: TextStyle(fontSize: 13, color: style.textMuted),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
      Expanded(
        child: Stack(children: [
          ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: MobileSize.gridGap),
            itemExtent: MobileSize.mapRowHeight,
            itemCount: MapNode.all.length,
            itemBuilder: (context, i) {
              final n = MapNode.all[i];
              final prevXp = i == 0 ? 0 : MapNode.all[i - 1].xp;
              return _MapRow(
                index: i,
                node: n,
                style: style,
                done: n.xp <= xp,
                isCurrent: i == current && n.xp > xp,
                progress: (xp - prevXp) / math.max(1, n.xp - prevXp),
                left: n.xp - xp,
                companionAsset: s.selectedCompanion.asset,
                onTap: () => _describe(context, s, n),
              );
            },
          ),
          AnimatedBuilder(
            animation: _scroll,
            builder: (context, _) {
              if (!_scroll.hasClients ||
                  !_scroll.position.haveDimensions ||
                  xp >= MapNode.all.last.xp) {
                return const SizedBox.shrink();
              }
              final at = current * MobileSize.mapRowHeight;
              final top = _scroll.offset;
              final bottom = top + _scroll.position.viewportDimension;
              final above = at + MobileSize.mapRowHeight < top;
              if (!above && at < bottom) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: MobileSize.gridGap),
                  child: PillButton(
                    style: style,
                    height: MobileSize.touchMin,
                    icon: above
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    label: '지금 위치로',
                    onTap: () => _goToCurrent(current),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    ]);
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.style, required this.progress});
  final SceneStyle style;
  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          height: MobileSize.goalBar,
          color: style.ringTrack,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: style.ringProgress),
          ),
        ),
      );
}

/// 칸의 좌우 위치. 가운데 오는 칭호 칸은 옆 글자가 화면을 넘지 않게 왼쪽으로 비킨다.
double _mapOffset(int i) {
  final dx = math.sin(i * math.pi / 3) * MobileSize.mapSwing;
  final titled = i < MapNode.all.length && MapNode.all[i].title != null;
  return titled && dx.abs() < 1 ? -MobileSize.mapSwing / 2 : dx;
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.index,
    required this.node,
    required this.style,
    required this.done,
    required this.isCurrent,
    required this.progress,
    required this.left,
    required this.companionAsset,
    required this.onTap,
  });

  final int index;
  final MapNode node;
  final SceneStyle style;
  final bool done;
  final bool isCurrent;
  final double progress;
  final int left;
  final String companionAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final big = node.title != null;
    final size = big
        ? MobileSize.mapNodeBig
        : (isCurrent ? MobileSize.mapNodeCurrent : MobileSize.mapNode);
    final dx = _mapOffset(index);
    final chipSide = dx > 0 ? -1.0 : 1.0; // 화면에서 넓은 쪽
    final label = big
        ? 'Lv.${node.level}, 칭호 ${node.title!.label}'
        : 'Lv.${node.level}';
    // 칸은 자기가 속한 칭호 구간의 색을 입는다. 안 간 곳은 옅게.
    final zone = TitleRings.all[FocusTitle.of(node.xp).index];
    final zoneColor = done
        ? zone.colors.first
        : Color.lerp(
            zone.colors.first, style.cardBg, MobileSize.mapFutureFade)!;
    final numberColor = isCurrent ? style.accent : TitleRing.textOn(zoneColor);
    final besideNode = size / 2 + 18;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _LinkPainter(
            from: dx,
            to: _mapOffset(index + 1),
            color: zoneColor,
            done: done,
            last: index == MapNode.all.length - 1,
          ),
        ),
      ),
      if (isCurrent)
        Transform.translate(
          offset: Offset(dx, 0),
          child: ExcludeSemantics(child: _Pulse(size: size, color: style.accent)),
        ),
      Transform.translate(
        offset: Offset(dx, 0),
        child: Semantics(
          button: true,
          onTap: onTap,
          label: done ? '$label, 지나옴' : (isCurrent ? '$label, 지금 여기' : label),
          excludeSemantics: true,
          child: PressScale(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: isCurrent
                        ? _CurrentPainter(
                            progress: progress.clamp(0.0, 1.0),
                            track: style.ringTrack,
                            color: style.accent)
                        : null,
                    child: Padding(
                      padding: EdgeInsets.all(isCurrent ? 9 : 0),
                      child: CustomPaint(
                        foregroundPainter: big
                            ? TitleFramePainter(
                                ring: zone,
                                reached: done,
                                ornamentGap: isCurrent ? 15 : 6)
                            : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent ? style.rowBg : zoneColor,
                            boxShadow: AppShadow.card(style.rowShadow),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(MobileSize.cardGap),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child:
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                if (big)
                                  Icon(
                                      zone.stars
                                          ? Icons.auto_awesome_rounded
                                          : Icons.military_tech_rounded,
                                      size: size * 0.3,
                                      color: numberColor),
                                Text('${node.level}',
                                    style: TextStyle(
                                        fontSize: big ? 34 : 24,
                                        height: 1.1,
                                        fontWeight: FontWeight.w900,
                                        color: numberColor)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (done)
                  Positioned(
                    right: big ? 4 : -2,
                    bottom: big ? 4 : -2,
                    child: Container(
                      width: MobileSize.mapCheck,
                      height: MobileSize.mapCheck,
                      decoration: BoxDecoration(
                        color: style.rowBg,
                        shape: BoxShape.circle,
                        boxShadow: AppShadow.card(style.rowShadow),
                      ),
                      child: Icon(Icons.check_rounded,
                          size: MobileSize.mapCheck * 0.72,
                          color: style.textStrong),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
      if (big)
        Transform.translate(
          offset: Offset(dx + chipSide * besideNode, isCurrent ? -26 : 0),
          child: FractionalTranslation(
            translation: Offset(chipSide * 0.5, 0),
            child: ExcludeSemantics(
              child: _TitleChip(style: style, title: node.title!),
            ),
          ),
        ),
      if (isCurrent) ...[
        Transform.translate(
          offset: Offset(dx + chipSide * besideNode, big ? 28 : 0),
          child: FractionalTranslation(
            translation: Offset(chipSide * 0.5, 0),
            child: ExcludeSemantics(
              child: _HereBubble(style: style, left: left, tailLeft: chipSide > 0),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(dx - chipSide * (size / 2 + 40), 0),
          child: ExcludeSemantics(
            child: Image.asset(companionAsset,
                width: MobileSize.mapNode, height: MobileSize.mapNode),
          ),
        ),
      ],
    ]);
  }
}

/// 지금 칸에서 퍼져 나가는 링. 동작 줄이기면 멈춘 링 하나.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c
        ..stop()
        ..value = 0.45;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size + MobileSize.mapPulse * 2),
          painter: _PulsePainter(_c, widget.size / 2, widget.color),
        ),
      );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.radius, this.color) : super(repaint: t);
  final Animation<double> t;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        size.center(Offset.zero),
        radius + MobileSize.mapPulse * t.value,
        Paint()..color = color.withValues(alpha: 0.32 * (1 - t.value)));
  }

  @override
  bool shouldRepaint(_PulsePainter o) =>
      o.radius != radius || o.color != color || o.t != t;
}

/// 지금 칸 옆 말풍선. 화면에서 가장 진한 면이라 어디서든 눈에 띈다.
class _HereBubble extends StatelessWidget {
  const _HereBubble(
      {required this.style, required this.left, required this.tailLeft});
  final SceneStyle style;
  final int left;
  final bool tailLeft;

  @override
  Widget build(BuildContext context) {
    final tail = CustomPaint(
      size: const Size(8, 14),
      painter: _TailPainter(style.textStrong, pointsLeft: tailLeft),
    );
    final body = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MobileSize.gridGap, vertical: MobileSize.iconGap),
      decoration: BoxDecoration(
        color: style.textStrong,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('지금 여기',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: style.cardBg)),
        Text('$left분 더',
            style: TextStyle(fontSize: 13, color: style.cardBg)),
      ]),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tailLeft ? [tail, body] : [body, tail],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color, {required this.pointsLeft});
  final Color color;
  final bool pointsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = pointsLeft ? 0.0 : size.width;
    final base = pointsLeft ? size.width : 0.0;
    canvas.drawPath(
        Path()
          ..moveTo(tip, size.height / 2)
          ..lineTo(base, 0)
          ..lineTo(base, size.height)
          ..close(),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter o) =>
      o.color != color || o.pointsLeft != pointsLeft;
}

/// 칭호 이름: 지도에서 가장 눈에 띄는 글자. 칭호 배지를 크게, 뒤 길이 비치지 않게 깔고 쓴다.
class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.style, required this.title});
  final SceneStyle style;
  final FocusTitle title;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: style.rowBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadow.card(style.rowShadow),
        ),
        child: TitleBadge(
            title: title,
            textColor: style.textStrong,
            height: MobileSize.mapTitleChip,
            weight: FontWeight.w900),
      );
}

/// 칸 사이 길: 지나온 길은 굵은 실선에 흰 줄을 덧칠, 안 간 길은 얇은 점선
class _LinkPainter extends CustomPainter {
  const _LinkPainter(
      {required this.from,
      required this.to,
      required this.color,
      required this.done,
      required this.last});
  final double from;
  final double to;
  final Color color;
  final bool done;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    if (last) return;
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx + from, size.height / 2)
      ..cubicTo(cx + from, size.height, cx + to, size.height, cx + to,
          size.height * 1.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = done ? MobileSize.mapLink : MobileSize.mapLinkFuture
      ..color = color;
    if (done) {
      // 밝은 칭호 색은 흰 줄이 묻히지 않게 길을 조금 진하게 깐다
      final light = TitleRing.textOn(color) == TitleRings.ink;
      canvas.drawPath(
          path,
          paint
            ..color = light
                ? Color.lerp(color, TitleRings.ink, MobileSize.mapLinkDeepen)!
                : color);
      canvas.drawPath(
          path,
          paint
            ..strokeWidth = MobileSize.mapLinkOver
            ..color = TitleRings.star);
      return;
    }
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += MobileSize.mapDash * 2) {
        canvas.drawPath(m.extractPath(d, d + MobileSize.mapDash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LinkPainter o) =>
      o.from != from ||
      o.to != to ||
      o.color != color ||
      o.done != done ||
      o.last != last;
}

class _CurrentPainter extends CustomPainter {
  const _CurrentPainter(
      {required this.progress, required this.track, required this.color});
  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = track;
    canvas.drawCircle(c, r, p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress, false, p..color = color);
  }

  @override
  bool shouldRepaint(_CurrentPainter o) =>
      o.progress != progress || o.color != color || o.track != track;
}

// ---- 퀘스트 ----

class _QuestsView extends StatelessWidget {
  const _QuestsView();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final today = s.todayKey;
    final week = s.thisWeekKey;
    final firstKey = QuestKind.firstSession.keyFor(today);
    final dailyKey = QuestKind.dailyGoal.keyFor(today);
    final weeklyKey = QuestKind.weeklyGoal.keyFor(week);
    final older = s.unopenedChests.difference({
      firstKey,
      dailyKey,
      weeklyKey,
      QuestKind.dailyLong.keyFor(today),
      QuestKind.weeklyHalf.keyFor(week),
      QuestKind.weeklyFull.keyFor(week),
    });
    // 고정 분량 퀘스트: 내 목표와 같으면 겹치므로 숨긴다 (안 연 상자가 있으면 보여 준다)
    List<Widget> fixed(QuestKind q, String period, int done, int goal, String when) =>
        q.minutes == goal && !s.unopenedChests.contains(q.keyFor(period))
            ? const []
            : [
                const SizedBox(height: MobileSize.cardGap),
                _QuestCard(
                  style: style,
                  title: '$when ${q.minutes}분 집중하기',
                  reward: '물방울 ${q.drops}개',
                  done: done,
                  goal: q.minutes!,
                  unit: '분',
                  chestKey: q.keyFor(period),
                ),
              ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 0, MobileSize.gutter,
          MobileSize.sectionGap),
      children: [
        if (older.isNotEmpty) ...[
          PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.card_giftcard_rounded,
            label: '지난 상자 ${older.length}개 열기',
            onTap: () {
              HapticFeedback.mediumImpact();
              s.openChests(older);
            },
          ),
          const SizedBox(height: MobileSize.gridGap),
        ],
        _SectionLabel(style: style, text: '오늘'),
        _QuestCard(
          style: style,
          title: '오늘 한 번 끝까지 집중하기',
          reward: '물방울 ${QuestKind.firstSession.drops}개',
          done: s.isRewarded(firstKey) ? 1 : 0,
          goal: 1,
          unit: '회',
          chestKey: firstKey,
        ),
        const SizedBox(height: MobileSize.cardGap),
        _QuestCard(
          style: style,
          title: '오늘 ${s.dailyGoal}분 집중하기',
          reward: '물방울 ${QuestKind.dailyGoal.drops}개',
          done: s.todayMinutes,
          goal: s.dailyGoal,
          unit: '분',
          chestKey: dailyKey,
        ),
        ...fixed(QuestKind.dailyLong, today, s.todayMinutes, s.dailyGoal, '오늘'),
        const SizedBox(height: MobileSize.sectionGap),
        _SectionLabel(style: style, text: '이번 주'),
        _QuestCard(
          style: style,
          title: '이번 주 ${s.weeklyGoal}분 집중하기',
          reward: '물방울 ${QuestKind.weeklyGoal.drops}개와 얼음',
          done: s.thisWeekMinutes,
          goal: s.weeklyGoal,
          unit: '분',
          chestKey: weeklyKey,
        ),
        for (final q in [QuestKind.weeklyHalf, QuestKind.weeklyFull])
          ...fixed(q, week, s.thisWeekMinutes, s.weeklyGoal, '이번 주'),
        const SizedBox(height: MobileSize.cardGap),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GoalPage())),
            child: Text('목표 바꾸기', style: TextStyle(color: style.accent)),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.style, required this.text});
  final SceneStyle style;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: MobileSize.cardGap),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: style.textMuted)),
      );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.style,
    required this.title,
    required this.reward,
    required this.done,
    required this.goal,
    required this.unit,
    required this.chestKey,
  });

  final SceneStyle style;
  final String title;
  final String reward;
  final int done;
  final int goal;
  final String unit;
  final String chestKey;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final rewarded = s.isRewarded(chestKey);
    final unopened = s.unopenedChests.contains(chestKey);
    return Container(
      constraints: const BoxConstraints(minHeight: MobileSize.questCard),
      padding: const EdgeInsets.all(MobileSize.cardPadding),
      decoration: _card(style),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.textStrong)),
                const SizedBox(height: MobileSize.labelGap),
                Text(
                    rewarded
                        ? (unopened ? '달성! 상자를 눌러 열어요' : '달성 · $reward 받음')
                        : '보상 $reward',
                    style: TextStyle(
                        fontSize: 13,
                        color: rewarded ? style.accent : style.textMuted)),
                const SizedBox(height: MobileSize.cardGap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Container(
                    height: MobileSize.goalBar,
                    color: style.ringTrack,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor:
                          (rewarded ? 1.0 : done / math.max(1, goal)).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: style.ringProgress),
                    ),
                  ),
                ),
                const SizedBox(height: MobileSize.labelGap),
                Text('${math.min(done, goal)} / $goal$unit',
                    style: TextStyle(fontSize: 12, color: style.textMuted)),
              ]),
        ),
        const SizedBox(width: MobileSize.gridGap),
        Semantics(
          container: true,
          button: unopened,
          onTap: unopened ? () => s.openChests([chestKey]) : null,
          label: unopened ? '상자 열기' : (rewarded ? '열린 상자' : '잠긴 상자'),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: unopened
                ? () {
                    HapticFeedback.mediumImpact();
                    s.openChests([chestKey]);
                  }
                : null,
            child: _Chest(
              style: style,
              open: rewarded && !unopened,
              dim: !rewarded,
              ready: unopened,
            ),
          ),
        ),
      ]),
    );
  }
}

/// 상자: 장면 색으로 그린다. 열릴 때 살짝 튀어 오른다.
class _Chest extends StatelessWidget {
  const _Chest(
      {required this.style,
      required this.open,
      required this.dim,
      required this.ready});
  final SceneStyle style;
  final bool open;
  final bool dim;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(clipBehavior: Clip.none, children: [
      TweenAnimationBuilder<double>(
        key: ValueKey(open),
        tween: Tween(begin: reduce ? 1 : 0.92, end: 1),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: CustomPaint(
          size: const Size.square(MobileSize.chest),
          painter: _ChestPainter(
            open: open,
            body: dim ? style.ringTrack : style.ringProgress,
            lid: dim ? style.divider : style.accent,
            mark: dim ? style.textFaint : style.rowBg,
          ),
        ),
      ),
      if (ready)
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: MobileSize.chestDot,
            height: MobileSize.chestDot,
            decoration:
                BoxDecoration(color: style.accent, shape: BoxShape.circle),
          ),
        ),
    ]);
  }
}

class _ChestPainter extends CustomPainter {
  const _ChestPainter(
      {required this.open,
      required this.body,
      required this.lid,
      required this.mark});
  final bool open;
  final Color body;
  final Color lid;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;
    final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(u * 0.12, u * 0.42, u * 0.76, u * 0.46),
        Radius.circular(u * 0.1));
    canvas.drawRRect(bodyRect, Paint()..color = body);
    final lidPaint = Paint()..color = lid;
    if (open) {
      // 열린 뚜껑과 안의 물방울
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(u * 0.12, u * 0.12, u * 0.76, u * 0.2),
              Radius.circular(u * 0.09)),
          lidPaint);
      for (final dx in [0.34, 0.5, 0.66]) {
        _drop(canvas, Offset(u * dx, u * 0.42), u * 0.075, lidPaint);
      }
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(u * 0.08, u * 0.28, u * 0.84, u * 0.26),
              Radius.circular(u * 0.11)),
          lidPaint);
      _drop(canvas, Offset(u * 0.5, u * 0.62), u * 0.08, Paint()..color = mark);
    }
  }

  void _drop(Canvas c, Offset center, double r, Paint p) {
    c.drawCircle(center, r, p);
    c.drawPath(
        Path()
          ..moveTo(center.dx - r * 0.85, center.dy - r * 0.45)
          ..lineTo(center.dx, center.dy - r * 1.9)
          ..lineTo(center.dx + r * 0.85, center.dy - r * 0.45)
          ..close(),
        p);
  }

  @override
  bool shouldRepaint(_ChestPainter o) =>
      o.open != open || o.body != body || o.lid != lid || o.mark != mark;
}

// ---- 업적 ----

class _AchievementsView extends StatelessWidget {
  const _AchievementsView();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    return ListView(
      padding: const EdgeInsets.fromLTRB(MobileSize.gutter, 0, MobileSize.gutter,
          MobileSize.sectionGap),
      children: [
        for (final a in Achievement.values) ...[
          Container(
            padding: const EdgeInsets.all(MobileSize.cardPadding),
            decoration: _card(style),
            child: Row(children: [
              Icon(
                s.hasAchievement(a)
                    ? Icons.emoji_events_rounded
                    : Icons.lock_outline_rounded,
                color: s.hasAchievement(a) ? style.accent : style.textFaint,
              ),
              const SizedBox(width: MobileSize.gridGap),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: style.textStrong)),
                      Text(a.detail,
                          style:
                              TextStyle(fontSize: 13, color: style.textMuted)),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: MobileSize.cardGap),
        ],
      ],
    );
  }
}
