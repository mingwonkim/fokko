// 칭호 테두리 10단계 · 공유 카드(이미지 캡처) · 승급 보상 시트 렌더 — 예외 0
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/focus/sheets.dart';
import 'package:focus_one/mobile/share/share_card.dart';
import 'package:focus_one/mobile/widgets/title_avatar.dart';
import 'package:focus_one/models/focus_title.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  test('테두리 토큰은 칭호마다 하나', () {
    expect(TitleRings.all.length, FocusTitle.values.length);
  });

  testWidgets('10단계 테두리 아바타', (tester) async {
    for (final scene in FocusScene.values) {
      await tester.pumpWidget(MaterialApp(
        home: Wrap(children: [
          for (final t in FocusTitle.values)
            for (final size in [
              MobileSize.avatarRow,
              MobileSize.avatar,
              MobileSize.avatarLarge
            ])
              TitleAvatar(
                  title: t,
                  asset: 'assets/mobile/companions/fawn.webp',
                  background: scene.style.cardBg,
                  size: size),
          TitleAvatar(
              title: FocusTitle.master, asset: '', background: scene.style.cardBg),
        ]),
      ));
      await tester.pump(const Duration(seconds: 1)); // 회전 프레임
      expect(tester.takeException(), isNull, reason: '$scene');
    }
  });

  testWidgets('공유 카드 3장면 렌더 + PNG 캡처', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final state = AppState(LocalStore(File('${dir.path}/d.json')));
    final key = GlobalKey();
    for (final scene in FocusScene.values) {
      state.setScene(scene);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 335,
              child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: RepaintBoundary(key: key, child: const ShareCard())),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$scene');
    }
    final bytes = await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.lengthInBytes;
    });
    expect(bytes, greaterThan(1000));
    state.dispose();
  });

  testWidgets('승급하면 보상 시트에 승급 블록', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final t0 = DateTime(2026, 11, 4, 9);
    final file = File('${dir.path}/d.json');
    // 30분 세션 시작 → 1시간 뒤 다시 열면 완료로 확정 (씨앗 → 새싹)
    final a = (await tester.runAsync(() async {
      final first = AppState(LocalStore(file));
      await withClock(Clock.fixed(t0), first.init);
      withClock(Clock.fixed(t0), () {
        first.setDurationMinutes(30);
        first.startTimer(allowNoTask: true);
      });
      await first.flush();
      first.dispose();
      final again = AppState(LocalStore(file));
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))), again.init);
      return again;
    }))!;
    expect(a.lastPromotion, FocusTitle.sprout);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: a,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
              onPressed: () => showRewardSheet(ctx), child: const Text('열기')),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('승급! 이제 \'새싹\'예요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    a.dispose();
  });

  testWidgets('연속으로 집중한 날엔 보상 시트 맨 위에 연속 배너', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/d.json');
    final d1 = DateTime(2026, 11, 4, 9);
    final d2 = d1.add(const Duration(days: 1));
    // 이틀 연달아 25분 완료 (앱을 껐다 켜서 복구 경로로 확정)
    final a = (await tester.runAsync(() async {
      Future<AppState> run(DateTime at) async {
        final st = AppState(LocalStore(file));
        await withClock(Clock.fixed(at), st.init);
        withClock(Clock.fixed(at), () {
          st.setDurationMinutes(25);
          st.startTimer(allowNoTask: true);
        });
        await st.flush();
        st.dispose();
        final again = AppState(LocalStore(file));
        await withClock(Clock.fixed(at.add(const Duration(hours: 1))), again.init);
        return again;
      }

      (await run(d1)).dispose();
      return run(d2);
    }))!;
    expect(a.lastStreakExtended, 2);

    await withClock(Clock.fixed(d2.add(const Duration(hours: 1))), () async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: a,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
                onPressed: () => showRewardSheet(ctx), child: const Text('열기')),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    });
    expect(find.text('2일 연속 집중!'), findsOneWidget);
    expect(find.text('연속 2일'), findsNothing, reason: '배너가 있으면 줄 표시는 뺀다');
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    a.dispose();
  });
}
