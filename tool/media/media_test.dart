// 포트폴리오용 스크린샷 2장 + 데모 영상 프레임 생성 (macOS 전용 도구, CI 대상 아님).
// 실제 앱 위젯(MiniWidgetScreen/ExpandedScreen/QuickCaptureOverlay)을 가상 데스크탑 위에
// 오프스크린 렌더링한다. 영상의 타이머 구간은 타임랩스(화면에 표기).
// 실행: flutter test tool/media --dart-define=OUT=<dir> --dart-define=FONTS=<Pretendard otf dir>
// 이후 ffmpeg로 <OUT>/frames/%04d.png → mp4 (timeline.json에 장면 전환 시각 기록)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/features/capture/quick_capture_overlay.dart';
import 'package:focus_one/features/expanded/expanded_screen.dart';
import 'package:focus_one/features/mini/mini_widget_screen.dart';
import 'package:focus_one/services/window_service.dart';
import 'package:focus_one/state/app_state.dart';

const out = String.fromEnvironment('OUT');
const fontDir = String.fromEnvironment('FONTS');
const desk = Size(1280, 720); // 영상 논리 크기 → ×1.5 = 1920×1080
const fps = 30;

/// 실제 파일에 쓰지 않는 저장소
class _NoopStore extends LocalStore {
  @override
  Future<StoreData> load() async => StoreData.empty();
  @override
  Future<bool> save(StoreData data) async => true;
}

/// window_manager 없이 모드만 바꾸는 창 서비스
class _DemoWindow extends WindowService {
  WindowMode _m = WindowMode.expanded;
  WindowMode _before = WindowMode.mini;
  @override
  WindowMode get mode => _m;
  void _set(WindowMode m) {
    _m = m;
    notifyListeners();
  }

  @override
  Future<void> expand() async => _set(WindowMode.expanded);
  @override
  Future<void> collapse() async => _set(WindowMode.mini);
  @override
  Future<void> toggleMode() async =>
      _set(_m == WindowMode.mini ? WindowMode.expanded : WindowMode.mini);
  @override
  Future<void> showCapture() async {
    _before = _m;
    _set(WindowMode.capture);
  }

  @override
  Future<void> closeCapture() async => _set(_before);
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final l = FontLoader(family);
    for (final p in paths) {
      final b = File(p).readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }

  final pretendard = ['Regular', 'Medium', 'SemiBold', 'Bold']
      .map((w) => '$fontDir/Pretendard-$w.otf')
      .toList();
  for (final f in ['Pretendard', 'Roboto', '.AppleSystemUIFont']) {
    await load(f, pretendard);
  }
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await load('MaterialIcons',
      ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

ThemeData _theme(FocusScene s) {
  final t = AppTheme.of(s);
  return t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Pretendard'));
}

/// 창 하나 (macOS식 그림자)
Widget _window(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );

Widget _app(AppState state, _DemoWindow win) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider<WindowService>.value(value: win),
      ],
      child: Consumer<AppState>(
        builder: (_, s, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(s.scene),
          home: child,
        ),
        child: const _Stage(),
      ),
    );

/// 연출 상태 (커서·클릭·단축키 표시·타임랩스 배지)
class _Fx extends ChangeNotifier {
  Offset cursor = const Offset(640, 420);
  double click = 0; // 1 → 0 클릭 링
  bool keycap = false;
  bool timelapse = false;
  int tick = 0; // 프레임 번호 (소리 막대 애니메이션)
  void update() => notifyListeners();
}

