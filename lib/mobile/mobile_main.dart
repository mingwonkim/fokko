// lib/mobile/mobile_main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../data/local_store.dart';
import '../services/mobile_sound_service.dart';
import '../services/league_sync.dart';
import '../services/ranking_service.dart';
import '../services/focus_lock_service.dart';
import '../services/session_notifier.dart';
import '../state/app_state.dart';
import 'duel/invite.dart';
import 'mobile_shell.dart';

/// 폰(iOS/Android) 진입점. 데스크탑 전용 서비스는 만들지 않는다.
Future<void> runMobile() async {
  // 집중 링 화면은 세로 전용
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final appState = AppState(LocalStore())
    ..autoBreak = false; // 폰: 휴식은 보상 시트에서 선택
  await appState.init();

  // 집중 중에만 소리 (데스크탑과 같은 규칙). 화면이 꺼져도 계속 재생.
  final sound = MobileSoundService();
  try {
    await sound.init();
  } catch (e) {
    debugPrint('sound init: $e');
  }
  appState.addListener(() {
    sound.setVolume(appState.soundVolume);
    final on = appState.phase == FocusPhase.focus &&
        appState.isRunning &&
        appState.soundEnabled &&
        appState.soundVolume > 0;
    sound.set(on ? appState.soundAsset : null);
  });

  // 세션 종료 알림 (거부돼도 앱은 정상 동작)
  final notifier = SessionNotifier();
  try {
    await notifier.init();
    appState.addListener(() => notifier.sync(appState));
  } catch (_) {}

  // 앱 잠금: 진행 중(재생)일 때만 잠그고, 일시정지·그만두기·완료면 해제.
  // iOS는 남은 시간이 15분 미만이면 잠그지 않는다(FocusLockService.minLock).
  final lock = FocusLockService();
  // 이번 재생 구간에 이미 시도했는지(성공 여부 무관) — 매초 틱마다 재시도하지 않게
  String? triedFor;
  var wasReady = appState.lockReady;
  appState.addListener(() async {
    final a = appState.activeSession;
    final want = appState.lockEnabled && a != null && a.isRunning;
    // 권한을 되찾으면 진행 중 세션에도 다시 건다
    if (appState.lockReady && !wasReady) triedFor = null;
    wasReady = appState.lockReady;
    try {
      if (want && triedFor != a.id) {
        triedFor = a.id;
        final ends =
            DateTime.now().add(Duration(seconds: appState.remainingSeconds));
        await lock.start(a.id, ends);
      } else if (!want && triedFor != null) {
        triedFor = null; // 재개하면 다시 시도
        // 재실행 뒤 start가 거절돼도 이전 실행의 잠금이 남아 있을 수 있어 항상 푼다
        await lock.stop();
      }
    } catch (_) {
      // 채널 오류여도 집중은 계속
    }
  });

  // 권한은 설정·강제 종료로 앱 밖에서 꺼질 수 있어 돌아올 때마다 본다
  Future<void> refreshLock() async {
    try {
      final st = await lock.status();
      appState.setLockReady(st.authorized && st.selectedCount > 0);
    } catch (_) {}
  }

  refreshLock(); // 권한 확인이 최대 2초 걸릴 수 있어 앱 시작을 막지 않는다 (그동안 lockReady는 기본값 true)

  // 랭킹: 참여(닉네임 있음)했으면 점수·아바타가 바뀔 때마다 제출. 오프라인이면 다음 변경 때 다시.
  final ranking = RankingService();
  LeagueSync? leagueSync;
  try {
    await RankingService.init();
    String? sent; // 마지막으로 보낸 '닉네임:아바타:점수'
    var retryAt = DateTime(0);
    Future<void> sync() async {
      final name = appState.rankNickname;
      final avatar = appState.selectedCompanion.id;
      final key = '$name:$avatar:${appState.rankScore}';
      if (name == null || key == sent || DateTime.now().isBefore(retryAt)) {
        return;
      }
      sent = key;
      try {
        await ranking.submit(appState.rankScore, name, avatar);
      } catch (_) {
        sent = null; // ponytail: 1분 뒤 다음 변경 알림 때 재시도
        retryAt = DateTime.now().add(const Duration(minutes: 1));
      }
    }

    appState.addListener(sync);
    sync();
    leagueSync = LeagueSync(appState, ranking)..start();
  } catch (_) {}

  try {
    await initKakao(); // 카톡 초대 카드 + 초대 링크로 열렸을 때 받기
  } catch (e) {
    debugPrint('kakao init: $e');
  }

  // 앱으로 돌아오면 잠금 권한과 못 보낸 리그 세션을 다시 본다
  AppLifecycleListener(onResume: () {
    refreshLock();
    sound.recheckEarphones();
    leagueSync?.sync();
  });

  runApp(
      MultiProvider(providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider.value(value: ranking),
      ], child: const MobileApp()));
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scene = context.select((AppState s) => s.scene);
    return MaterialApp(
      title: 'Fokko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(scene),
      builder: (context, child) => _TabletScale(child: child!),
      home: const MobileShell(),
    );
  }
}

/// iPad: 폰 기준(짧은 변 640pt)으로 배치하고 화면에 맞게 통째로 키운다 → 글자·버튼이 비율대로 커짐.
/// 분할 화면 등 좁은 창은 배율 1(폰 그대로).
class _TabletScale extends StatelessWidget {
  const _TabletScale({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final k = (mq.size.shortestSide / MobileSize.tabletBase).clamp(1.0, 1.6);
    if (k == 1.0) return child;
    return FittedBox(
      child: SizedBox.fromSize(
        size: mq.size / k,
        child: MediaQuery(
          data: mq.copyWith(
            size: mq.size / k,
            padding: mq.padding / k,
            viewPadding: mq.viewPadding / k,
            viewInsets: mq.viewInsets / k,
          ),
          child: child,
        ),
      ),
    );
  }
}
