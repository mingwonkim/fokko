// 게임화 화면 미리보기 PNG (macOS 전용: AppleGothic). CI 대상 아님.
// 실행: flutter test tool/preview/game_capture_test.dart --dart-define=OUT=<dir>
// 프로필 카드(칭호 4단계) · 공유 카드 · 명예의 전당(가짜 서버) · 승급 보상 시트
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/duel/duel_page.dart';
import 'package:focus_one/mobile/focus/sheets.dart';
import 'package:focus_one/mobile/records/profile_card.dart';
import 'package:focus_one/mobile/records/ranking_page.dart';
import 'package:focus_one/mobile/share/share_card.dart';
import 'package:focus_one/models/collection.dart';
import 'package:focus_one/models/task.dart';
import 'package:focus_one/services/ranking_service.dart';
import 'package:focus_one/state/app_state.dart';

import 'capture_test.dart' show loadFont;

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

class _FakeRanking extends RankingService {
  RankRow r(int rank, String n, String a, int p, int t, {bool me = false}) =>
      (rank: rank, nickname: n, avatar: a, points: p, totalMinutes: t, isMe: me);
  @override
  Future<List<RankRow>> ranking(RankPeriod period) async => [
        r(1, '고래사냥', 'whale', 1840, 31000),
        r(2, '새벽집중', 'owl', 1320, 9500),
        r(3, '도토리', 'squirrel', 990, 2600),
        r(4, '집중러', 'fawn', 610, 3000, me: true),
        r(5, '하루한시간', '', 420, 500),
        r(6, '시험기간', 'fox', 300, 160),
      ];
  @override
  Future<List<Duel>> duels() async => [
        (code: 'AAAAAA', nickname: '새벽집중', avatar: 'owl', totalMinutes: 9500,
          myWeek: 200, theirWeek: 130, wins: 2, losses: 1, draws: 0),
        (code: 'BBBBBB', nickname: '도토리', avatar: 'squirrel', totalMinutes: 2600,
          myWeek: 40, theirWeek: 95, wins: 0, losses: 3, draws: 0),
        (code: 'CCCCCC', nickname: '하루한시간', avatar: 'fox', totalMinutes: 160,
          myWeek: 0, theirWeek: 0, wins: 0, losses: 0, draws: 1),
      ];
  @override
  Future<List<RankRow>> pastWinners(RankPeriod period) async => [
        r(1, '고래사냥', 'whale', 2100, 29000),
        r(2, '도토리', 'squirrel', 1500, 2400),
        r(3, '새벽집중', 'owl', 1210, 9000),
      ];
}

void main() {
  testWidgets('game capture', (tester) async {
    await tester.runAsync(loadFont);
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));

    Future<AppState> stateWith(int minutes, {DateTime? at}) async =>
        (await tester.runAsync(() async {
          final f = File('${dir.path}/$minutes.json');
          final end = DateTime.now().subtract(const Duration(hours: 1));
          await LocalStore(f).save(StoreData(
            tasks: const [],
            inbox: const [],
            sessions: [
              FocusSession(
                  id: 's$minutes',
                  taskId: '',
                  taskTitle: '',
                  minutes: minutes,
                  endedAt: end,
                  focusedSec: minutes * 60,
                  segments: [(end.subtract(Duration(minutes: minutes)), end)],
                  scene: 'forest',
                  outcome: SessionOutcome.completed)
            ],
            progress: const Progress(rankNickname: '집중러'),
          ));
          final s = AppState(LocalStore(f));
          await s.init();
          return s;
        }))!;

    Future<void> shot(AppState state, Widget child, Size size, String name,
        {Future<void> Function()? then}) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(size);
      final theme = AppTheme.of(state.scene);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          Provider<RankingService>.value(value: _FakeRanking()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'AppleGothic')),
            home: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'AppleGothic'),
              child: child,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      if (then != null) await then();
      // 그림 디코딩 기다리기
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    const phone = Size(402, 874);
    // 프로필 카드: 씨앗 / 나무 / 달빛 / 마스터
    for (final (m, label) in [(12, 'seed'), (600, 'tree'), (3000, 'moon'), (31000, 'master')]) {
      final s = await stateWith(m);
      for (final scene in [FocusScene.forest, FocusScene.night]) {
        s.setScene(scene);
        await shot(
            s,
            Scaffold(
                backgroundColor: scene.style.cardBg,
                body: const Padding(
                    padding: EdgeInsets.all(MobileSize.gutter),
                    child: ProfileCard())),
            const Size(402, 400),
            'profile_${label}_${scene.name}');
      }
      if (m == 3000) {
        for (final scene in [FocusScene.ocean, FocusScene.night]) {
          s.setScene(scene);
          await shot(
              s,
              Scaffold(
                  backgroundColor: scene.style.cardBg,
                  body: const Center(
                      child: SizedBox(
                          width: 360,
                          child: AspectRatio(
                              aspectRatio: 4 / 5, child: ShareCard())))),
              const Size(402, 500),
              'share_${scene.name}');
        }
        for (final scene in [FocusScene.forest, FocusScene.night]) {
          s.setScene(scene);
          await shot(s, const DuelPage(), phone, 'duel_${scene.name}',
              then: () => tester.pump(const Duration(milliseconds: 300)));
          await shot(
              s,
              Scaffold(
                  backgroundColor: scene.style.cardBg,
                  body: const SingleChildScrollView(
                      padding: EdgeInsets.all(MobileSize.gutter),
                      child: DuelCard())),
              const Size(402, 640),
              'duelcard_${scene.name}',
              then: () => tester.pump(const Duration(milliseconds: 300)));
        }
        s.setScene(FocusScene.forest);
        await shot(s, const RankingPage(), phone, 'hall_forest',
            then: () => tester.pump(const Duration(milliseconds: 300)));
        s.setScene(FocusScene.night);
        await shot(s, const RankingPage(), phone, 'hall_night',
            then: () => tester.pump(const Duration(milliseconds: 300)));
      }
      s.dispose();
    }

    // 승급 보상 시트: 30분 세션 시작 → 1시간 뒤 다시 열면 완료(씨앗 → 새싹)
    final t0 = DateTime(2026, 11, 4, 9);
    final f = File('${dir.path}/promo.json');
    final promo = (await tester.runAsync(() async {
      final a = AppState(LocalStore(f));
      await withClock(Clock.fixed(t0), a.init);
      withClock(Clock.fixed(t0), () {
        a.setDurationMinutes(30);
        a.startTimer(allowNoTask: true);
      });
      await a.flush();
      a.dispose();
      final b = AppState(LocalStore(f));
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))), b.init);
      return b;
    }))!;
    await shot(
        promo,
        Scaffold(
          backgroundColor: promo.scene.style.cardBg,
          body: Builder(
              builder: (ctx) => Center(
                  child: TextButton(
                      onPressed: () => showRewardSheet(ctx),
                      child: const Text('열기')))),
        ),
        phone,
        'promotion', then: () async {
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
