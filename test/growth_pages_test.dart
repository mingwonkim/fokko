// 목표·연속일 화면: 작은 폰·큰 글자에서 넘침 없고, 누르면 목표가 바뀐다
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/growth/growth_pages.dart';
import 'package:focus_one/models/growth.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  for (final (name, size, scale) in [
    ('SE', const Size(375, 667), 1.0),
    ('큰 글자', const Size(375, 667), 2.0),
  ]) {
    for (final scene in FocusScene.values) {
      testWidgets('$name ${scene.name} 렌더', (tester) async {
        final dir = Directory.systemTemp.createTempSync('fo');
        addTearDown(() => dir.deleteSync(recursive: true));
        final state = AppState(LocalStore(File('${dir.path}/d.json')));
        state.setScene(scene);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final page in const [GoalPage(), StreakPage()]) {
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: ChangeNotifierProvider.value(
                value: state, child: MaterialApp(home: page)),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        state.dispose();
      });
    }
  }

  testWidgets('+ 누르면 일일 목표가 바로 오르고, − 는 내일부터', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(LocalStore(File('${dir.path}/d.json')));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state, child: const MaterialApp(home: GoalPage())));
    await tester.tap(find.byTooltip('일일 목표 5분 늘리기'));
    await tester.pump();
    expect(state.dailyGoal, Growth.dailyDefault + 5);
    await tester.tap(find.byTooltip('일일 목표 5분 줄이기'));
    await tester.pump();
    await tester.tap(find.byTooltip('일일 목표 5분 줄이기'));
    await tester.pump();
    expect(state.dailyGoal, Growth.dailyDefault + 5, reason: '낮춘 값은 오늘 적용 안 됨');
    expect(find.text('내일부터 적용'), findsOneWidget);
    state.dispose();
  });
}
