// 스토어 스크린샷(홍보 문구 + 실제 앱 화면) · 앱 프리뷰 영상 프레임 생성. 로컬 전용, CI 대상 아님.
// 1) flutter test tool/media/seed_test.dart --dart-define=OUT=<seed.json>
// 2) flutter test tool/store --dart-define=SEED=<seed.json> --dart-define=OUT=<dir> --dart-define=FONTS=<dir>
//    FONTS: Pretendard-{Regular,Medium,SemiBold,Bold,ExtraBold}.otf + NotoColorEmoji.ttf
// 3) bash tool/store/encode.sh <dir>  → PNG(알파 제거) · preview.mp4
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/mobile_shell.dart';
import 'package:focus_one/state/app_state.dart';

const seed = String.fromEnvironment('SEED');
const out = String.fromEnvironment('OUT');
const fontDir = String.fromEnvironment('FONTS');

/// 기기: 캔버스 논리 크기 · 배율 · 앱 화면 크기 · 안전 영역
typedef Device = ({String name, Size canvas, double ratio, Size screen, EdgeInsets safe});
const iphone = (
  name: 'iphone',
  canvas: Size(440, 956), // ×3 = 1320×2868 (6.9")
  ratio: 3.0,
  screen: Size(440, 956),
  safe: EdgeInsets.only(top: 62, bottom: 34),
);
const android = (
  name: 'android',
  canvas: Size(360, 640), // ×3 = 1080×1920 (Google Play 9:16)
  ratio: 3.0,
  screen: Size(402, 874),
  safe: EdgeInsets.only(top: 40, bottom: 24),
);
const ipad = (
  name: 'ipad',
  canvas: Size(1032, 1376), // ×2 = 2064×2752 (13")
  ratio: 2.0,
  screen: Size(1032, 1376),
  safe: EdgeInsets.only(top: 24, bottom: 20),
);

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      final b = File('$fontDir/$f').readAsBytesSync();
      l.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await l.load();
  }

  final pretendard = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'].map((w) => 'Pretendard-$w.otf').toList();
  for (final f in [
    'Pretendard',
    'Roboto',
    '.AppleSystemUIFont',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    'FlutterTest'
  ]) {
    await load(f, pretendard);
  }
  await load('Emoji', ['NotoColorEmoji.ttf']);
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.buffer)))).load();
}

ThemeData _theme(FocusScene s) {
  final t = AppTheme.of(s);
  return t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Pretendard', fontFamilyFallback: const ['Emoji']));
}

/// 실제 앱 (mobile_main.dart의 MobileApp과 같은 구성, 폰트만 Pretendard + 이모지 대체)
Widget _app(AppState state, Device d) => ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (_, s, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(s.scene),
          builder: (context, child) {
            // iPad: 앱의 _TabletScale과 같은 배율 (짧은 변 / 640, 최대 1.6)
            final mq = MediaQuery.of(context);
            final k = (mq.size.shortestSide / MobileSize.tabletBase).clamp(1.0, 1.6);
            if (k == 1.0) return child!;
            return FittedBox(
              child: SizedBox.fromSize(
                size: mq.size / k,
                child: MediaQuery(
                  data: mq.copyWith(size: mq.size / k, padding: mq.padding / k, viewPadding: mq.viewPadding / k),
                  child: child!,
                ),
              ),
            );
          },
          home: child,
        ),
        child: const MobileShell(),
      ),
    );

/// 앱 화면을 기기 크기 MediaQuery로 감싼다
Widget _screen(AppState state, Device d) => MediaQuery(
      data: MediaQueryData(
        size: d.screen,
        devicePixelRatio: d.ratio,
        padding: d.safe,
        viewPadding: d.safe,
      ),
      child: SizedBox.fromSize(size: d.screen, child: _app(state, d)),
    );

