// v3 1차안 미리보기: 집중 차오름 4장면 × 진행률 + 대기 화면 (macOS 전용: AppleGothic). CI 대상 아님.
// 실행: flutter test tool/preview/fill_capture_test.dart --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/mobile_shell.dart';
import 'package:focus_one/state/app_state.dart';

import 'capture_test.dart' show loadFont;

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

void main() {
  testWidgets('fill capture', (tester) async {
    await tester.runAsync(loadFont);
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(LocalStore(File('${dir.path}/d.json')));
    state.addTask('디자인 시안 마무리하기', setAsCurrent: true);

    Future<void> shot(Size size, String name) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.of(state.scene).copyWith(
              textTheme: AppTheme.of(state.scene)
                  .textTheme
                  .apply(fontFamily: 'AppleGothic')),
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: MediaQueryData(
                  size: size,
                  padding: size.height < 700
                      ? const EdgeInsets.only(top: 20)
                      : const EdgeInsets.only(top: 59, bottom: 34)),
              child: DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'AppleGothic'),
                  child: const MobileShell()),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      // 친구 그림 디코딩 대기 (안 기다리면 첫 장면 그림이 비어 찍힌다)
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1.5);
        final d = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
      });
    }

    const phone = Size(402, 874);
    for (final scene in FocusScene.values) {
      state.setScene(scene);
      state.setDurationMinutes(20);
      await shot(phone, '${scene.name}-0-idle');
      state.startTimer(allowNoTask: true);
      var at = 0;
      for (final m in [5, 10, 15, 19]) {
        await tester.pump(Duration(minutes: m - at));
        at = m;
        await shot(phone, '${scene.name}-$m');
      }
      state.stopTimer();
      // 타임랩스 GIF용 프레임 (1분마다)
      state.startTimer(allowNoTask: true);
      for (var i = 0; i < 19; i++) {
        await tester.pump(const Duration(minutes: 1));
        await shot(phone, 'gif-${scene.name}-${i.toString().padLeft(2, '0')}');
      }
      state.stopTimer();
    }
    state.setScene(FocusScene.ocean);
    await shot(const Size(375, 667), 'ocean-se-idle');
    state.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