final fx = _Fx();

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final win = context.watch<WindowService>();
    final app = context.watch<AppState>();
    final playing = app.isRunning && app.phase == FocusPhase.focus;
    final Widget screen = switch (win.mode) {
      WindowMode.mini => const MiniWidgetScreen(),
      WindowMode.expanded => const ExpandedScreen(),
      WindowMode.capture => SizedBox.fromSize(
          size: WindowSizes.capture,
          child: QuickCaptureOverlay(onClose: win.closeCapture),
        ),
    };
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Pretendard'),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            const Positioned.fill(child: _Wallpaper()),
            const Positioned(left: 72, top: 64, child: _EditorWindow()),
            Positioned(
              right: 56,
              top: 56,
              child: AnimatedSwitcher(
                duration: AppDuration.enter,
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topRight,
                  children: [...prev, if (cur != null) cur],
                ),
                child: KeyedSubtree(key: ValueKey(win.mode), child: _window(screen)),
              ),
            ),
            Positioned.fill(
              child: ListenableBuilder(
                listenable: fx,
                builder: (_, __) => Stack(children: [
                  if (fx.timelapse)
                    const Positioned(top: 24, left: 0, right: 0, child: Center(child: _Badge('타임랩스', icon: Icons.fast_forward_rounded))),
                  // 실제 앱은 집중 중에만 장면 사운드 재생 — 영상엔 소리 대신 표시
                  if (playing)
                    Positioned(right: 56, bottom: 40, child: _SoundPill(scene: app.scene, tick: fx.tick)),
                  if (fx.keycap)
                    const Positioned(
                      bottom: 48,
                      left: 0,
                      right: 0,
                      child: Center(child: _Keycaps()),
                    ),
                  Positioned(
                    left: fx.cursor.dx - 22,
                    top: fx.cursor.dy - 22,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: CustomPaint(painter: _CursorPainter(fx.click)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wallpaper extends StatelessWidget {
  const _Wallpaper();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCE9E2), Color(0xFFE4ECF4), Color(0xFFEDE7F3)],
          ),
        ),
      );
}

/// 뒤에서 하고 있는 "작업" — 일반 문서 창 (특정 제품 모방 없음)
class _EditorWindow extends StatelessWidget {
  const _EditorWindow();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w, [double o = 1]) => Container(
          width: w,
          height: 10,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Color.fromRGBO(30, 40, 50, 0.10 * o),
            borderRadius: BorderRadius.circular(5),
          ),
        );
    return Container(
      width: 700,
      height: 592,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEDEDEA))),
            ),
            child: Row(children: [
              for (final c in const [Color(0xFFE6E6E3), Color(0xFFE6E6E3), Color(0xFFE6E6E3)])
                Container(width: 11, height: 11, margin: const EdgeInsets.only(right: 7), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              const Text('디자인 시안 v2.md', style: TextStyle(fontSize: 12, color: Color(0xFF8A8F94))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('디자인 시안 마무리',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF2A2F33))),
                const SizedBox(height: 24),
                bar(560), bar(520), bar(590), bar(300),
                const SizedBox(height: 18),
                bar(220, 1.6),
                bar(540), bar(570), bar(480), bar(380),
                const SizedBox(height: 18),
                bar(200, 1.6),
                bar(560), bar(420),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 재생 중인 장면 사운드 표시: 스피커 + 이름 + 움직이는 막대
class _SoundPill extends StatelessWidget {
  const _SoundPill({required this.scene, required this.tick});
  final FocusScene scene;
  final int tick;

  @override
  Widget build(BuildContext context) {
    final style = scene.style;
    final name = switch (scene) {
      FocusScene.forest => '숲 소리',
      FocusScene.night => '밤바람 · 뻐꾸기',
      FocusScene.ocean => '파도 소리',
      FocusScene.daily => '카페',
    };
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.volume_up_rounded, size: 20, color: style.accent),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: style.textStrong)),
        const SizedBox(width: 12),
        for (var i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 6 + 12 * (0.5 + 0.5 * math.sin(tick * 0.35 + i * 1.7)).abs(),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: style.ringProgress, borderRadius: BorderRadius.circular(2)),
          ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC1B1D1C),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      );
}

class _Keycaps extends StatelessWidget {
  const _Keycaps();
  @override
  Widget build(BuildContext context) {
    Widget key(String k) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE61B1D1C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [key('Ctrl'), key('Shift'), key('Space'), const SizedBox(width: 10), const _Badge('딴생각 메모')]);
  }
}

/// 일반 화살표 커서 + 클릭 링
class _CursorPainter extends CustomPainter {
  _CursorPainter(this.click);
  final double click;
  @override
  void paint(Canvas canvas, Size size) {
    const tip = Offset(22, 22);
    if (click > 0) {
      canvas.drawCircle(
        tip,
        10 + 14 * (1 - click),
        Paint()..color = Color.fromRGBO(30, 30, 30, 0.25 * click),
      );
    }
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx, tip.dy + 22)
      ..lineTo(tip.dx + 5.5, tip.dy + 17)
      ..lineTo(tip.dx + 9.5, tip.dy + 25.5)
      ..lineTo(tip.dx + 13, tip.dy + 24)
      ..lineTo(tip.dx + 9, tip.dy + 15.8)
      ..lineTo(tip.dx + 16, tip.dy + 15.8)
      ..close();
    canvas.drawShadow(p, Colors.black, 3, false);
    canvas.drawPath(p, Paint()..color = Colors.black);
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CursorPainter old) => old.click != click;
}

Future<void> _png(WidgetTester tester, GlobalKey key, String path, double ratio) =>
    tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(data!.buffer.asUint8List());
    });

