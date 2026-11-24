// 차오름 높이: 시작은 화면 아래, 끝은 화면 위까지 빈틈 없이
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/mobile/focus/scene_fill.dart';

void main() {
  test('수면 위치', () {
    const h = 800.0;
    expect(fillSurfaceY(h, 0, overshoot: 20), h, reason: '시작은 바닥에서');
    expect(fillSurfaceY(h, 1, overshoot: 20), -20);
    expect(fillSurfaceY(h, 0.5), 400);
    expect(fillSurfaceY(h, 2), 0); // 범위 밖은 자른다
  });

  for (final scene in FocusScene.values) {
    testWidgets('${scene.name} 진행도별 그리기 예외 없음', (tester) async {
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: SceneFill(scene: scene, progress: p),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('앱이 안 보이면 다시 그리지 않고, 돌아오면 다시 움직인다', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SceneFill(scene: FocusScene.ocean, progress: 0.5),
    ));
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue, reason: '보일 땐 움직인다');
    await tester.pump();
    // paused면 프레임 자체가 꺼져 검사가 안 되므로 프레임이 살아 있는 inactive로 본다
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.binding.delayed(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '안 보이면 멈춘다');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue, reason: '돌아오면 다시');
    await tester.pumpWidget(const SizedBox());
  });

  group('10분 타이머 기준', () {
    const size = Size(100, 874);
    Future<ByteData> render(FocusScene scene, double p) async {
      final recorder = ui.PictureRecorder();
      SceneFillPainter(
              scene: scene, progress: p, time: ValueNotifier<double>(1.5))
          .paint(Canvas(recorder), size);
      final image = await recorder.endRecording().toImage(100, 874);
      return (await image.toByteData())!;
    }

    int alpha(ByteData d, int x, int y) => d.getUint8((y * 100 + x) * 4 + 3);
    bool anyPainted(ByteData d, int y) =>
        [for (var x = 0; x < 100; x += 5) alpha(d, x, y)].any((a) => a > 0);
    bool allPainted(ByteData d, int y) =>
        [for (var x = 0; x < 100; x += 5) alpha(d, x, y)].every((a) => a > 0);

    for (final scene in [FocusScene.ocean, FocusScene.daily, FocusScene.forest]) {
      test('\${scene.name}: 10초 만에 바닥에 보인다', () async {
        expect(anyPainted(await render(scene, 10 / 600), 873), isTrue);
      });
      test('\${scene.name}: 끝나야 맨 위까지 차고, 1분 전엔 아직 아니다', () async {
        expect(allPainted(await render(scene, 1), 0), isTrue);
        expect(allPainted(await render(scene, 0.9), 40), isFalse);
      });
    }
  });

  test('한 프레임 그리기 비용 (전력 대리 지표)', () {
    const size = Size(402, 874);
    for (final scene in FocusScene.values) {
      final time = ValueNotifier<double>(1.5);
      final painter =
          SceneFillPainter(scene: scene, progress: 1, time: time);
      final watch = Stopwatch()..start();
      const frames = 240;
      for (var i = 0; i < frames; i++) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }
      watch.stop();
      final ms = watch.elapsedMicroseconds / 1000 / frames;
      // ignore: avoid_print
      print('fill ${scene.name}: ${ms.toStringAsFixed(3)} ms/frame');
      expect(ms, lessThan(FillMotion.frame.inMilliseconds / 2));
      time.dispose();
    }
  });

  testWidgets('동작 줄이기면 움직임 타이머를 돌리지 않는다', (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SceneFill(scene: FocusScene.ocean, progress: 0.5),
      ),
    ));
    await tester.pump();
    await tester.binding.delayed(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
