// 폰 탭(집중·할 일·기록) 렌더: SE·Pro Max 크기, 3장면, 큰 글자에서 오버플로/예외 0
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/mobile_main.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  for (final (name, size, scale) in [
    ('SE', const Size(375, 667), 1.0),
    ('ProMax', const Size(440, 956), 1.0),
    ('17 큰 글자', const Size(402, 874), 1.3),
  ]) {
    testWidgets('폰 탭 렌더 — $name', (tester) async {
      final dir = Directory.systemTemp.createTempSync('fo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final state = AppState(LocalStore(File('${dir.path}/d.json')));
      state.addTask('디자인 시안 마무리하고 팀에 공유하기', setAsCurrent: true, tagId: 'general');
      state.addTask('운동');
      state.addToInbox('치과 예약');

      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scene in FocusScene.values) {
        state.setScene(scene);
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider.value(value: state, child: const MobileApp()),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$name $scene 집중');
        for (final tab in ['성장', '할 일', '경쟁', '꾸미기', '집중']) {
          await tester.tap(find.text(tab).last);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$name $scene $tab');
        }
      }
      // 풍경 → 보관함·도감·상점 페이지
      await tester.tap(find.text('꾸미기').last);
      await tester.pump();
      for (final page in ['보관함', '도감', '상점']) {
        await tester.ensureVisible(find.text(page).first);
        await tester.tap(find.text(page).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name $page');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      state.dispose();
    });
  }
}
