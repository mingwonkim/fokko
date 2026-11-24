// test/scene_render_test.dart
// 세 장면(숲/밤/바다)에서 미니 위젯·확장 패널이 오버플로/페인트 예외 없이 렌더링되는지 확인.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/core/app_theme.dart';
import 'package:focus_one/core/design_tokens.dart';
import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/features/expanded/expanded_screen.dart';
import 'package:focus_one/features/mini/mini_widget_screen.dart';
import 'package:focus_one/services/window_service.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  Widget host(AppState state, FocusScene scene, Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: WindowService()),
        ],
        child: MaterialApp(
          theme: AppTheme.of(scene),
          home: Scaffold(
            backgroundColor: Colors.grey,
            body: Center(child: child),
          ),
        ),
      );

  testWidgets('세 장면 모두 미니/확장 화면 렌더링', (tester) async {
    final state = AppState(LocalStore());
    state.addTask('디자인 시안 마무리', setAsCurrent: true);
    state.addTask('주간 회의 준비');

    for (final scene in FocusScene.values) {
      state.setScene(scene);

      await tester.pumpWidget(host(state, scene, const MiniWidgetScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$scene mini');
      expect(find.text('지금 집중할 일'), findsOneWidget);

      await tester.pumpWidget(host(state, scene, const ExpandedScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$scene expanded');
      expect(find.text('Fokko'), findsOneWidget);
      expect(find.text(scene.style.sceneLabel), findsOneWidget);
      expect(find.text('오늘의 작업'), findsOneWidget);
      expect(find.textContaining(scene.style.footerLabel), findsOneWidget);

      // 차단·인박스 뷰: 큰 다이얼이 소형 타이머 줄로 접히고 내용이 렌더링돼야 함
      await tester.tap(find.text('차단'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$scene blocker');
      expect(find.text('집중 중 차단 사용'), findsOneWidget);

      await tester.tap(find.textContaining('인박스'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$scene inbox');
    }
  });
}
