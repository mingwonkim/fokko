// 1:1 대결: 마감일 계산 · 서버 오류 문구 · 대결 카드/화면 렌더(가짜 서버) — 예외 0
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/duel/duel_page.dart';
import 'package:focus_one/services/ranking_service.dart';
import 'package:focus_one/state/app_state.dart';

class _Fake extends RankingService {
  final accepted = <String>[];
  @override
  Future<List<Duel>> duels() async => [
        (code: 'AAAAAA', nickname: '새벽집중', avatar: 'owl', totalMinutes: 9500,
          myWeek: 200, theirWeek: 130, wins: 2, losses: 1, draws: 0),
        (code: 'BBBBBB', nickname: '도토리', avatar: '', totalMinutes: 20,
          myWeek: 40, theirWeek: 95, wins: 0, losses: 0, draws: 0),
        (code: 'CCCCCC', nickname: '하루한시간', avatar: 'fox', totalMinutes: 0,
          myWeek: 0, theirWeek: 0, wins: 0, losses: 0, draws: 1),
      ];
  @override
  Future<String> acceptInvite(String code) async {
    accepted.add(code);
    return '새벽집중';
  }
}

void main() {
  test('마감까지 남은 날', () {
    expect(daysLeft(DateTime(2026, 11, 2)), 6); // 월
    expect(daysLeft(DateTime(2026, 11, 8)), 0); // 일
  });

  test('수락 오류 문구', () {
    expect(acceptError(Exception('bad code')), '없는 초대 코드예요');
    expect(acceptError(Exception('own code')), '내 초대 코드예요');
    expect(acceptError(Exception('join first')), contains('참여'));
  });

  testWidgets('대결 카드·화면 + 초대 코드로 열면 수락', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(LocalStore(File('${dir.path}/d.json')));
    await tester.runAsync(state.init);
    state.setRankNickname('집중러');
    final fake = _Fake();
    for (final scene in FocusScene.values) {
      state.setScene(scene);
      for (final page in [
        const Scaffold(body: SingleChildScrollView(child: DuelCard())),
        const DuelPage(initialCode: 'K7M2QX'),
      ]) {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            Provider<RankingService>.value(value: fake),
          ],
          child: MaterialApp(home: page),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1)); // 회전 테두리라 settle 안 됨
        expect(tester.takeException(), isNull, reason: '$scene');
      }
    }
    expect(find.text('3명 중 1명에게 앞서는 중'), findsOneWidget);
    expect(fake.accepted, contains('K7M2QX'));
    state.dispose();
  });
}
