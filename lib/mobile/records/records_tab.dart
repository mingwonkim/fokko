// lib/mobile/records/records_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/task.dart';
import '../../state/app_state.dart';
import '../../state/stats.dart';
import '../focus/sheets.dart' show tagColor;
import '../duel/duel_page.dart';
import 'profile_card.dart';

enum _Period { day, week, month, year }

/// 경쟁 탭 (spec §2, 옛 이름 기록): 연속일 → 일/주/월/년·기간 이동 → 시간/횟수 → 막대 → 태그 → 잔디 → 골든타임 → 세션
class RecordsTab extends StatefulWidget {
  const RecordsTab({super.key});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  _Period _period = _Period.week;
  int _offset = 0; // 0 = 이번 기간, -1 = 이전…

  (DateTime, DateTime) _range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.day:
        final d = DateTime(today.year, today.month, today.day + _offset);
        return (d, DateTime(d.year, d.month, d.day + 1));
      case _Period.week:
        final monday = DateTime(today.year, today.month,
            today.day - (today.weekday - 1) + 7 * _offset);
        return (monday, DateTime(monday.year, monday.month, monday.day + 7));
      case _Period.month:
        final m = DateTime(today.year, today.month + _offset);
        return (m, DateTime(m.year, m.month + 1));
      case _Period.year:
        final y = DateTime(today.year + _offset);
        return (y, DateTime(y.year + 1));
    }
  }

  String _label((DateTime, DateTime) r) {
    final (a, b) = r;
    return switch (_period) {
      _Period.day => '${a.month}월 ${a.day}일',
      _Period.week =>
        '${a.month}.${a.day} – ${b.subtract(const Duration(days: 1)).month}.${b.subtract(const Duration(days: 1)).day}',
      _Period.month => '${a.year}년 ${a.month}월',
      _Period.year => '${a.year}년',
    };
  }

  (List<int>, List<String>) _bars(FocusStats st, (DateTime, DateTime) r) {
    final (a, b) = r;
    return switch (_period) {
      _Period.day => (
          st.hours(a),
          [for (var h = 0; h < 24; h++) h % 6 == 0 ? '$h' : '']
        ),
      _Period.week => (
          st.range(a, 7),
          const ['월', '화', '수', '목', '금', '토', '일']
        ),
      _Period.month => (
          st.range(a, b.difference(a).inDays),
          [
            for (var d = 1; d <= b.difference(a).inDays; d++)
              d == 1 || d % 7 == 0 ? '$d' : ''
          ]
        ),
      _Period.year => (
          st.months(a.year),
          [for (var m = 1; m <= 12; m++) m % 3 == 1 ? '$m월' : '']
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final now = DateTime.now();
    final st = FocusStats(s.sessions);
    final r = _range(now);
    final (bars, labels) = _bars(st, r);
    final total = bars.fold(0, (a, b) => a + b);
    final byTag = st.byTag(r.$1, r.$2);
    final golden = st.goldenHours(now);
    final recent = s.sessions.reversed.take(20).toList();

    Widget card(Widget child,
            {EdgeInsets? padding, double gap = MobileSize.cardGap}) =>
        Container(
          margin: EdgeInsets.only(bottom: gap),
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(style.rowShadow),
          ),
          child: child,
        );
    TextStyle label() => TextStyle(fontSize: 13, color: style.textMuted);
    TextStyle value() => TextStyle(
        fontSize: 22, fontWeight: FontWeight.w700, color: style.textStrong);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MobileSize.gutter, 8, MobileSize.gutter, MobileSize.contentBottomGap),
      children: [
        // 탭 제목 행 높이 통일 (할 일·풍경과 같은 48)
        SizedBox(
          height: MobileSize.headerMinHeight,
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('경쟁',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: style.textStrong))),
        ),
        const SizedBox(height: 16),
        const ProfileCard(), // 칭호·명예의 전당·자랑하기
        const DuelCard(), // 이번 주 1:1 대결·카톡 초대
        // 연속일 + 최근 7일 점
        card(Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('연속', style: label()),
            Text('${st.streak(now)}일', style: value()),
          ]),
          const Spacer(),
          for (final sec
              in st.range(DateTime(now.year, now.month, now.day - 6), 7))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sec >= 60 ? style.ringProgress : style.divider,
                ),
              ),
            ),
        ])),
        const SizedBox(height: MobileSize.sectionGap - MobileSize.cardGap),
        // 기간 선택
        SegmentedButton<_Period>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Period.day, label: Text('일')),
            ButtonSegment(value: _Period.week, label: Text('주')),
            ButtonSegment(value: _Period.month, label: Text('월')),
            ButtonSegment(value: _Period.year, label: Text('년')),
          ],
          selected: {_period},
          onSelectionChanged: (v) => setState(() {
            _period = v.first;
            _offset = 0;
          }),
        ),
        Row(children: [
          IconButton(
              tooltip: '이전',
              icon: Icon(Icons.chevron_left_rounded, color: style.textMuted),
              onPressed: () => setState(() => _offset--)),
          Expanded(
            child: Text(_label(r),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.textStrong)),
          ),
          IconButton(
              tooltip: '다음',
              icon: Icon(Icons.chevron_right_rounded,
                  color: _offset < 0 ? style.textMuted : style.divider),
              onPressed: _offset < 0 ? () => setState(() => _offset++) : null),
        ]),
        Row(children: [
          Expanded(
              child: card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('집중 시간', style: label()),
                Text(_hm(total), style: value()),
              ]))),
          const SizedBox(width: 12),
          Expanded(
              child: card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('완료', style: label()),
                Text('${st.completedCount(r.$1, r.$2)}회', style: value()),
              ]))),
        ]),
        card(SizedBox(
          height: total == 0 ? 96 : 160, // 빈 상태는 작게 — 아래 달력을 밀어내지 않게
          child: total == 0
              ? Center(child: Text('기록 없음', style: label()))
              : CustomPaint(
                  painter: _BarsPainter(bars, labels, style.ringProgress,
                      style.divider,
                      DefaultTextStyle.of(context)
                          .style
                          .copyWith(fontSize: 11, color: style.textMuted))),
        )),
        if (byTag.isNotEmpty)
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('태그별', style: label()),
            const SizedBox(height: 12),
            for (final e
                in (byTag.entries.toList()..sort((a, b) => b.value - a.value)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tagColor(
                          style,
                          s.tags
                                  .where((t) => t.id == e.key)
                                  .firstOrNull
                                  ?.colorIndex ??
                              4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        s.tags.where((t) => t.id == e.key).firstOrNull?.name ??
                            (e.key.isEmpty ? '태그 없음' : '삭제된 태그'),
                        style:
                            TextStyle(fontSize: 14, color: style.textStrong)),
                  ),
                  Text(_hm(e.value),
                      style: TextStyle(fontSize: 14, color: style.textMuted)),
                ]),
              ),
          ])),
        // 차트·태그 묶음과 달력 사이는 섹션 간격
        const SizedBox(height: MobileSize.sectionGap - MobileSize.cardGap),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_calMonth(r).month}월 집중 달력', style: label()),
          const SizedBox(height: 12),
          _MonthDots(
              month: _calMonth(r),
              data: st.monthDots(_calMonth(r)),
              style: style),
        ])),
        card(Row(children: [
          Text('골든타임', style: label()),
          const Spacer(),
          Text(
            golden.isEmpty ? '아직 몰라요' : golden.map((h) => '$h시').join(' · '),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: style.textStrong),
          ),
        ])),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('최근 세션', style: label()),
          const SizedBox(height: 8),
          for (final x in recent)
            card(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              Row(children: [
                Expanded(
                  child: Text(
                    x.taskTitle.isEmpty ? '집중' : x.taskTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: style.textStrong),
                  ),
                ),
                Text(
                  '${x.endedAt.month}.${x.endedAt.day} · ${_hm(x.focusedSec ?? x.minutes * 60)}'
                  '${x.outcome == SessionOutcome.completed ? '' : ' · 중단'}',
                  style: TextStyle(fontSize: 13, color: style.textMuted),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  /// 달력은 보고 있는 기간의 달 (년 보기면 이번 달)
  DateTime _calMonth((DateTime, DateTime) r) => _period == _Period.year
      ? DateTime(DateTime.now().year, DateTime.now().month)
      : DateTime(r.$1.year, r.$1.month);

  static String _hm(int sec) {
    final m = sec ~/ 60;
    return m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.labels, this.color, this.track, this.text);
  final List<int> values;
  final List<String> labels;
  final Color color, track;
  final TextStyle text; // 캔버스 글자는 테마 글꼴을 상속하지 않아 직접 받는다

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    final maxV = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final w = size.width / values.length;
    final barW = (w * 0.6).clamp(2.0, 24.0);
    final h = size.height - labelH;
    for (var i = 0; i < values.length; i++) {
      final x = i * w + (w - barW) / 2;
      final bh = values[i] / maxV * h;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h - bh.clamp(2.0, h), barW, bh.clamp(2.0, h)),
          Radius.circular(barW / 2));
      canvas.drawRRect(r, Paint()..color = values[i] == 0 ? track : color);
      if (labels[i].isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: text),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * w + w / 2 - tp.width / 2, h + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.values != values || o.color != color;
}

/// 한 달 달력에 날마다 점 하나: 색 = 그날 가장 오래 집중한 장면, 크기 = 집중 시간 4단계.
/// 숫자는 쓰지 않는다(정보 과밀 금지). 오늘만 테두리.
class _MonthDots extends StatelessWidget {
  const _MonthDots(
      {required this.month, required this.data, required this.style});
  final DateTime month;
  final Map<DateTime, (int, String?)> data;
  final SceneStyle style;

  @override
  Widget build(BuildContext context) {
    final lead = month.weekday - 1; // 월요일 시작
    final days = data.length;
    final today = DateTime.now();
    final cells = lead + days;
    return Column(children: [
      Row(children: [
        for (final w in const ['월', '화', '수', '목', '금', '토', '일'])
          Expanded(
            child: Center(
              child: Text(w,
                  style: TextStyle(fontSize: 11, color: style.textMuted)),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      for (var row = 0; row * 7 < cells; row++)
        SizedBox(
          height: 36,
          child: Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(child: _dot(row * 7 + c - lead + 1, days, today)),
          ]),
        ),
    ]);
  }

  Widget _dot(int day, int days, DateTime today) {
    if (day < 1 || day > days) return const SizedBox.shrink();
    final d = DateTime(month.year, month.month, day);
    final (lv, scene) = data[d]!;
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final color = lv == 0
        ? style.divider
        : (FocusScene.values.asNameMap()[scene] ?? FocusScene.forest)
            .style
            .ringProgress;
    final size = lv == 0 ? 6.0 : 10.0 + lv * 4; // 6 / 14 / 18 / 22 / 26
    return Center(
      child: Semantics(
        label: '$day일 ${lv == 0 ? '집중 없음' : '집중 $lv단계'}',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: style.textStrong, width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }
}
