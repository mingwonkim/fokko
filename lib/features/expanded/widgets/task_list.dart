// lib/features/expanded/widgets/task_list.dart
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../core/scene_decorations.dart';
import '../../../models/task.dart';
import '../../../state/app_state.dart';

/// 작업 리스트 (Tiimo Today 카드): [장면 칩] 제목·집중 n회 [원형 체크].
/// 행 탭 = 현재 작업 선택, 체크 = 완료, 우클릭 = 삭제. 마지막 줄은 할 일 입력.
class TaskList extends StatefulWidget {
  const TaskList({super.key});

  @override
  State<TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(AppState state) {
    state.addTask(_controller.text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final style = state.scene.style;
    final pending = state.pendingTasks;
    final done = state.todayDoneTasks;

    // 입력은 목록 끝 (고정 아님) — 560px 고정 창에서 카드 2장을 보이게 하려고 (docs/v2/app-deviations.md)
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final task in pending)
          _TaskRow(task: task, state: state, style: style),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: (_) => _submit(state),
          style: TextStyle(fontSize: 14, color: style.textStrong),
          decoration: InputDecoration(
            hintText: pending.isEmpty ? '딱 하나만 적어보세요' : '할 일 추가',
            hintStyle: TextStyle(fontSize: 14, color: style.textFaint),
            filled: true,
            fillColor: style.fieldFill,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: style.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: style.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: style.accent, width: 2),
            ),
            prefixIcon: Icon(Icons.add_rounded, size: 18, color: style.textMuted),
          ),
        ),
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              '완료 ${done.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: style.textMuted,
              ),
            ),
          ),
          for (final task in done)
            _TaskRow(task: task, state: state, style: style, done: true),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.state,
    required this.style,
    this.done = false,
  });

  final Task task;
  final AppState state;
  final SceneStyle style;
  final bool done;

  Future<void> _menu(BuildContext context, Offset at) async {
    final picked = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: const [PopupMenuItem(value: true, child: Text('삭제'))],
    );
    if (picked == true) state.deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = !done && state.currentTask?.id == task.id;
    final count = state.sessionCountFor(task.id);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _menu(context, d.globalPosition),
        child: PressScale(
          onTap: done ? null : () => state.selectTask(task.id),
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : AppDuration.check,
            curve: Curves.easeOut,
            height: AppSize.row,
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: style.rowBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? style.accent : Colors.transparent,
                width: 2,
              ),
              boxShadow: AppShadow.card(style.rowShadow),
            ),
            child: Row(
              children: [
                Container(
                  width: AppSize.chip,
                  height: AppSize.chip,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.divider,
                    shape: BoxShape.circle,
                  ),
                  child: SceneBullet(scene: state.scene, selected: !done),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: done ? style.textFaint : style.textStrong,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: style.textFaint,
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '집중 $count회',
                          style: TextStyle(
                              fontSize: 12, height: 1.3, color: style.textFaint),
                        ),
                    ],
                  ),
                ),
                // 체크: 48 터치 영역 안에 24 원
                Semantics(
                  button: true,
                  label: done ? '완료됨' : '완료',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: done ? null : () => state.completeTask(task.id),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedContainer(
                          duration:
                              reduce ? Duration.zero : AppDuration.check,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
