// lib/main.dart
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'mobile/mobile_main.dart';
import 'models/task.dart';
import 'services/ambient_sound_service.dart';
import 'services/blocker_service.dart';
import 'services/hotkey_service.dart';
import 'services/tray_service.dart';
import 'services/window_service.dart';
import 'state/app_state.dart';

final _hotkeyService = HotkeyService();
final _trayService = TrayService();
final _blockerService = BlockerService();
final _ambientSoundService = AmbientSoundService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 폰은 별도 셸 — 아래 데스크탑 전용 초기화(창·트레이·단축키·알림)를 타지 않는다
  if (Platform.isIOS || Platform.isAndroid) return runMobile();

  // 1. 창 초기화 (미니 위젯, always-on-top, frameless)
  final windowService = WindowService();
  await windowService.initMiniWindow();

  // 2. 데스크탑 알림 초기화
  await localNotifier.setup(appName: 'Fokko');

  // 3. 앱 상태 로드
  final appState = AppState(LocalStore());
  await appState.init();

  // 세션 완료 → 데스크탑 알림 (자동으로 휴식 시작, 차단 해제)
  appState.onSessionComplete = (Task task, int minutes) {
    LocalNotification(
      title: '집중 완료!',
      body: '"${task.title}" $minutes분 집중했어요. 휴식 동안 차단이 풀립니다.',
    ).show();
  };

  // 휴식 종료 → 알림
  appState.onBreakEnd = () {
    LocalNotification(
      title: '휴식 끝',
      body: '다음 집중을 시작할 준비가 됐어요.',
    ).show();
  };

  // 방해 앱/사이트 감지 → 경고 알림
  _blockerService.onViolation = (String target, bool killed) {
    LocalNotification(
      title: killed ? '방해 앱을 닫았어요' : '집중이 흔들리고 있어요',
      body: killed
          ? '"$target" 을(를) 종료했습니다. 다시 집중해볼까요?'
          : '"$target" 이(가) 열려 있어요. 지금 하던 일로 돌아가세요.',
    ).show();
  };

  // 집중 시작/중단에 맞춰 차단 on/off 자동 동기화
  void syncBlocker() {
    if (appState.shouldBlock) {
      _blockerService.start(appState.blockerSettings);
    } else {
      _blockerService.stop();
    }
  }

  appState.addListener(syncBlocker);

  // 집중 중에만 장면(숲/밤/바다) 앰비언트 사운드 루프 재생 (on/off·볼륨 설정 반영)
  void syncAmbientSound() {
    _ambientSoundService.setVolume(appState.soundVolume);
    if (appState.phase == FocusPhase.focus &&
        appState.isRunning &&
        appState.soundEnabled) {
      _ambientSoundService.play(appState.scene);
    } else {
      _ambientSoundService.stop();
    }
  }

  appState.addListener(syncAmbientSound);

  // 4. 트레이 상주 (창 닫기 ≠ 종료, 트레이 메뉴에서만 실제 종료)
  await _trayService.init();
  _trayService.onShowRequested = windowService.bringToFront;
  _trayService.onQuitRequested = () async {
    await _hotkeyService.dispose();
    _blockerService.dispose();
    _ambientSoundService.dispose();
    _trayService.dispose();
    await windowManager.destroy();
  };

  // 5. 전역 단축키 (Ctrl+Shift+Space → 브레인덤프 캡처)
  _hotkeyService.onQuickCapture = windowService.showCapture;
  await _hotkeyService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: windowService),
      ],
      child: const FocusOneApp(),
    ),
  );
}
