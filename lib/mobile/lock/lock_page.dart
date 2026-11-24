// lib/mobile/lock/lock_page.dart
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../services/focus_lock_service.dart';
import '../../state/app_state.dart';
import '../focus/sheets.dart' show showFocusSheet;
import '../adaptive.dart';

/// 앱 잠금: 처음엔 안내·동의 → OS 권한 → 앱 선택, 그다음부턴 설정(켜기·잠글 앱).
/// Android 접근성은 Play 정책상 사용 목적·수집 범위를 먼저 고지하고 동의를 받는다.
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> with WidgetsBindingObserver {
  final _lock = FocusLockService();
  bool _authorized = false;
  int _selected = 0;
  bool _loading = true;
  bool _waitingSettings = false; // Android: 설정 화면에서 돌아오기를 기다림

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _refresh(afterSettings: _waitingSettings);
    }
  }

  Future<void> _refresh({bool afterSettings = false}) async {
    try {
      final st = await _lock.status();
      if (!mounted) return;
      setState(() {
        _authorized = st.authorized;
        _selected = st.selectedCount;
        _loading = false;
      });
      context.read<AppState>()
          .setLockReady(st.authorized && st.selectedCount > 0);
      if (afterSettings && st.authorized) {
        _waitingSettings = false;
        await _pick();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _turnOn() async {
    if (Platform.isAndroid) {
      _waitingSettings = true;
      await _lock.authorize(); // 설정 화면 → 돌아오면 _refresh
      return;
    }
    if (await _lock.authorize()) {
      await _refresh();
      await _pick();
    }
  }

  Future<void> _pick() async {
    final n = Platform.isIOS ? await _lock.pickAppsIOS() : await _pickAndroid();
    if (!mounted) return;
    setState(() => _selected = n);
    final s = context.read<AppState>();
    if (n > 0) s.setLockEnabled(true);
    s.setLockReady(_authorized && n > 0);
  }

  Future<int> _pickAndroid() async {
    final apps = await _lock.listApps();
    final chosen = await _lock.selection();
    if (!mounted) return chosen.length;
    await showFocusSheet(context, '잠글 앱', (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        final style = context.read<AppState>().scene.style;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: MobileSize.gutter),
              children: [
                for (final a in apps)
                  CheckboxListTile(
                    value: chosen.contains(a.package),
                    title: Text(a.label,
                        style: TextStyle(color: style.textStrong)),
                    activeColor: style.accent,
                    onChanged: (v) => set(() => v == true
                        ? chosen.add(a.package)
                        : chosen.remove(a.package)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MobileSize.gutter),
            child: PillButton(
              style: style,
              width: double.infinity,
              height: MobileSize.cta,
              icon: Icons.check_rounded,
              label: '${chosen.length}개 저장',
              onTap: () => Navigator.pop(ctx),
            ),
          ),
        ]);
      });
    });
    return _lock.setSelection(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final ready = s.lockEnabled && _authorized && _selected > 0;
    return Scaffold(
      backgroundColor: style.cardBg,
      appBar: AppBar(
        backgroundColor: style.cardBg,
        foregroundColor: style.textStrong,
        surfaceTintColor: Colors.transparent,
        title: const Text('앱 잠금',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: MaxWidth(
                child: (_authorized && _selected > 0)
                    ? _settings(s, style, ready)
                    : _intro(style),
              ),
            ),
    );
  }

  Widget _row(SceneStyle style, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: style.rowBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: style.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 15, height: 1.4, color: style.textStrong)),
            ),
          ),
        ]),
      );

  Widget _intro(SceneStyle style) => ListView(
        padding: const EdgeInsets.fromLTRB(
            MobileSize.gutter, 8, MobileSize.gutter, 24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: style.rowBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadow.card(style.rowShadow),
              ),
              child:
                  Icon(Icons.lock_rounded, size: 40, color: style.ringProgress),
            ),
          ),
          const SizedBox(height: 20),
          Text('딴짓 앱은 잠시 닫아둘까요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: style.textStrong)),
          const SizedBox(height: 8),
          Text('지금 할 일 하나에만 머물 수 있게, 고른 앱만 집중하는 동안 막아요.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, height: 1.4, color: style.textMuted)),
          const SizedBox(height: 28),
          _row(style, Icons.timer_outlined, '집중하는 동안만 잠기고, 끝나면 바로 풀려요.'),
          if (Platform.isIOS)
            _row(style, Icons.hourglass_bottom_rounded,
                '15분 이상 집중할 때 잠겨요.'),
          _row(style, Icons.call_outlined, '전화·문자 같은 기본 앱은 그대로 쓸 수 있어요.'),
          if (Platform.isAndroid)
            _row(style, Icons.visibility_off_outlined,
                '접근성 권한으로 지금 열린 앱 이름만 확인해요. 화면 내용은 읽지도 저장하지도 않고, 어디로도 보내지 않아요.'),
          const SizedBox(height: 20),
          PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.lock_outline_rounded,
            label: Platform.isAndroid ? '동의하고 설정 열기' : '계속',
            onTap: _authorized ? _pick : _turnOn,
          ),
          // iOS 심사 5.1.1(iv): 권한 안내 뒤엔 바로 권한 요청으로 가야 해서 미루기 버튼을 두지 않는다
          if (Platform.isAndroid)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('나중에', style: TextStyle(color: style.textMuted)),
            ),
        ],
      );

  Widget _settings(AppState s, SceneStyle style, bool ready) => ListView(
        padding: const EdgeInsets.all(MobileSize.gutter),
        children: [
          Container(
            decoration: BoxDecoration(
              color: style.rowBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.card(style.rowShadow),
            ),
            child: Column(children: [
              SwitchListTile(
                value: s.lockEnabled,
                activeTrackColor: style.ringProgress,
                title: Text('집중 중 앱 잠금',
                    style: TextStyle(color: style.textStrong)),
                onChanged: s.setLockEnabled,
              ),
              Divider(height: 1, color: style.divider),
              ListTile(
                title: Text('잠글 앱', style: TextStyle(color: style.textStrong)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('$_selected개', style: TextStyle(color: style.textMuted)),
                  Icon(Icons.chevron_right_rounded, color: style.textMuted),
                ]),
                onTap: _pick,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            Platform.isIOS
                ? '15분 이상 집중할 때 잠기고, 끝나면 바로 풀려요.'
                : '집중하는 동안 고른 앱을 열면 Fokko로 돌아와요. 끝나면 풀려요.',
            style: TextStyle(fontSize: 13, height: 1.4, color: style.textMuted),
          ),
        ],
      );
}