/// 데모 데이터: 할 일 3 + 완료 1 + 오늘 세션 2
Future<AppState> _seed(WidgetTester tester) async {
  final state = AppState(_NoopStore());
  state.addTask('디자인 시안 마무리', setAsCurrent: true);
  await tester.pump(const Duration(milliseconds: 1));
  state.addTask('주간 회의 준비');
  await tester.pump(const Duration(milliseconds: 1));
  state.addTask('메일 답장하기');
  await tester.pump(const Duration(milliseconds: 1));
  state.addTask('어제 회의록 정리');
  state.completeTask(state.pendingTasks.last.id);
  state.setDurationMinutes(5);
  for (var i = 0; i < 2; i++) {
    state.startTimer();
    await tester.pump(const Duration(minutes: 5));
    state.skipBreak();
  }
  state.setDurationMinutes(25);
  return state;
}

void main() {
  testWidgets('screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false; // 테스트 기본값은 그림자를 단색 판으로 그림
    final state = await _seed(tester);
    state.startTimer();
    await tester.pump(const Duration(minutes: 6, seconds: 18));

    for (final (name, screen, size) in [
      ('focusone-mini', const MiniWidgetScreen(), WindowSizes.mini),
      ('focusone-panel', const ExpandedScreen(), WindowSizes.expanded),
    ]) {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(Size(size.width + 160, size.height + 160));
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider<WindowService>.value(value: _DemoWindow()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(state.scene),
          home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Pretendard'),
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 40, 56, 72),
                    child: _window(screen),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await _png(tester, key, '$out/$name.png', 3);
    }
    state.dispose();
    debugDisableShadows = true;
  });

  testWidgets('video', (tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false; // 테스트 기본값은 그림자를 단색 판으로 그림
    final state = await _seed(tester);
    final win = _DemoWindow();
    await tester.binding.setSurfaceSize(desk);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: _app(state, win)));
    await tester.pump(const Duration(milliseconds: 400));

    Directory('$out/frames').createSync(recursive: true);
    var n = 0;
    final marks = <String, double>{};
    void mark(String k) => marks[k] = n / fps;

    Future<void> frame({Duration fake = const Duration(microseconds: 33333)}) async {
      fx.tick = n;
      fx.update();
      await tester.pump(fake);
      await _png(tester, key, '$out/frames/${(n++).toString().padLeft(4, '0')}.png', 1.5);
    }

    Future<void> hold(double sec, {Duration? fake}) async {
      for (var i = 0; i < (sec * fps).round(); i++) {
        fx.click = (fx.click - 0.12).clamp(0, 1);
        fx.update();
        await frame(fake: fake ?? const Duration(microseconds: 33333));
      }
    }

    Future<void> moveTo(Offset target, double sec) async {
      final from = fx.cursor;
      final count = (sec * fps).round();
      for (var i = 1; i <= count; i++) {
        final t = Curves.easeInOutCubic.transform(i / count);
        fx.cursor = Offset.lerp(from, target, t)!;
        fx.click = (fx.click - 0.12).clamp(0, 1);
        fx.update();
        await frame();
      }
    }

    Future<void> clickOn(Finder f, {double move = 0.7}) async {
      final c = tester.getCenter(f);
      await moveTo(c, move);
      final g = await tester.startGesture(c);
      fx.click = 1;
      fx.update();
      await frame();
      await frame();
      await g.up();
      await hold(0.15);
    }

    // 1) 확장 패널, 대기
    await hold(0.8);
    // 2) 시작
    await clickOn(find.text('시작'));
    mark('start');
    // 3) 타임랩스 (프레임당 5초 → 25:00 → 19:00)
    fx.timelapse = true;
    final away = fx.cursor + const Offset(-260, 140);
    final from = fx.cursor;
    for (var i = 1; i <= 72; i++) {
      fx.cursor = Offset.lerp(from, away, Curves.easeOut.transform((i / 30).clamp(0, 1)))!;
      fx.update();
      await frame(fake: const Duration(seconds: 5));
    }
    fx.timelapse = false;
    fx.update();
    // 4) 장면 전환: 숲 → 밤 → 바다
    await clickOn(find.text('숲'));
    mark('night');
    await hold(1.1);
    await clickOn(find.text('밤'), move: 0.35);
    mark('ocean');
    await hold(1.1);
    // 5) 미니로 접기
    await clickOn(find.byTooltip('미니 위젯으로'), move: 0.5);
    await moveTo(fx.cursor + const Offset(-380, 260), 0.6);
    await hold(0.5);
    // 6) 단축키 → 생각 메모 → Enter
    fx.keycap = true;
    fx.update();
    await hold(0.3);
    await win.showCapture();
    await hold(0.35);
    const text = '치과 예약 전화하기';
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(find.byType(TextField), text.substring(0, i));
      await hold(0.12);
    }
    await hold(0.35);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    fx.keycap = false;
    fx.update();
    // 7) 미니 위젯으로 복귀, 마무리
    await hold(1.6);
    mark('end');

    File('$out/timeline.json').writeAsStringSync(jsonEncode(marks));
    state.dispose();
    debugDisableShadows = true;
  });
}
