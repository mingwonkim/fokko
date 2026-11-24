// lib/mobile/share/share_card.dart
// 자랑하기: 칭호 테두리 아바타 + 닉네임 + 이번 주/누적 집중을 4:5 카드 이미지로 만들어 공유 시트로.
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../state/app_state.dart';
import '../../state/stats.dart';
import '../focus/sheets.dart' show showFocusSheet;
import '../widgets/title_avatar.dart';

String hm(int minutes) => minutes >= 60
    ? '${minutes ~/ 60}시간${minutes % 60 == 0 ? '' : ' ${minutes % 60}분'}'
    : '$minutes분';

/// 이번 주(월요일부터) 실집중 분
int weekMinutes(AppState s, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return FocusStats(s.sessions).range(monday, 7).fold(0, (a, b) => a + b) ~/
      60;
}

Future<void> showShareSheet(BuildContext context) {
  final key = GlobalKey();
  return showFocusSheet(context, '자랑하기', (ctx) {
    final style = ctx.read<AppState>().scene.style;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MobileSize.gutter, 0, MobileSize.gutter, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: RepaintBoundary(key: key, child: const ShareCard()),
          ),
        ),
        const SizedBox(height: MobileSize.sectionGap - 8),
        Builder(
          builder: (btn) => PillButton(
            style: style,
            width: double.infinity,
            height: MobileSize.cta,
            icon: Icons.ios_share_rounded,
            label: '공유하기',
            onTap: () => _share(key, btn),
          ),
        ),
      ]),
    );
  });
}

Future<void> _share(GlobalKey key, BuildContext button) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final box = button.findRenderObject() as RenderBox?;
  final origin =
      box == null ? null : box.localToGlobal(Offset.zero) & box.size; // iPad
  HapticFeedback.lightImpact();
  final image = await boundary.toImage(pixelRatio: 3);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) return;
  await SharePlus.instance.share(ShareParams(
    files: [
      XFile.fromData(png.buffer.asUint8List(),
          mimeType: 'image/png', name: 'focusone.png')
    ],
    sharePositionOrigin: origin,
  ));
}

/// 공유 이미지 본체 (부모가 4:5 크기를 준다). 글자 크기는 카드 폭 비례.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final title = s.title;
    final total = s.focusMinutesTotal;
    final week = weekMinutes(s, DateTime.now());
    return LayoutBuilder(builder: (context, c) {
      final u = c.maxWidth / 100; // 카드 폭의 1%
      TextStyle t(double size, {FontWeight w = FontWeight.w500, Color? color}) =>
          TextStyle(
              fontSize: size * u,
              fontWeight: w,
              color: color ?? style.textStrong,
              height: 1.25);
      Widget stat(String label, String value) => Expanded(
            child: Column(children: [
              Text(label, style: t(4, color: style.textMuted)),
              SizedBox(height: u),
              Text(value, style: t(6.5, w: FontWeight.w700)),
            ]),
          );
      return MediaQuery.withNoTextScaling(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: style.dialColors,
                stops: style.dialStops,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(8 * u),
              child: Column(children: [
                const Spacer(),
                TitleAvatar(
                  title: title,
                  asset: s.selectedCompanion.asset,
                  background: style.rowBg,
                  size: 40 * u,
                ),
                SizedBox(height: 5 * u),
                Text(s.rankNickname ?? '나', style: t(6, w: FontWeight.w600)),
                SizedBox(height: u),
                Text(title.label,
                    style: t(10, w: FontWeight.w800, color: style.accent)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4 * u),
                  decoration: BoxDecoration(
                    color: style.rowBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(children: [
                    stat('이번 주 집중', hm(week)),
                    stat('누적 집중', hm(total)),
                  ]),
                ),
                SizedBox(height: 5 * u),
                Text('FocusOne', style: t(4.5, w: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
