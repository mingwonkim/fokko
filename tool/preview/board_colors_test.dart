// 꾸미기 장면별 그라데이션을 한 장으로 (macOS 전용). CI 대상 아님.
// 실행: flutter test tool/preview/board_colors_test.dart --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/models/collection.dart';

import 'capture_test.dart' show loadFont;

const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

const _sample = [
  Placement('fawn', 1, 1),
  Placement('tree', 3, 0),
  Placement('rabbit', 4, 1),
  Placement('whale', 0, 3),
  Placement('bench', 2, 3),
  Placement('puppy', 4, 3),
  Placement('squirrel', 1, 4),
  Placement('grass', 3, 5),
];

void main() {
  testWidgets('colors', (tester) async {
    await tester.runAsync(loadFont);
    const size = Size(760, 800);
    await tester.binding.setSurfaceSize(size);
    final key = GlobalKey();
    Widget board(String label, Color top, Color bottom) => Column(children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2622))),
          ),
          Container(
            width: 340,
            height: 340,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, bottom]),
            ),
            child: Stack(children: [
              for (final p in [..._sample]..sort((a, b) => a.y.compareTo(b.y)))
                Positioned(
                  left: (p.x * 340 / 6 - 340 / 60).clamp(0.0, 340 - 68.0),
                  top: (p.y * 340 / 6 - 340 / 24).clamp(0.0, 340 - 68.0),
                  width: 68,
                  height: 68,
                  child: Image.asset(itemAsset(p.itemId), fit: BoxFit.contain),
                ),
            ]),
          ),
        ]);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'AppleGothic'),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 18,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final scene in FocusScene.values)
                    board(scene.style.sceneLabel, scene.style.boardTop,
                        scene.style.boardBottom),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump();
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/board-colors.png').writeAsBytesSync(d!.buffer.asUint8List());
    });
    await tester.binding.setSurfaceSize(null);
  });
}
