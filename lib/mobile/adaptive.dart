// lib/mobile/adaptive.dart
// iPad 대응: 폰은 그대로, 넓은 화면은 가운데 최대 폭
import 'package:material_ui/material_ui.dart';

import '../core/design_tokens.dart';

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= MobileSize.tabletBreak;

class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, this.max = MobileSize.listMaxWidth, required this.child});
  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: max),
          child: child,
        ),
      );
}
