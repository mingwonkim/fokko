// 리그: 화면 값 파싱·승강 구역, 세션 예약·제출 재시도, 리그 화면
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/growth/league_view.dart';
import 'package:focus_one/models/league.dart';
import 'package:focus_one/services/league_sync.dart';
import 'package:focus_one/services/ranking_service.dart';
import 'package:focus_one/state/app_state.dart';

LeagueRow row(int rank, {bool me = false, int minutes = 100}) => LeagueRow(
    rank: rank,
    nickname: 'u$rank',
    avatar: 'fawn',
    minutes: minutes,
    totalMinutes: 500,
    isMe: me);

class FakeRanking extends RankingService {
  LeagueStatus status = const LeagueStatus(joined: false);
  final begun = <String>[];
  final finished = <String>[];
  final calls = <String>[];
  Set<String> failIds = {};
  Object? finishError;
  bool joined = false;
  bool left = false;

  @override
  Future<LeagueStatus> leagueStatus() async => status;
  @override
  Future<void> joinLeague() async {
    joined = true;
    status = const LeagueStatus(joined: true);
  }

  @override
  Future<void> leaveLeague() async {
    left = true;
    status = const LeagueStatus(joined: false);
  }

  @override
  Future<void> beginFocus(String sessionId, int plannedSec) async {
    begun.add(sessionId);
    calls.add('begin:$sessionId');
  }
  @override
  Future<int> finishFocus(String sessionId) async {
    calls.add('finish:$sessionId');
    if (finishError != null) throw finishError!;
    if (failIds.contains(sessionId)) throw Exception('too early');
    finished.add(sessionId);
    return 25;
  }
}

