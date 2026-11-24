// 성장 탭: 작은 폰·큰 글자 넘침 없음, 상자 열기, 현재 칸이 보임
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/growth/companion_page.dart';
import 'package:focus_one/mobile/growth/growth_tab.dart';
import 'package:focus_one/models/collection.dart';
import 'package:focus_one/mobile/widgets/title_avatar.dart';
import 'package:focus_one/models/focus_title.dart';
import 'package:focus_one/models/growth.dart';
import 'package:focus_one/models/task.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('fo'));
  tearDown(() {
    // 앱 상태가 뒤늦게 저장 중일 수 있다 — 임시 폴더라 남아도 무해
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 무시
    }
  });

  Future<AppState> seeded(WidgetTester tester, int minutes) async {
    final file = File('${dir.path}/d.json');
    final now = clock.now();
    await tester.runAsync(() => LocalStore(file).save(StoreData(
          tasks: const [],
          inbox: const [],
          sessions: [
            if (minutes > 0)
              FocusSession(
                  id: 's',
                  taskId: '',
                  taskTitle: '',
                  minutes: minutes,
                  endedAt: now,
                  focusedSec: minutes * 60,
                  scene: 'forest',
                  companionId: 'fawn',
                  outcome: SessionOutcome.completed),
          ],
        )));
    final st = AppState(LocalStore(file));
    await tester.runAsync(st.init);
    return st;
  }

  Widget app(AppState st, Size size, double scale, Widget home) => MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: ChangeNotifierProvider.value(
            value: st, child: MaterialApp(home: Scaffold(body: home))),
      );

  for (final (name, size, scale) in [
    ('SE', const Size(375, 667), 1.0),
    ('큰 글자', const Size(375, 667), 1.5),
  ]) {
    for (final scene in FocusScene.values) {
      testWidgets('$name ${scene.name} 세 구역', (tester) async {
        final st = await seeded(tester, 40);
        st.setScene(scene);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(st, size, scale, const GrowthTab()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final label in ['퀘스트', '업적', '지도']) {
          await tester.tap(find.textContaining(label).first);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: label);
        }
        st.dispose();
      });
    }
  }

  testWidgets('지도는 지금 칸 근처에서 시작한다', (tester) async {
    final st = await seeded(tester, 2400);
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        app(st, const Size(402, 874), 1, const GrowthTab()));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('지금 여기')), findsOneWidget);
    st.dispose();
  });

  test('칭호 칸 글자는 칭호 색 위에서 읽힌다, 장식은 칭호마다 다르다', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    for (final scene in FocusScene.values) {
      for (final r in TitleRings.all) {
        final base = r.colors.first;
        final future = Color.lerp(
            base, scene.style.cardBg, MobileSize.mapFutureFade)!;
        expect(contrast(base, TitleRing.textOn(base)), greaterThanOrEqualTo(4.5),
            reason: '지나온 칸 $base');
        // 안 간 칸 숫자는 24pt 이상 굵은 글자라 큰 글자 기준 3:1
        expect(contrast(future, TitleRing.textOn(future)),
            greaterThanOrEqualTo(3),
            reason: '${scene.name} 안 간 칸 $future');
      }
    }
    final looks = {
      for (final r in TitleRings.all)
        r.ornaments.map((o) => '${o.shape.name}${o.count}').join('+')
    };
    expect(looks, hasLength(TitleRings.all.length));
  });

  testWidgets('작은 폰에서 칭호 글자가 모두 화면 안에 있다', (tester) async {
    final st = await seeded(tester, 40000);
    const size = Size(375, 7000);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(st, size, 1, const GrowthTab()));
    await tester.pump();
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(0);
    await tester.pump();
    final badges = find.byType(TitleBadge);
    expect(badges, findsNWidgets(FocusTitle.values.length + 1)); // 상단 카드 포함
    for (final e in badges.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(0));
      expect(left + box.size.width, lessThanOrEqualTo(size.width));
    }
    st.dispose();
  });

  test('지도 배경은 칭호 구간마다 색이 다르고 갑자기 바뀌지 않는다', () {
    final style = FocusScene.forest.style;
    final titled = [
      for (var i = 0; i < MapNode.all.length; i++)
        if (MapNode.all[i].title != null) i
    ];
    final colors = {for (final r in titled) mapBackgroundAt(style, r + 0.0)};
    expect(colors.length, greaterThanOrEqualTo(FocusTitle.values.length - 1),
        reason: '칭호마다 다른 배경');
    for (var r = 0.0; r < MapNode.all.length; r += 0.25) {
      final a = mapBackgroundAt(style, r), b = mapBackgroundAt(style, r + 0.25);
      expect((a.r - b.r).abs(), lessThan(0.06), reason: '줄 $r');
      expect((a.g - b.g).abs(), lessThan(0.06), reason: '줄 $r');
      expect((a.b - b.b).abs(), lessThan(0.06), reason: '줄 $r');
    }
  });

  for (final minutes in [0, 40, 200, 1000, 3000, 8000, 20000]) {
    testWidgets('$minutes분: 지금 여기 표시가 하나, 작은 폰 화면 안', (tester) async {
      final st = await seeded(tester, minutes);
      const size = Size(375, 667);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(st, size, 1, const GrowthTab()));
      await tester.pump();
      final here = find.text('지금 여기');
      expect(here, findsOneWidget);
      final box = tester.renderObject<RenderBox>(here);
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(0));
      expect(left + box.size.width, lessThanOrEqualTo(size.width));
      st.dispose();
    });
  }

  testWidgets('멀리 스크롤하면 지금 위치로 버튼이 나오고 누르면 돌아온다', (tester) async {
    final st = await seeded(tester, 40);
    const size = Size(402, 874);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(st, size, 1, const GrowthTab()));
    await tester.pump();
    expect(find.text('지금 위치로'), findsNothing);
    final list = tester.state<ScrollableState>(find.byType(Scrollable).last);
    list.position.jumpTo(3000);
    await tester.pump();
    expect(find.text('지금 위치로'), findsOneWidget);
    expect(find.text('지금 여기'), findsNothing);
    await tester.tap(find.text('지금 위치로'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('지금 여기'), findsOneWidget);
    expect(find.text('지금 위치로'), findsNothing);
    st.dispose();
  });

  testWidgets('지도 머리에 레벨과 다음 레벨까지 남은 분', (tester) async {
    final st = await seeded(tester, 40); // 30(Lv.2) 지나 65(Lv.3)까지
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        app(st, const Size(402, 874), 1, const GrowthTab()));
    await tester.pump();
    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.textContaining('다음 레벨까지 25분'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Lv\.3, 지금 여기')), findsOneWidget);
    st.dispose();
  });

  testWidgets('퀘스트에 75·225·450분, 내 목표와 같으면 하나만', (tester) async {
    final st = await seeded(tester, 40);
    const size = Size(402, 1400);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(st, size, 1, const GrowthTab()));
    await tester.tap(find.textContaining('퀘스트'));
    await tester.pump();
    for (final t in ['오늘 75분 집중하기', '이번 주 225분 집중하기', '이번 주 450분 집중하기']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    st.setDailyGoal(75);
    st.setWeeklyGoal(225);
    await tester.pump();
    expect(find.text('오늘 75분 집중하기'), findsOneWidget);
    expect(find.text('이번 주 225분 집중하기'), findsOneWidget);
    st.dispose();
  });

  testWidgets('업적에 90·180·365일', (tester) async {
    final st = await seeded(tester, 40);
    const size = Size(402, 1200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(st, size, 1, const GrowthTab()));
    await tester.tap(find.text('업적'));
    await tester.pump();
    for (final t in ['90일 연속', '180일 연속', '365일 연속']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    st.dispose();
  });

  testWidgets('상자를 열면 안 연 상자가 줄고 물방울은 그대로', (tester) async {
    // 끝날 시각이 지난 진행 세션을 켜면 실제 완료 경로로 보상이 나온다
    final started = DateTime.now().subtract(const Duration(minutes: 30));
    final file = File('${dir.path}/d.json');
    await tester.runAsync(() => LocalStore(file).save(StoreData(
          tasks: const [],
          inbox: const [],
          sessions: const [],
          activeSession: ActiveSession(
            id: 'a',
            taskId: '',
            taskTitle: '',
            scene: 'forest',
            startedAt: started,
            plannedSec: 1500,
            resumedAt: started,
            companionId: 'fawn',
          ),
        )));
    final b = AppState(LocalStore(file));
    await tester.runAsync(b.init);
    expect(b.unopenedChests, isNotEmpty);
    final drops = b.drops;
    final count = b.unopenedChests.length;

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        app(b, const Size(402, 874), 1, const GrowthTab()));
    await tester.tap(find.textContaining('퀘스트'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('상자 열기').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(b.unopenedChests.length, count - 1);
    expect(b.drops, drops);
    b.dispose();
  });

  testWidgets('친구 성장 화면', (tester) async {
    final st = await seeded(tester, 130);
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp(
            home: CompanionPage(companion: Companion.byId('fawn')!))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('470분 더 함께하면 빛나는 단짝'), findsOneWidget);
    st.dispose();
  });
}
