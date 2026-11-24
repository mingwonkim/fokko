// lib/features/expanded/widgets/inbox_list.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../state/app_state.dart';

/// 브레인덤프 인박스.
/// 여기 있는 항목은 "아직 할 일이 아님". 사용자가 승격해야만 할 일이 된다.
class InboxList extends StatelessWidget {
  const InboxList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final style = state.scene.style;

    if (state.inbox.isEmpty) {
      return Center(
        child: Text(
          '작업 중 떠오른 생각은\nCtrl+Shift+Space로 여기에 쌓여요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: style.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.inbox.length,
      itemBuilder: (context, index) {
        final item = state.inbox[index];
        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: BoxDecoration(
            color: style.rowBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(style.rowShadow),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: style.textStrong),
                ),
              ),
              IconButton(
                tooltip: '할 일로 올리기',
                icon: Icon(Icons.arrow_upward_rounded,
                    size: 18, color: style.accent),
                onPressed: () => state.promoteInboxItem(item.id),
              ),
              IconButton(
                tooltip: '버리기',
                icon: Icon(Icons.close_rounded,
                    size: 18, color: style.textFaint),
                onPressed: () => state.deleteInboxItem(item.id),
              ),
            ],
          ),
        );
      },
    );
  }
}
