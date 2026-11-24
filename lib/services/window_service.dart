// lib/services/window_service.dart
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../core/design_tokens.dart';

enum WindowMode { mini, expanded, capture }

/// 미니 위젯 ↔ 확장 패널 창 전환 담당.
/// 창 크기/위치 로직은 전부 여기로 모은다 (화면 위젯에서 직접 조작 금지).
class WindowService extends ChangeNotifier {
  WindowMode _mode = WindowMode.mini;
  WindowMode get mode => _mode;

  Future<void> initMiniWindow() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: WindowSizes.mini,
      backgroundColor: null, // 투명 배경은 main에서 별도 설정
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      // 첫 실행: 화면 우상단 근처에 배치
      await windowManager.setAlignment(Alignment.topRight);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Future<void> toggleMode() async {
    if (_mode == WindowMode.mini) {
      await expand();
    } else {
      await collapse();
    }
  }

  Future<void> expand() async {
    _mode = WindowMode.expanded;
    notifyListeners();
    await windowManager.setSize(WindowSizes.expanded, animate: true);
  }

  Future<void> collapse() async {
    _mode = WindowMode.mini;
    notifyListeners();
    await windowManager.setSize(WindowSizes.mini, animate: true);
  }

  WindowMode _modeBeforeCapture = WindowMode.mini;

  /// 전역 단축키로 호출: 캡처 모드로 전환 + 창을 앞으로
  Future<void> showCapture() async {
    if (_mode != WindowMode.capture) {
      _modeBeforeCapture = _mode;
    }
    _mode = WindowMode.capture;
    notifyListeners();
    await windowManager.setSize(WindowSizes.capture, animate: true);
    await windowManager.show();
    await windowManager.focus();
  }

  /// 캡처 종료: 이전 모드로 복귀
  Future<void> closeCapture() async {
    _mode = _modeBeforeCapture;
    notifyListeners();
    final size = _mode == WindowMode.expanded
        ? WindowSizes.expanded
        : WindowSizes.mini;
    await windowManager.setSize(size, animate: true);
  }

  /// 창을 앞으로 가져오고 포커스
  Future<void> bringToFront() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }
}
