// v3 4단계 미리보기: 리그 화면 (macOS 전용: AppleGothic). CI 대상 아님.
// 실행: flutter test tool/preview/league_capture_test.dart --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/growth/league_view.dart';
import 'package:focus_one/models/league.dart';
import 'package:focus_one/services/ranking_service.dart';
import 'package:focus_one/state/app_state.dart';

import 'capture_test.dart' show loadFont;

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

class _Fake extends RankingService {
  _Fake(this.s);
  final LeagueStatus s;
  @override
  Future<LeagueStatus> leagueStatus() async => s;
}

void main() {
  testWidgets('league capture', (tester) async {
    await tester.runAsync(loadFont);
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 임시 폴더
      }
    });
    final state = AppState(LocalStore(File('${dir.path}/d.json')));
    const names = ['고래사냥', '새벽집중', '도토리', '집중러', '하루한시간', '시험기간', '달리기', '책벌레', '커피', '느림보'];
    const pics = ['whale', 'owl', 'squirrel', 'fawn', 'fox', 'rabbit', 'turtle', 'cat', 'puppy', 'bear'];
    final full = LeagueStatus(
      joined: true,
      tier: LeagueTier.explore,
      week: '2026-11-02',
      board: [
        for (var i = 0; i < 10; i++)
          LeagueRow(
              rank: i + 1,
              nickname: names[i],
              avatar: pics[i],
              minutes: 420 - i * 40,
              totalMinutes: 3000 - i * 300,
              isMe: i == 3)
      ],
      lastResult: const LeagueResult(
          week: '2026-10-26', rank: 2, groupSize: 8, minutes: 240,
          from: LeagueTier.walk, to: LeagueTier.explore),
    );
    const size = Size(402, 874);
    Future<void> shot(FocusScene scene, LeagueStatus s, String? nick, String name) async {
      state.setScene(scene);
      state.setRankNickname(nick);
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          Provider<RankingService>.value(value: _Fake(s)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(scene).copyWith(
              textTheme:
                  AppTheme.of(scene).textTheme.apply(fontFamily: 'AppleGothic')),
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: const MediaQueryData(
                  size: size, padding: EdgeInsets.only(top: 59, bottom: 34)),
              child: Scaffold(
                  backgroundColor: scene.style.cardBg,
                  body: const SafeArea(child: LeagueView())),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1.5);
        final d = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
      });
    }

    await shot(FocusScene.forest, full, '집중러', 'board');
    await shot(FocusScene.night, full, '집중러', 'board-night');
    await shot(FocusScene.forest, const LeagueStatus(joined: false), '집중러', 'intro');
    await shot(FocusScene.ocean,
        const LeagueStatus(joined: true, week: '2026-11-02'), '집중러', 'empty');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
