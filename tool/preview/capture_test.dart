// 디자인 미리보기 PNG 생성 (macOS 전용: 시스템 AppleGothic 사용). CI 대상 아님.
// 실행: flutter test tool/preview --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/features/expanded/expanded_screen.dart';
import 'package:focus_one/features/mini/mini_widget_screen.dart';
import 'package:focus_one/services/window_service.dart';
import 'package:focus_one/state/app_state.dart';

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

Future<void> loadFont() async {
  final bytes = File('/System/Library/Fonts/Supplemental/AppleGothic.ttf').readAsBytesSync();
  for (final family in ['Roboto', '.AppleSystemUIFont', 'AppleGothic']) {
    final l = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
    await l.load();
  }
  final icons = File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.buffer)))).load();
}

void main() {
  testWidgets('capture', (tester) async {
    await tester.runAsync(loadFont);
    final state = AppState(LocalStore());
    state.addTask('디자인 시안 마무리', setAsCurrent: true);
    state.addTask('주간 회의 준비');
    state.addTask('메일 답장하기');

    Future<void> shot(Widget child, Size size, String name, [String? tapText]) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(Size(size.width + 80, size.height + 80));
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: WindowService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(state.scene).copyWith(
              textTheme: AppTheme.of(state.scene).textTheme.apply(fontFamily: 'AppleGothic')),
          home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'AppleGothic'),
            child: Scaffold(
              backgroundColor: const Color(0xFFDADDE3),
              body: Center(child: RepaintBoundary(key: key, child: Padding(padding: const EdgeInsets.all(40), child: child))),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      if (tapText != null) {
        await tester.tap(find.textContaining(tapText));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    state.addTask('어제 회의록 정리');
    state.completeTask(state.pendingTasks.last.id);
    state.addToInbox('치과 예약 전화하기');
    for (final scene in FocusScene.values) {
      state.setScene(scene);
      state.stopTimer();
      await shot(const MiniWidgetScreen(), WindowSizes.mini, '${scene.name}-mini-idle');
      await shot(const ExpandedScreen(), WindowSizes.expanded, '${scene.name}-expanded-idle');
      state.startTimer();
      await tester.pump(const Duration(minutes: 9));
      await shot(const MiniWidgetScreen(), WindowSizes.mini, '${scene.name}-mini-running');
      await shot(const ExpandedScreen(), WindowSizes.expanded, '${scene.name}-expanded-running');
      state.pauseTimer();
    }
    state.setScene(FocusScene.forest);
    await shot(const ExpandedScreen(), WindowSizes.expanded, 'forest-expanded-inbox', '인박스');
    state.dispose(); // 시각 기준 타이머(1초 틱)를 정리해야 테스트가 끝난다
  });
}