void main() {
  group('LeagueStatus', () {
    test('서버 JSON', () {
      final s = LeagueStatus.fromJson({
        'joined': true,
        'tier': 1,
        'week': '2026-11-02',
        'board': [
          {'rank': 1, 'nickname': 'a', 'avatar': '', 'minutes': 10, 'total_minutes': 30, 'is_me': true}
        ],
        'last_result': {
          'week': '2026-10-26', 'rank': 2, 'group_size': 5, 'minutes': 40,
          'from_tier': 0, 'to_tier': 1
        },
      });
      expect(s.tier, LeagueTier.explore);
      expect(s.board.single.isMe, isTrue);
      expect(s.lastResult!.to, LeagueTier.explore);
      expect(LeagueStatus.fromJson({'joined': false}).joined, isFalse);
    });

    test('동점이면 구분선도 서버 정산과 같다', () {
      LeagueStatus of(List<(int, int)> rows) => LeagueStatus(
          joined: true,
          tier: LeagueTier.explore,
          board: [for (final (rank, minutes) in rows) row(rank, minutes: minutes)]);
      final allTied = of([(1, 100), (1, 100), (1, 100), (1, 100), (1, 100)]);
      expect(allTied.promoteCount, 5, reason: '전원 1위 승급');
      expect(allTied.demoteCount, 0, reason: '선 동점은 강등 없음');
      final zero = of([(1, 0), (1, 0), (1, 0), (1, 0), (1, 0)]);
      expect(zero.promoteCount, 0, reason: '0분은 승급 안 함');
      final bottomTied = of([(1, 90), (2, 50), (3, 50), (4, 10), (4, 10)]);
      expect(bottomTied.promoteCount, 1);
      expect(bottomTied.demoteCount, 0, reason: '하위 동점은 강등 제외');
      final clear = of([(1, 90), (2, 50), (3, 40), (4, 30), (5, 10)]);
      expect(clear.demoteCount, 1);
    });

    test('승강 구역은 서버 규칙과 같다', () {
      LeagueStatus of(int n, LeagueTier t) => LeagueStatus(
          joined: true, tier: t, board: [for (var i = 1; i <= n; i++) row(i, minutes: 200 - i * 10)]);
      expect(of(10, LeagueTier.explore).promoteCount, 2);
      expect(of(10, LeagueTier.explore).demoteCount, 2);
      expect(of(4, LeagueTier.explore).promoteCount, 1);
      expect(of(4, LeagueTier.explore).demoteCount, 0);
      expect(of(3, LeagueTier.explore).promoteCount, 0, reason: '소규모는 150분 규칙');
      expect(of(10, LeagueTier.voyage).promoteCount, 0);
      expect(of(10, LeagueTier.walk).demoteCount, 0);
    });
  });

  group('LeagueSync', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fo'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 임시 폴더
      }
    });

    test('못 보낸 세션을 먼저 보내고 새 세션을 예약한다', () async {
      final st = AppState(LocalStore(File('${dir.path}/o.json')));
      await st.init();
      st.setRankNickname('나');
      st.setLeagueJoined(true);
      st.addLeagueOutboxForTest('old');
      final fake = FakeRanking();
      final sync = LeagueSync(st, fake);
      st.startTimer(allowNoTask: true);
      await sync.sync();
      expect(fake.calls, ['finish:old', 'begin:${st.activeSession!.id}']);
      st.stopTimer();
      st.dispose();
    });

    test('한 세션 전송 실패가 다른 세션을 막지 않는다', () async {
      final st = AppState(LocalStore(File('${dir.path}/p.json')));
      await st.init();
      st.setRankNickname('나');
      st.setLeagueJoined(true);
      st.addLeagueOutboxForTest('bad');
      st.addLeagueOutboxForTest('good');
      final fake = FakeRanking()..failIds = {'bad'};
      await LeagueSync(st, fake).sync();
      expect(st.leagueOutbox, {'bad'});
      expect(fake.finished, ['good']);
      st.dispose();
    });

    test('시작 뒤 오래 지난 세션은 재실행해도 새로 예약하지 않는다', () async {
      final st = AppState(LocalStore(File('${dir.path}/q.json')));
      await st.init();
      st.setRankNickname('나');
      st.setLeagueJoined(true);
      st.startTimer(allowNoTask: true);
      final started = st.activeSession!.startedAt;
      final fake = FakeRanking();
      await LeagueSync(st, fake, now: () => started.add(const Duration(minutes: 2)))
          .sync();
      expect(fake.begun, isEmpty, reason: '재실행 복구');
      await LeagueSync(st, fake, now: () => started.add(const Duration(seconds: 5)))
          .sync();
      expect(fake.begun, hasLength(1), reason: '방금 시작');
      st.stopTimer();
      st.dispose();
    });

    test('참여 안 했으면 아무것도 안 보낸다', () async {
      final st = AppState(LocalStore(File('${dir.path}/d.json')));
      await st.init();
      final fake = FakeRanking();
      final sync = LeagueSync(st, fake)..start();
      st.startTimer(allowNoTask: true);
      await sync.sync();
      expect(fake.begun, isEmpty);
      st.stopTimer();
      sync.stop();
      st.dispose();
    });

    test('참여 중: 시작을 한 번만 예약하고, 끝난 세션은 실패해도 남았다가 다시 보낸다', () async {
      final file = File('${dir.path}/d.json');
      final st = AppState(LocalStore(file));
      await st.init();
      st.setRankNickname('나');
      st.setLeagueJoined(true);
      st.setDurationMinutes(10);
      var now = DateTime.now();
      final fake = FakeRanking()..finishError = Exception('too early');
      final sync = LeagueSync(st, fake,
          now: () => now, retry: const Duration(seconds: 30));
      st.startTimer(allowNoTask: true);
      final id = st.activeSession!.id;
      await sync.sync();
      await sync.sync();
      expect(fake.begun, [id]);

      // 앱을 껐다 끝난 뒤 켠다고 치고 저장 파일에서 세션을 끝낸다
      await st.flush();
      st.dispose();
      final raw = file.readAsStringSync();
      final past = DateTime.now().subtract(const Duration(hours: 1));
      file.writeAsStringSync(raw
          .replaceAll(RegExp(r'"startedAt":"[^"]+"'), '"startedAt":"${past.toIso8601String()}"')
          .replaceAll(RegExp(r'"resumedAt":"[^"]+"'), '"resumedAt":"${past.toIso8601String()}"'));
      final b = AppState(LocalStore(file));
      await b.init();
      expect(b.leagueOutbox, {id});

      final sync2 = LeagueSync(b, fake, now: () => now);
      await sync2.sync();
      expect(b.leagueOutbox, {id}, reason: '실패하면 남는다');
      fake.finishError = null;
      await sync2.sync();
      expect(fake.finished, isEmpty, reason: '재시도 대기 중');
      now = now.add(const Duration(seconds: 31));
      await sync2.sync();
      expect(fake.finished, [id]);
      expect(b.leagueOutbox, isEmpty);
      await b.flush();
      b.dispose();
    });

    test('랭킹에서 나가면 리그 참여와 대기열도 지운다', () async {
      final st = AppState(LocalStore(File('${dir.path}/d.json')));
      await st.init();
      st.setRankNickname('나');
      st.setLeagueJoined(true);
      st.setRankNickname(null);
      expect(st.leagueJoined, isFalse);
      st.dispose();
    });
  });

  group('리그 화면', () {
    Future<(AppState, FakeRanking)> pump(
        WidgetTester tester, Size size, double scale,
        {LeagueStatus? status, String? nickname, FocusScene? scene}) async {
      final dir = Directory.systemTemp.createTempSync('fo');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // 임시 폴더
        }
      });
      final st = AppState(LocalStore(File('${dir.path}/d.json')));
      if (nickname != null) st.setRankNickname(nickname);
      if (scene != null) st.setScene(scene);
      final fake = FakeRanking();
      if (status != null) fake.status = status;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: st),
            Provider<RankingService>.value(value: fake),
          ],
          child: const MaterialApp(home: Scaffold(body: LeagueView())),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return (st, fake);
    }

    final full = LeagueStatus(
      joined: true,
      tier: LeagueTier.explore,
      week: '2026-11-02',
      board: [for (var i = 1; i <= 10; i++) row(i, me: i == 4, minutes: 200 - i * 10)],
      lastResult: const LeagueResult(
          week: '2026-10-26', rank: 2, groupSize: 5, minutes: 90,
          from: LeagueTier.walk, to: LeagueTier.explore),
    );

    testWidgets('닉네임 없으면 명예의 전당 안내', (tester) async {
      final (st, _) = await pump(tester, const Size(402, 874), 1);
      expect(find.text('명예의 전당에 먼저 참여하기'), findsOneWidget);
      st.dispose();
    });

    testWidgets('참여 버튼 → 서버 참여 → 빈 조 안내', (tester) async {
      final (st, fake) =
          await pump(tester, const Size(402, 874), 1, nickname: '나');
      await tester.tap(find.text('리그 참여하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fake.joined, isTrue);
      expect(st.leagueJoined, isTrue);
      expect(find.text('이번 주 첫 집중을 끝내면 조가 정해져요'), findsOneWidget);
      st.dispose();
    });

    for (final (name, size, scale) in [
      ('SE', const Size(375, 667), 1.0),
      ('큰 글자', const Size(375, 667), 1.5),
    ]) {
      for (final scene in FocusScene.values) {
        testWidgets('$name ${scene.name} 순위표 넘침 없음', (tester) async {
          final (st, _) = await pump(tester, size, scale,
              nickname: '나', status: full, scene: scene);
          expect(tester.takeException(), isNull);
          expect(find.text('여기까지 승급'), findsOneWidget);
          st.dispose();
        });
      }
    }

    testWidgets('연결 실패면 다시 시도', (tester) async {
      final dir = Directory.systemTemp.createTempSync('fo');
      final st = AppState(LocalStore(File('${dir.path}/d.json')));
      st.setRankNickname('나');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: st),
          Provider<RankingService>.value(value: _Failing()),
        ],
        child: const MaterialApp(home: Scaffold(body: LeagueView())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('연결이 안 돼요. 다시 시도'), findsOneWidget);
      st.dispose();
    });
  });
}

class _Failing extends FakeRanking {
  @override
  Future<LeagueStatus> leagueStatus() async => throw Exception('no function');
}
