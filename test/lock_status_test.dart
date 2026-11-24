// 잠금을 켜 뒀는데 권한이 꺼지면 '켜짐'으로 보이지 않고, 시작할 때 알려 준다
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focus_one/data/local_store.dart';
import 'package:focus_one/mobile/focus/focus_home.dart';
import 'package:focus_one/state/app_state.dart';

void main() {
  testWidgets('권한이 없으면 켜짐으로 표시하지 않고 시작할 때 안내한다', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fo');
    final st = AppState(LocalStore(File('${dir.path}/d.json')));
    await tester.runAsync(st.init);
    st.setLockEnabled(true);
    const size = Size(402, 874);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: size),
      child: ChangeNotifierProvider.value(
        value: st,
        child: const MaterialApp(home: Scaffold(body: FocusHome())),
      ),
    ));
    await tester.pump();
    expect(find.byTooltip('앱 잠금 켜짐'), findsOneWidget);

    st.setLockReady(false);
    await tester.pump();
    expect(find.byTooltip('앱 잠금 켜짐'), findsNothing);
    expect(find.byTooltip('앱 잠금 꺼짐, 권한을 확인해 주세요'), findsOneWidget);

    await tester.tap(find.text('시작'));
    await tester.pump();
    expect(find.textContaining('앱 잠금이 꺼져 있어요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    final snack = tester.getRect(find.textContaining('앱 잠금이 꺼져 있어요'));
    final memo = tester.getRect(find.text('딴생각 메모'));
    expect(snack.bottom, lessThan(memo.top), reason: '취소·메모 버튼을 가리지 않는다');
    st.stopTimer();
    st.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