/// 홍보 컷: 위 문구 + 아래 둥근 화면(기기 테두리)
class _Poster extends StatelessWidget {
  const _Poster({required this.d, required this.scene, required this.title, required this.sub, required this.child});
  final Device d;
  final FocusScene scene;
  final String title, sub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final st = scene.style;
    final tablet = d.name == 'ipad';
    final radius = tablet ? 36.0 : 56.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400), // 영상: 장면이 바뀌면 배경도 천천히
      width: d.canvas.width,
      height: d.canvas.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [st.dialColors.first, st.cardBg],
        ),
      ),
      child: Column(children: [
        SizedBox(height: tablet ? 64 : 70),
        // 영상: 문구가 바뀔 때 교차 페이드
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(key: ValueKey(title), children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: tablet ? 52 : 34,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: st.textStrong)),
            const SizedBox(height: 12),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: tablet ? 24 : 17,
                    fontWeight: FontWeight.w500,
                    color: st.textMuted)),
          ]),
        ),
        SizedBox(height: tablet ? 44 : 32),
        // 남은 높이에 기기 전체가 들어가게 축소
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: tablet ? 56 : 40),
            child: FittedBox(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(radius + 12),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 48, offset: Offset(0, 22))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: SizedBox.fromSize(size: d.screen, child: child),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<void> _png(WidgetTester tester, GlobalKey key, String path, double ratio) => tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(data!.buffer.asUint8List());
    });

