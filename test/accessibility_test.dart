// 5단계: 폰 새 화면 접근성 — 터치 크기, 눌리는 것의 라벨, 글자 대비
import 'dart:io';

import 'dart:ui' show Tristate;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/focus/focus_home.dart';
import 'package:focus_one/mobile/growth/growth_pages.dart';
import 'package:focus_one/mobile/growth/growth_tab.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  final pages = <String, Widget>{
    '집중 홈': const FocusHome(),
    '성장': const GrowthTab(),
    '목표': const GoalPage(),
    '연속일': const StreakPage(),
  };
  for (final scene in FocusScene.values) {
    for (final entry in pages.entries) {
      testWidgets('${scene.name} ${entry.key}', (tester) async {
        final handle = tester.ensureSemantics();
        final dir = Directory.systemTemp.createTempSync('fo');
        addTearDown(() {
          try {
            dir.deleteSync(recursive: true);
          } on FileSystemException {
            // 임시 폴더
          }
        });
        final st = AppState(LocalStore(File('${dir.path}/d.json')));
        st.setScene(scene);
        await tester.binding.setSurfaceSize(const Size(402, 874));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: st,
          child: MaterialApp(
            theme: AppTheme.of(scene),
            home: Scaffold(
                backgroundColor: scene.style.cardBg,
                body: SafeArea(child: entry.value)),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        // 버튼이라고 읽히면 화면 낭독기로 실제로 눌려야 한다
        final broken = <String>[];
        void visit(SemanticsNode n) {
          final d = n.getSemanticsData();
          if (d.flagsCollection.isButton &&
              d.flagsCollection.isEnabled != Tristate.isFalse &&
              !d.hasAction(SemanticsAction.tap)) {
            broken.add(d.label);
          }
          n.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        visit(tester.getSemantics(find.byType(Scaffold).first));
        expect(broken, isEmpty, reason: '누르기 동작 없는 버튼');
        st.dispose();
        handle.dispose();
      });
    }
  }

  testWidgets('집중 홈 버튼 이름은 한 번만, 원형 버튼도 버튼으로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 임시 폴더
      }
    });
    final st = AppState(LocalStore(File('${dir.path}/d.json')));
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: st,
      child: const MaterialApp(home: Scaffold(body: SafeArea(child: FocusHome()))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    SemanticsData node(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
    for (final label in ['시작', '딴생각 메모', '집중 소리', '앱 잠금']) {
      final d = node(label);
      expect(d.label, label);
      expect(d.flagsCollection.isButton, isTrue, reason: label);
      expect(d.hasAction(SemanticsAction.tap), isTrue, reason: label);
    }
    await tester.tap(find.bySemanticsLabel('시작'));
    await tester.pump();
    expect(st.activeSession, isNotNull);
    st.stopTimer();
    st.dispose();
    handle.dispose();
  });
}
