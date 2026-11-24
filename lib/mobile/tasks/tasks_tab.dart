// lib/mobile/tasks/tasks_tab.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/scene_decorations.dart';
import '../../models/task.dart';
import '../../state/app_state.dart';
import '../focus/sheets.dart';
import '../mobile_shell.dart';

/// 할 일 탭 (spec §2): 태그별 접는 섹션 → 행64(체크·제목2줄·바로 집중) → 추가 / 인박스 / 완료 접힘
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final _collapsed = <String>{};
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final style = s.scene.style;
    final tagIds = {for (final t in s.tags) t.id};
    final sections = [
      for (final t in s.tags) (t.id, t.name, t.colorIndex),
      if (s.pendingTasks
          .any((t) => t.tagId == null || !tagIds.contains(t.tagId)))
        ('', '태그 없음', -1),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MobileSize.gutter, 8, MobileSize.gutter, MobileSize.contentBottomGap),
      children: [
        // 탭 제목 행 높이 통일 (48)
        ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: MobileSize.headerMinHeight),
          child: Row(children: [
            Expanded(
              child: Text('할 일',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: style.textStrong)),
            ),
            _InboxButton(state: s),
          ]),
        ),
        const SizedBox(height: 16),
        for (final (id, name, color) in sections) ...[
          _SectionHeader(
            state: s,
            name: name,
            color: color < 0 ? style.divider : tagColor(style, color),
            count: _tasksOf(s, id, tagIds).length,
            collapsed: _collapsed.contains(id),
            onTap: () => setState(() => _collapsed.contains(id)
                ? _collapsed.remove(id)
                : _collapsed.add(id)),
          ),
          if (!_collapsed.contains(id)) ...[
            for (final t in _tasksOf(s, id, tagIds))
              _TaskRow(state: s, task: t),
            if (id.isNotEmpty) _AddRow(state: s, tagId: id),
          ],
          const SizedBox(height: MobileSize.sectionGap),
        ],
        if (s.todayDoneTasks.isNotEmpty) ...[
          _SectionHeader(
            state: s,
            name: '오늘 완료',
            color: style.checkBg,
            count: s.todayDoneTasks.length,
            collapsed: !_showDone,
            onTap: () => setState(() => _showDone = !_showDone),
          ),
          if (_showDone)
            for (final t in s.todayDoneTasks)
              _TaskRow(state: s, task: t, done: true),
        ],
      ],
    );
  }

  List<Task> _tasksOf(AppState s, String tagId, Set<String> tagIds) =>
      s.pendingTasks
          .where((t) => tagId.isEmpty
              ? (t.tagId == null || !tagIds.contains(t.tagId))
              : t.tagId == tagId)
          .toList();
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.state,
    required this.name,
    required this.color,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });
  final AppState state;
  final String name;
  final Color color;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    return Semantics(
      button: true,
      expanded: !collapsed,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: MobileSize.row,
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(name,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.textStrong)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(fontSize: 13, color: style.textMuted)),
            const Spacer(),
            Icon(
                collapsed
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
                color: style.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.state, required this.task, this.done = false});
  final AppState state;
  final Task task;
  final bool done;

  void _focusNow(BuildContext context) {
    state.selectTask(task.id);
    state.startTimer();
    HapticFeedback.lightImpact();
    context.read<ValueNotifier<MobileTab>>().value = MobileTab.focus;
  }

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    final current = state.currentTask?.id == task.id;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(
          left: 6), // 테두리2+6+체크48 = 글자 시작 56 (추가 입력과 같은 선)
      decoration: BoxDecoration(
        color: style.rowBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: current ? style.accent : Colors.transparent, width: 2),
        boxShadow: AppShadow.card(style.rowShadow),
      ),
      child: Row(children: [
        // 체크: 48 터치 안에 24 원
        Semantics(
          button: true,
          label: done ? '완료됨' : '완료',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: done
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    state.completeTask(task.id);
                  },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: AppSize.check,
                  height: AppSize.check,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? style.checkBg : null,
                    border: done
                        ? null
                        : Border.all(color: style.accent, width: 1.5),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded,
                          size: 16, color: style.checkFg)
                      : null,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: done ? style.textFaint : style.textStrong,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: style.textFaint,
              ),
            ),
          ),
        ),
        if (!done)
          IconButton(
            tooltip: '바로 집중',
            icon: Icon(Icons.play_circle_outline_rounded,
                color: style.accent, size: 28),
            onPressed: () => _focusNow(context),
          ),
      ]),
    );
  }
}

class _AddRow extends StatefulWidget {
  const _AddRow({required this.state, required this.tagId});
  final AppState state;
  final String tagId;

  @override
  State<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<_AddRow> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.state.scene.style;
    return SizedBox(
      height: 52,
      child: TextField(
        controller: _c,
        onSubmitted: (v) {
          widget.state.addTask(v, tagId: widget.tagId);
          _c.clear();
        },
        style: TextStyle(fontSize: 16, color: style.textStrong),
        decoration: InputDecoration(
          hintText: '할 일 추가',
          hintStyle: TextStyle(color: style.textMuted),
          prefixIcon: Icon(Icons.add_rounded, color: style.textMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 56, minHeight: 52), // 글자 시작 56
          filled: true,
          fillColor: style.rowBg.withValues(alpha: 0.6),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// 인박스(딴생각 메모) 버튼 + 시트: 할 일로 올리기 / 버리기
class _InboxButton extends StatelessWidget {
  const _InboxButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final style = state.scene.style;
    final n = state.inbox.length;
    return PressScale(
      onTap: () => showFocusSheet(context, '딴생각 메모', (ctx) {
        return Consumer<AppState>(builder: (_, s, __) {
          if (s.inbox.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  MobileSize.gutter, 8, MobileSize.gutter, 40),
              child: Text('집중 중 떠오른 생각은 메모 버튼으로 여기에 모여요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: style.textMuted)),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                MobileSize.gutter, 4, MobileSize.gutter, 24),
            children: [
              for (final i in s.inbox)
                Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                      color: style.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Row(children: [
                    Expanded(
                      child: Text(i.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 16, color: style.textStrong)),
                    ),
                    IconButton(
                      tooltip: '할 일로',
                      icon:
                          Icon(Icons.arrow_upward_rounded, color: style.accent),
                      onPressed: () => s.promoteInboxItem(i.id),
                    ),
                    IconButton(
                      tooltip: '버리기',
                      icon: Icon(Icons.close_rounded, color: style.textMuted),
                      onPressed: () => s.deleteInboxItem(i.id),
                    ),
                  ]),
                ),
            ],
          );
        });
      }),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: style.rowBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadow.card(style.rowShadow),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_note_rounded, size: 20, color: style.textStrong),
          const SizedBox(width: 4),
          Text(n > 0 ? '메모 $n' : '메모',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: style.textStrong)),
        ]),
      ),
    );
  }
}
