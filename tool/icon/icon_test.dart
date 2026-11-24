// 앱 아이콘 렌더 (1024×1024 투명 PNG, macOS Big Sur 그리드: 본체 824 + 여백 100).
// 실제 FocusRing/SceneDialPainter로 그린다. CI 대상 아님.
// 실행: flutter test tool/icon --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/core/scene_decorations.dart';
import 'package:focus_one/features/mini/widgets/focus_ring.dart';

const out = String.fromEnvironment('OUT');
const canvas = 1024.0;
const body = 824.0;

/// 링 아이콘: 장면 바탕 + 굵은 링(75%) + 링 안 장면 그림
Widget ringIcon(FocusScene scene, List<Color> bg) => _body(
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg),
      FocusRing(progress: 0.75, scene: scene, size: 600, stroke: 90, inset: 108),
    );

/// 미니멀: 장면 색 바탕 + 흰 링 + 흰 잎
Widget minimalIcon() => _body(
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5FA882), Color(0xFF246B4B)],
      ),
      SizedBox(
        width: 560,
        height: 560,
        child: Stack(alignment: Alignment.center, children: [
          const SizedBox.expand(child: CircularProgressIndicator(
            value: 0.75,
            strokeWidth: 84,
            strokeCap: StrokeCap.round,
            color: Colors.white,
            backgroundColor: Color(0x40FFFFFF),
          )),
          Transform.translate(
            offset: const Offset(-40, 40),
            child: const Leaf(size: 200, angle: 45, colorA: Colors.white, colorB: Color(0xFFDDF2E5)),
          ),
        ]),
      ),
    );

Widget _body(Gradient g, Widget child) => Center(
      child: Container(
        width: body,
        height: body,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          gradient: g,
          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(body * 0.45)),
          shadows: const [
            BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: child,
      ),
    );

void main() {
  testWidgets('icons', (tester) async {
    debugDisableShadows = false;
    await tester.binding.setSurfaceSize(const Size(canvas, canvas));
    final variants = {
      'A-forest': ringIcon(FocusScene.forest, const [Color(0xFFFFFFFF), Color(0xFFE3F2E8)]),
      'B-night': ringIcon(FocusScene.night, const [Color(0xFF2A2833), Color(0xFF14131A)]),
      'C-ocean': ringIcon(FocusScene.ocean, const [Color(0xFFFFFFFF), Color(0xFFDDEDF7)]),
      'D-minimal': minimalIcon(),
    };
    for (final MapEntry(:key, :value) in variants.entries) {
      final k = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: k, child: SizedBox.expand(child: value)),
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        final b = k.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/icon-$key.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
    debugDisableShadows = true;
  });
}
