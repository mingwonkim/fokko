// lib/features/expanded/widgets/blocker_settings_view.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../state/app_state.dart';

/// 차단 설정 탭.
/// 집중 세션 중에만 차단이 켜지고, 휴식/대기 중에는 자동으로 풀린다.
class BlockerSettingsView extends StatelessWidget {
  const BlockerSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final settings = state.blockerSettings;

    // 패널 자체에 24px 패딩이 있으므로 여기선 세로 여백만 (가로 공간 확보)
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('집중 중 차단 사용',
              style: Theme.of(context).textTheme.bodyMedium),
          subtitle: Text(
            '집중 세션 동안만 감지 · 휴식 시간엔 자동 해제',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value: settings.enabled,
          onChanged: state.setBlockerEnabled,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('감지 시 앱 강제 종료',
              style: Theme.of(context).textTheme.bodyMedium),
          subtitle: Text(
            '끄면 경고 알림만 표시',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value: settings.autoKill,
          onChanged: settings.enabled ? state.setBlockerAutoKill : null,
        ),
        const SizedBox(height: AppSpacing.md),
        _BlockItemSection(
          title: '차단할 앱',
          hint: '프로세스 이름 일부 (예: discord)',
          items: settings.apps,
          onAdd: state.addBlockedApp,
          onRemove: state.removeBlockedApp,
        ),
        const SizedBox(height: AppSpacing.lg),
        _BlockItemSection(
          title: '차단할 사이트',
          hint: '탭 제목 키워드 (예: YouTube)',
          items: settings.sites,
          onAdd: state.addBlockedSite,
          onRemove: state.removeBlockedSite,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '사이트 감지는 브라우저 창 제목 기반의 소프트 차단이에요. '
          '완전 차단(hosts/확장 프로그램)은 다음 단계에서 추가됩니다.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _BlockItemSection extends StatefulWidget {
  const _BlockItemSection({
    required this.title,
    required this.hint,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final List<String> items;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  @override
  State<_BlockItemSection> createState() => _BlockItemSectionState();
}

class _BlockItemSectionState extends State<_BlockItemSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onAdd(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _submit,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.items.isEmpty)
          Text(
            '아직 없음',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: widget.items
                .map((item) => Chip(
                      label: Text(item,
                          style: Theme.of(context).textTheme.bodySmall),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => widget.onRemove(item),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
      ],
    );
  }
}