/// Image.asset은 실제 IO로 디코딩 → runAsync에서 미리 읽어 둔다
Future<void> _images(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

Future<AppState> _state(WidgetTester tester) async {
  // 시드 사본으로 시작 (저장이 시드를 바꾸지 않게)
  final f = File('$out/state.json');
  File(seed).copySync(f.path);
  final s = AppState(LocalStore(f))..autoBreak = false;
  await tester.runAsync(s.init);
  final tag = s.currentTask?.tagId; // 태그 칩을 지금 할 일과 맞춤
  if (tag != null) s.selectTag(tag);
  return s;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _images(tester);
  await tester.pump(const Duration(milliseconds: 400));
  await _images(tester);
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

void main() {
  for (final d in [iphone, android, ipad]) {
    testWidgets('shots ${d.name}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.runAsync(_loadFonts);
      debugDisableShadows = false;
      tester.view.physicalSize = d.canvas * d.ratio;
      tester.view.devicePixelRatio = d.ratio;
      Directory('$out/${d.name}').createSync(recursive: true);
      final s = await _state(tester);

      final key = GlobalKey();
      var title = '', sub = '';
      Future<void> shot(String name, String t, String sb) async {
        title = t;
        sub = sb;
        // 같은 트리를 다시 그리므로 앱 상태(탭·시트)는 유지된다
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: _Poster(d: d, scene: s.scene, title: title, sub: sub, child: _screen(s, d)),
          ),
        ));
        await _settle(tester);
        await _png(tester, key, '$out/${d.name}/$name.png', d.ratio);
      }

      // 장면 4개를 고르게: 숲 01·06, 바다 02·03, 밤 04·08, 일상 05·07
      // 1) 숲 · 집중 중 (50분 중 18분 경과). 기록 없이 버린다 — 03의 연속 배너가 오늘 첫 완료에 뜨게
      s.setDurationMinutes(50);
      await _settle(tester);
      s.startTimer();
      await tester.pump(const Duration(minutes: 18, seconds: 24));
      await shot('01_focus', '할 일 딱 하나,\n집중한 만큼 차올라요', 'ADHD를 위한 싱글 태스크 집중 타이머');
      s.stopTimer();
      await _settle(tester);

      // 2) 바다 · 집중 중 → 3) 완료 + 연속 집중 배너
      s.setScene(FocusScene.ocean);
      s.setDurationMinutes(25);
      await _settle(tester);
      s.startTimer();
      await tester.pump(const Duration(minutes: 14, seconds: 10));
      await shot('02_ocean', '바다 속으로\n깊이 몰입해요', '물고기 · 기포 · 파도 소리가 함께 차올라요');
      await tester.pump(const Duration(minutes: 11));
      await shot('03_streak', '매일 이어 가면\n친구가 함께 기뻐해요', '연속 집중 배너 · 새 친구 · 물방울 보상');
      await tester.tap(find.byTooltip('닫기').last);
      await _settle(tester);

      // 4) 밤 · 성장 지도  5) 일상 · 퀘스트
      s.setScene(FocusScene.night);
      await _tapTab(tester, '성장');
      await shot('04_growth', '집중할수록\n레벨이 올라요', '칭호마다 색이 바뀌는 성장 지도');
      s.setScene(FocusScene.daily);
      await tester.tap(find.textContaining('퀘스트').first);
      await _settle(tester);
      await shot('05_quests', '오늘의 퀘스트로\n매일 조금씩', '달성하면 상자 속 물방울과 얼음');

      // 6) 숲 · 꾸미기
      s.setScene(FocusScene.forest);
      await _tapTab(tester, '꾸미기');
      await shot('06_scenery', '모은 친구로\n나만의 풍경 꾸미기', '친구 36종, 집중할수록 하나씩 만나요');

      // 7) 일상(카페) · 집중 중 · 앱 잠금
      s.setScene(FocusScene.daily);
      await _tapTab(tester, '집중');
      s.setDurationMinutes(30);
      await _settle(tester);
      s.startTimer();
      await tester.pump(const Duration(minutes: 12, seconds: 41));
      await shot('07_daily', '카페 · 도서관 · 기차,\n어디서든 내 집중 자리', '집중하는 동안 딴 앱은 잠가요');
      await tester.pump(const Duration(minutes: 60));
      await _settle(tester);
      if (find.byTooltip('닫기').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('닫기').last);
        await _settle(tester);
      }

      // 8) 밤 · 경쟁
      s.setScene(FocusScene.night);
      await _tapTab(tester, '경쟁');
      await shot('08_compete', '친구와 겨루며\n함께 자라요', '1:1 대결 · 랭킹 · 연속 기록');

      s.dispose();
      debugDisableShadows = true;
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    });
  }

  // Google Play 그래픽 이미지 1024×500
  testWidgets('feature graphic', (tester) async {
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    Directory('$out/android').createSync(recursive: true);
    final key = GlobalKey();
    const friends = ['fawn', 'rabbit', 'whale', 'puppy'];
    final style = FocusScene.forest.style;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.boardTop, style.boardBottom],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fokko',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 76,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: style.textStrong)),
                  const SizedBox(height: 8),
                  Text('할 일 딱 하나,\n집중한 만큼 자라요',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 36,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: style.textStrong)),
                ],
              ),
            ),
            SizedBox(
              width: 440,
              child: Wrap(alignment: WrapAlignment.center, children: [
                for (final f in friends)
                  Image.asset('assets/mobile/companions/$f.webp',
                      width: 200, height: 200),
              ]),
            ),
          ]),
        ),
      ),
    ));
    await _images(tester);
    await tester.pump();
    await _png(tester, key, '$out/android/feature_graphic.png', 1);
    debugDisableShadows = true;
    tester.view.reset();
  });

  // 앱 프리뷰: 886×1920 · 30fps. 장면 전환 시각은 timeline.json (소리 입히기용)
  // 기기 테두리·배경 없이 앱 화면만 꽉 채운다 (1.0.1 거절 2.3.4: 프리뷰에 테두리 금지). 문구는 상태바 자리에 덧씌움.
  testWidgets('video', (tester) async {
    const d = (
      name: 'video',
      canvas: Size(443, 960),
      ratio: 2.0,
      screen: Size(443, 960),
      safe: EdgeInsets.only(top: 62, bottom: 34),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.runAsync(_loadFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = d.canvas * d.ratio;
    tester.view.devicePixelRatio = d.ratio;
    final dir = Directory('$out/video/frames')..createSync(recursive: true);
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    final s = await _state(tester);
    const fps = 30;
    final key = GlobalKey();
    var title = '';
    var n = 0;
    final marks = <String, double>{};
    void mark(String k) => marks[k] = n / fps;

    Widget tree() => Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Stack(children: [
              _screen(s, d),
              Positioned(left: 0, right: 0, top: 0, height: d.safe.top, child: _Caption(scene: s.scene, text: title)),
            ]),
          ),
        );

    Future<void> frame([Duration step = const Duration(microseconds: 33333)]) async {
      await tester.pumpWidget(tree());
      await tester.pump(step);
      await _png(tester, key, '${dir.path}/${(n++).toString().padLeft(4, '0')}.png', d.ratio);
    }

    Future<void> hold(double sec) async {
      for (var i = 0; i < (sec * fps).round(); i++) {
        await frame();
      }
    }

    void say(String t, String _) => title = t.replaceAll('\n', ' ');

    Future<void> tap(Finder f) async {
      await tester.tap(f);
      await frame();
      await _images(tester);
    }

    // 1) 할 일 하나 · 링 돌려 시간 정하기 (25 → 50분)
    say('할 일 딱 하나만 고르고', '링을 돌려 집중할 시간을 정해요');
    await tester.pumpWidget(tree());
    await _settle(tester);
    mark('forest');
    await hold(1.2);
    for (var m = 30; m <= 50; m += 5) {
      s.setDurationMinutes(m);
      await hold(0.25);
    }
    await hold(0.6);

    // 2) 시작 → 타임랩스 (50분을 5초에)
    say('시작하면 딴 앱은 잠겨요', '집중하는 동안 SNS는 잠시 멀리');
    s.startTimer();
    await hold(1.6);
    say('집중할수록 친구가 선명해져요', '50분 타임랩스');
    for (var i = 0; i < 150; i++) {
      await frame(const Duration(seconds: 20));
    }
    await _images(tester);

    // 3) 완료 보상
    say('끝까지 해내면\n새 친구가 찾아와요', '모은 물방울로 풍경을 꾸며요');
    await hold(2.6);
    await tap(find.byTooltip('닫기').last);
    await hold(0.5);

    // 4) 장면: 숲 → 밤 → 바다
    say('숲 · 밤 · 바다', '장면마다 다른 소리로 몰입');
    for (final sc in [FocusScene.night, FocusScene.ocean]) {
      s.setScene(sc);
      mark(sc.name);
      await frame();
      await _images(tester);
      await hold(1.3);
    }
    s.setScene(FocusScene.forest);
    mark('forest2');

    // 5) 성장 지도 · 꾸미기
    say('집중할수록\n레벨이 올라요', '칭호마다 색이 바뀌는 성장 지도');
    await tap(find.text('성장').last);
    await hold(2.4);
    say('모은 친구로\n나만의 풍경 꾸미기', '친구 36종, 집중할수록 하나씩 만나요');
    await tap(find.text('꾸미기').last);
    await hold(2.2);

    // 6) 기록 (천천히 스크롤)
    say('집중한 시간이\n한눈에 쌓여요', '연속 기록 · 태그별 시간 · 골든타임');
    await tap(find.text('경쟁').last);
    await hold(0.8);
    // 터치 인식 임계값(18px)을 넘겨야 스크롤이 시작된다 → 한 제스처로 이어서 끌기
    final g = await tester.startGesture(tester.getCenter(find.byType(Scrollable).first));
    for (var i = 0; i < 40; i++) {
      await g.moveBy(const Offset(0, -10));
      await frame();
    }
    await g.up();
    await hold(1.0);

    mark('end');

    File('$out/video/timeline.json').writeAsStringSync(jsonEncode(marks));
    s.dispose();
    debugDisableShadows = true;
    debugDefaultTargetPlatformOverride = null;
    tester.view.reset();
  });
}

/// 영상 문구: 상태바 자리(앱이 비워 두는 위쪽 안전 영역)에 한 줄
class _Caption extends StatelessWidget {
  const _Caption({required this.scene, required this.text});
  final FocusScene scene;
  final String text;

  @override
  Widget build(BuildContext context) {
    final st = scene.style;
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(text,
            key: ValueKey(text),
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: st.textStrong)),
      ),
    );
  }
}
