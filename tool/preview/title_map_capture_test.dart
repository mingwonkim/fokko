// 지도 전체를 한 장으로: 칭호별 칸·테두리 확인용 (macOS 전용). CI 대상 아님.
// 실행: flutter test tool/preview/title_map_capture_test.dart --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/growth/growth_tab.dart';
import 'package:focus_one/models/task.dart';
import 'package:focus_one/state/app_state.dart';

import 'capture_test.dart' show loadFont;

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

void main() {
  for (final (name, minutes, scene) in [
    ('forest', 3300, FocusScene.forest),
    ('night', 3300, FocusScene.night),
  ]) {
    testWidgets(name, (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      await tester.runAsync(loadFont);
      final dir = Directory.systemTemp.createTempSync('fo');
      final file = File('${dir.path}/d.json');
      await tester.runAsync(() => LocalStore(file).save(StoreData(
            tasks: const [],
            inbox: const [],
            sessions: [
              FocusSession(
                  id: 's',
                  taskId: '',
                  taskTitle: '',
                  minutes: minutes,
                  endedAt: DateTime.now(),
                  focusedSec: minutes * 60,
                  scene: 'forest',
                  companionId: 'fawn',
                  outcome: SessionOutcome.completed),
            ],
          )));
      final st = AppState(LocalStore(file));
      await tester.runAsync(st.init);
      st.setScene(scene);
      const size = Size(402, 874);
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: const MediaQueryData(size: size),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'AppleGothic'),
                child: Scaffold(
                    backgroundColor: scene.style.cardBg,
                    body: const GrowthTab()),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final list = tester.state<ScrollableState>(find.byType(Scrollable).last);
      for (final y in [-1.0, 0.0, 1200.0, 2400.0, 3400.0, 4400.0]) {
        if (y >= 0) list.position.jumpTo(y);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final d = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/map-$name-${y.toInt()}.png')
              .writeAsBytesSync(d!.buffer.asUint8List());
        });
      }
      await tester.binding.setSurfaceSize(null);
      st.dispose();
    });
  }
}
