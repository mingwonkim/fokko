// lib/state/app_state.dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../core/design_tokens.dart';
import '../data/local_store.dart';
import '../models/blocker_settings.dart';
import '../models/collection.dart';
import '../models/focus_title.dart';
import '../models/growth.dart';
import '../models/task.dart';

/// 타이머 사이클: 대기 → 집중 → 휴식 → 대기
enum FocusPhase { idle, focus, breakTime }

/// 앱 전역 상태.
/// 원칙: "현재 작업 1개 + 타이머"가 중심. 목록은 보조 데이터.
class AppState extends ChangeNotifier {
  AppState(this._store);

  final LocalStore _store;

  List<Task> _tasks = [];
  List<BrainDumpItem> _inbox = [];
  List<FocusSession> _sessions = [];
  BlockerSettings _blockerSettings = const BlockerSettings();

  String? _currentTaskId;
  Timer? _ticker;
  int _totalSeconds = 25 * 60; // 다음 세션 길이 설정
  ActiveSession? _active; // 진행/일시정지 중인 세션 (저장됨)

  /// 완료 후 자동 휴식 — 데스크탑 true, 폰은 보상 시트에서 선택(false)
  bool autoBreak = true;
  Progress _progress = const Progress(); // 폰: 태그·친구·풍경·물방울
  FocusSession? _lastReward; // 방금 완료한 세션 (보상 시트 표시용, 저장 안 함)
  FocusTitle? _lastPromotion; // 방금 세션으로 오른 칭호 (보상 시트와 같은 수명)

  int _breakTotalSeconds = 5 * 60;
  DateTime? _breakEndsAt; // 휴식 중일 때만 (저장 안 함 — 꺼지면 휴식은 버린다)

  FocusScene _scene = FocusScene.forest;
  bool _soundEnabled = true;
  double _soundVolume = 0.6;

  // ---- Getters ----
  List<Task> get pendingTasks =>
      _tasks.where((t) => !t.isDone).toList(growable: false);

  /// 오늘 완료한 작업 (리스트 하단에 취소선으로 표시)
  List<Task> get todayDoneTasks {
    final now = DateTime.now();
    return _tasks
        .where((t) =>
            t.isDone &&
            t.completedAt != null &&
            t.completedAt!.year == now.year &&
            t.completedAt!.month == now.month &&
            t.completedAt!.day == now.day)
        .toList(growable: false);
  }

  /// 작업별 완료한 집중 세션 수 (🍅 카운트)
  int sessionCountFor(String taskId) => _sessions
      .where((s) => s.taskId == taskId && s.outcome == SessionOutcome.completed)
      .length;

  /// 오늘 완료한 집중 세션 수 (푸터: 심은 나무/모은 별/만난 고래)
  int get todaySessionCount {
    final now = DateTime.now();
    return _sessions
        .where((s) =>
            s.outcome == SessionOutcome.completed &&
            s.endedAt.year == now.year &&
            s.endedAt.month == now.month &&
            s.endedAt.day == now.day)
        .length;
  }

  List<BrainDumpItem> get inbox => List.unmodifiable(_inbox);
  List<FocusSession> get sessions => List.unmodifiable(_sessions);

  Task? get currentTask {
    if (_currentTaskId == null) return null;
    for (final t in _tasks) {
      if (t.id == _currentTaskId && !t.isDone) return t;
    }
    return null;
  }

  bool get isRunning => _active?.isRunning ?? false;
  FocusPhase get phase => _breakEndsAt != null
      ? FocusPhase.breakTime
      : (_active != null ? FocusPhase.focus : FocusPhase.idle);
  ActiveSession? get activeSession => _active;
  BlockerSettings get blockerSettings => _blockerSettings;
  FocusScene get scene => _scene;

  void setScene(FocusScene scene) {
    if (_scene == scene) return;
    _scene = scene;
    notifyListeners();
    _persist();
  }

  bool get soundEnabled => _soundEnabled;
  double get soundVolume => _soundVolume;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    notifyListeners();
    _persist();
  }

  /// 슬라이더 드래그 중엔 persist:false로 호출하고 놓을 때 저장한다 (파일 쓰기 폭주 방지)
  void setSoundVolume(double volume, {bool persist = true}) {
    _soundVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
    if (persist) _persist();
  }

  /// 차단이 실제로 켜져야 하는 상태인가 (집중 중 + 타이머 작동 + 설정 on)
  bool get shouldBlock =>
      phase == FocusPhase.focus && isRunning && _blockerSettings.enabled;

  int get remainingSeconds {
    final now = clock.now();
    if (_breakEndsAt != null) {
      return _breakEndsAt!
          .difference(now)
          .inSeconds
          .clamp(0, _breakTotalSeconds);
    }
    return _active?.remainingSec(now) ?? _totalSeconds;
  }

  int get totalSeconds => _breakEndsAt != null
      ? _breakTotalSeconds
      : (_active?.plannedSec ?? _totalSeconds);

  /// 1.0(시작) → 0.0(종료). FocusRing이 이 값으로 원을 줄인다.
  double get progress =>
      totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds;

  /// 오늘 완료한 집중 시간(분)
  int get todayFocusMinutes {
    final now = DateTime.now();
    return _sessions
        .where((s) =>
            s.endedAt.year == now.year &&
            s.endedAt.month == now.month &&
            s.endedAt.day == now.day)
        .fold(0, (sum, s) => sum + s.minutes);
  }

  // ---- 성장: 목표·연속일·얼음 (v3) ----
  Growth get _growth => _progress.growth;
  Set<String> get _activeDays => _growth.activeDays(_sessions);
  String get _today => dayKey(clock.now());

  int get streakDays => _growth.streak(_today, _activeDays);
  int get bestStreak => _growth.bestStreak(_activeDays);
  int get iceCount => _growth.ice;
  Set<String> get iceDays => _growth.iceDays;
  Set<String> get activeDays => _activeDays;
  bool get focusedToday => _activeDays.contains(_today);

  int get dailyGoal => _growth.daily.on(_today);
  int get weeklyGoal => _growth.weekly.on(weekKey(_today));
  GoalPlan get dailyPlan => _growth.daily;
  GoalPlan get weeklyPlan => _growth.weekly;
  int get todayMinutes => minutesOn(_today);
  int get thisWeekMinutes => weekMinutes(_today);

  /// XP = 끝까지 완료한 집중 분. 칭호와 같은 값이라 따로 저장하지 않는다.
  int get xp => focusMinutesTotal;

  int _completedMinutes(bool Function(String day) inRange) => _sessions
      .where((x) =>
          x.outcome == SessionOutcome.completed && inRange(dayKey(x.endedAt)))
      .fold(0, (sum, x) => sum + (x.focusedSec ?? x.minutes * 60) ~/ 60);

  int minutesOn(String day) => _completedMinutes((d) => d == day);

  int weekMinutes(String day) {
    final from = weekKey(day);
    final to = addDays(from, 6);
    return _completedMinutes(
        (d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0);
  }

  static int _fitGoal(int v, int min, int max) =>
      ((v / Growth.goalStep).round() * Growth.goalStep).clamp(min, max);

  void setDailyGoal(int minutes) {
    final today = _today;
    _setProgress(_progress.copyWith(
        growth: _growth.copyWith(
            daily: _growth.daily.changed(
                _fitGoal(minutes, Growth.dailyMin, Growth.dailyMax),
                today: today,
                from: addDays(today, 1)))));
  }

  void setWeeklyGoal(int minutes) {
    final week = weekKey(_today);
    _setProgress(_progress.copyWith(
        growth: _growth.copyWith(
            weekly: _growth.weekly.changed(
                _fitGoal(minutes, Growth.weeklyMin, Growth.weeklyMax),
                today: week,
                from: addDays(week, 7)))));
  }

  bool buyIce() {
    if (_growth.ice >= Growth.iceMax || _progress.drops < Growth.icePrice) {
      return false;
    }
    _setProgress(_progress.copyWith(
        drops: _progress.drops - Growth.icePrice,
        growth: _growth.copyWith(ice: _growth.ice + 1)));
    return true;
  }

  /// 어제까지 빠진 날을 얼음으로 메운다. 진행 중 세션이 남았으면 그 기록이 먼저라 미룬다.
  void settleGrowth() {
    if (_active != null) return;
    final next = _growth.settled(_today, _activeDays);
    if (identical(next, _growth)) return;
    _setProgress(_progress.copyWith(growth: next));
  }

  /// 방금 세션으로 달성한 퀘스트 (보상 시트와 같은 수명)
  List<QuestReward> get lastQuestRewards => _lastQuestRewards;
  List<QuestReward> _lastQuestRewards = const [];

  Set<String> get unopenedChests => _growth.unopened;
  bool isRewarded(String key) => _growth.rewarded.contains(key);
  String get todayKey => _today;
  String get thisWeekKey => weekKey(_today);

  @visibleForTesting
  void addLeagueOutboxForTest(String id) => _setProgress(_progress.copyWith(
      growth: _growth.copyWith(leagueOutbox: {..._growth.leagueOutbox, id})));

  void openChests(Iterable<String> keys) => _setProgress(
      _progress.copyWith(growth: _growth.opened(keys)));

  /// 그 친구와 끝까지 완료한 누적 분
  int companionMinutes(String id) => _sessions
      .where((x) =>
          x.outcome == SessionOutcome.completed && x.companionId == id)
      .fold(0, (sum, x) => sum + (x.focusedSec ?? x.minutes * 60) ~/ 60);

  CompanionStage companionStage(String id) =>
      CompanionStage.of(companionMinutes(id));

  int get level => MapNode.levelOf(xp);

  bool hasAchievement(Achievement a) => switch (a) {
        Achievement.firstFocus =>
          _sessions.any((x) => x.outcome == SessionOutcome.completed),
        Achievement.week => bestStreak >= 7,
        Achievement.month => bestStreak >= 30,
        Achievement.quarter => bestStreak >= 90,
        Achievement.halfYear => bestStreak >= 180,
        Achievement.year => bestStreak >= 365,
        Achievement.allFriends => Companion.all.every(isUnlocked),
      };

  void _grantGoalRewards(String day) {
    final gained = <QuestReward>[];
    final next = _growth.rewardedFor(day,
        dayMinutes: minutesOn(day),
        weekMinutes: weekMinutes(day),
        onReward: gained.add);
    _progress = _progress.copyWith(
        growth: next,
        drops: _progress.drops + gained.fold(0, (sum, r) => sum + r.drops));
    _lastQuestRewards = gained;
  }

  /// 세션 완료 콜백 (알림/사운드 트리거용, main에서 주입)
  void Function(Task task, int minutes)? onSessionComplete;

  // ---- 초기화 ----
  Future<void> init() async {
    final data = await _store.load();
    _tasks = List.of(data.tasks);
    _inbox = List.of(data.inbox);
    _sessions = List.of(data.sessions);
    _blockerSettings = data.blockerSettings;
    _scene = data.scene;
    _soundEnabled = data.soundEnabled;
    _soundVolume = data.soundVolume;
    _progress = data.progress.withSingleBoard();
    _progress = _progress.copyWith(
        growth: _growth.migrated(_today,
            dayMinutes: minutesOn(_today), weekMinutes: weekMinutes(_today)));
    // 마지막에 하던 미완료 작업이 있으면 이어서 표시
    final pending = pendingTasks;
    if (pending.isNotEmpty) _currentTaskId = pending.first.id;
    // 꺼지기 전 진행 중이던 세션 복구: 이미 끝났으면 완료 처리(휴식 없이), 아니면 이어서
    _active = data.activeSession;
    if (_active != null) {
      _currentTaskId = pending.any((t) => t.id == _active!.taskId)
          ? _active!.taskId
          : null; // 할 일 없이 시작한 세션 → 다른 할 일을 띄우지 않음
      if (_active!.remainingSec(clock.now()) <= 0) {
        _finishSession(startBreak: false);
      } else if (_active!.isRunning) {
        _startTicker();
      }
    }
    settleGrowth();
    _persist();
    notifyListeners();
  }

  Timer? _retry;
  bool _disposed = false;

  /// 저장 실패 시 2초 뒤 최신 상태로 다시 저장 (성공할 때까지)
  Future<void> _persist() async {
    final ok = await _store.save(_snapshot());
    if (!ok && _retry == null && !_disposed) {
      _retry = Timer(const Duration(seconds: 2), () {
        _retry = null;
        _persist();
      });
    }
  }

  /// 대기 중인 저장 완료까지 (테스트용)
  Future<void> flush() => _store.flush();

  StoreData _snapshot() => StoreData(
        tasks: _tasks,
        inbox: _inbox,
        sessions: _sessions,
        blockerSettings: _blockerSettings,
        scene: _scene,
        soundEnabled: _soundEnabled,
        soundVolume: _soundVolume,
        activeSession: _active,
        progress: _progress,
      );

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---- Task ----
  void addTask(String title, {bool setAsCurrent = false, String? tagId}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final task = Task(
        id: _newId(), title: trimmed, createdAt: DateTime.now(), tagId: tagId);
    _tasks.add(task);
    if (setAsCurrent || _currentTaskId == null) {
      _currentTaskId = task.id;
    }
    notifyListeners();
    _persist();
  }

  void selectTask(String id) {
    if (_currentTaskId == id) return;
    stopTimer(); // 작업 전환 시 타이머 리셋 — "하나만" 원칙
    _currentTaskId = id;
    // 태그는 하나의 값(currentTagId)만 쓴다 — 할 일에 태그가 있으면 그걸로 맞춤
    final tag = _tasks.where((t) => t.id == id).firstOrNull?.tagId;
    if (tag != null && _progress.tags.any((t) => t.id == tag)) {
      _progress = _progress.copyWith(currentTagId: () => tag);
    }
    notifyListeners();
    _persist();
  }

  /// 폰: 할 일 없이 태그만으로 집중
  void clearCurrentTask() {
    if (_active != null) return;
    _currentTaskId = null;
    notifyListeners();
  }

  void completeCurrentTask() {
    final task = currentTask;
    if (task == null) return;
    // 진행 중이던 시간은 조기 완료로 기록 (1분 이상일 때)
    if (_active != null && _active!.focusedSec(clock.now()) >= 60) {
      _recordSession(SessionOutcome.early);
    }
    _cancelSession();
    _tasks = _tasks
        .map((t) => t.id == task.id
            ? t.copyWith(isDone: true, completedAt: DateTime.now())
            : t)
        .toList();
    // 다음 작업 자동 선택은 하지 않는다 — 사용자가 직접 고르게 해서
    // "끝냈다"는 완결감을 준다.
    _currentTaskId = null;
    notifyListeners();
    _persist();
  }

  /// 리스트 체크로 완료. 현재 작업이 아니면 타이머·선택을 건드리지 않는다.
  void completeTask(String id) {
    if (id == _currentTaskId) return completeCurrentTask();
    _tasks = _tasks
        .map((t) => t.id == id
            ? t.copyWith(isDone: true, completedAt: DateTime.now())
            : t)
        .toList();
    notifyListeners();
    _persist();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    if (_currentTaskId == id) {
      stopTimer();
      _currentTaskId = null;
    }
    notifyListeners();
    _persist();
  }

  // ---- Brain Dump ----
  void addToInbox(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inbox.insert(
      0,
      BrainDumpItem(id: _newId(), text: trimmed, createdAt: DateTime.now()),
    );
    notifyListeners();
    _persist();
  }

  /// 인박스 항목을 정식 작업으로 승격
  void promoteInboxItem(String id) {
    final idx = _inbox.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = _inbox.removeAt(idx);
    addTask(item.text);
  }

  void deleteInboxItem(String id) {
    _inbox.removeWhere((i) => i.id == id);
    notifyListeners();
    _persist();
  }

  // ---- Timer ----
  // 남은 시간은 항상 시계로 계산한다. 1초 타이머는 화면 갱신·종료 감지용일 뿐.
  void setDurationMinutes(int minutes) {
    if (_active != null) return; // 진행·일시정지 중엔 길이 변경 불가
    _totalSeconds = minutes * 60;
    notifyListeners();
  }

  /// [allowNoTask] 폰: 할 일 없이 태그만으로 시작 허용 (데스크탑은 할 일 필수)
  void startTimer({bool allowNoTask = false}) {
    final task = currentTask;
    if ((task == null && !allowNoTask) || isRunning || _breakEndsAt != null) {
      return;
    }
    final now = clock.now();
    _active = _active?.resumed(now) ??
        ActiveSession(
          id: _newId(),
          taskId: task?.id ?? '',
          taskTitle: task?.title ?? '',
          scene: _scene.name,
          startedAt: now,
          plannedSec: _totalSeconds,
          resumedAt: now,
          tagId: _progress.currentTagId,
          companionId: selectedCompanion.id,
        );
    _startTicker();
    notifyListeners();
    _persist();
  }

  void pauseTimer() {
    if (!isRunning) return;
    _ticker?.cancel();
    _active = _active!.paused(clock.now());
    notifyListeners();
    _persist();
  }

  /// 리셋: 기록 없이 세션을 버린다 (데스크탑 ↺)
  void stopTimer() {
    _breakEndsAt = null;
    _cancelSession();
    notifyListeners();
    _persist();
  }

  /// 그만두기: 집중한 만큼 기록은 남기고 보상은 없음 (폰)
  void abandonSession() {
    if (_active == null) return;
    if (_active!.focusedSec(clock.now()) >= 60) {
      _recordSession(SessionOutcome.abandoned);
    }
    stopTimer();
  }

  /// 비상 탈출 비용: 남은 1분마다 물방울 2 (올림). 실수로 길게 시작했을 때의 출구.
  int get escapeCost => (remainingSeconds / 60).ceil() * 2;

  /// 물방울을 내고 지금 끝낸다. 결과는 그만두기와 같다(기록만, 보상 없음).
  bool escapeSession() {
    final cost = escapeCost;
    if (_active == null || _progress.drops < cost) return false;
    _setProgress(_progress.copyWith(
        drops: _progress.drops - cost,
        escapeSpent: _progress.escapeSpent + cost));
    abandonSession();
    return true;
  }

  String? get rankNickname => _progress.rankNickname;
  void setRankNickname(String? v) => _setProgress(_progress.copyWith(
      rankNickname: () => v,
      // 랭킹에서 나가면 서버 계정이 지워져 리그도 함께 끝난다
      growth: v == null
          ? _growth.copyWith(leagueJoined: false, leagueOutbox: const {})
          : null));

  bool get leagueJoined => _growth.leagueJoined;
  Set<String> get leagueOutbox => _growth.leagueOutbox;

  void setLeagueJoined(bool v) {
    if (v == _growth.leagueJoined) return;
    _setProgress(_progress.copyWith(
        growth: _growth.copyWith(
            leagueJoined: v, leagueOutbox: v ? null : const {})));
  }

  void leagueSent(String sessionId) => _setProgress(_progress.copyWith(
      growth: _growth.copyWith(
          leagueOutbox: _growth.leagueOutbox.difference({sessionId}))));

  /// 끝까지 완료한 집중의 누적 분 (= 모은 물방울 총량, 칭호 기준)
  int get focusMinutesTotal => _sessions
      .where((x) => x.outcome == SessionOutcome.completed)
      .fold(0, (sum, x) => sum + (x.focusedSec ?? x.minutes * 60) ~/ 60);

  FocusTitle get title => FocusTitle.of(focusMinutesTotal);

  /// 랭킹 점수 = 지금까지 모은 물방울 − 비상 탈출에 쓴 물방울. 상점 구매는 빼지 않는다.
  int get rankScore {
    final earned = focusMinutesTotal;
    return (earned - _progress.escapeSpent).clamp(0, earned);
  }

  void _cancelSession() {
    _ticker?.cancel();
    _active = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_breakEndsAt != null) {
        if (remainingSeconds <= 0) return _endBreak();
      } else if (_active != null && _active!.remainingSec(clock.now()) <= 0) {
        return _finishSession();
      }
      notifyListeners();
    });
  }

  /// 끝까지 완료. 세션 ID로 기록하므로 재실행·복귀가 겹쳐도 한 번만 남는다.
  void _finishSession({bool startBreak = true}) {
    final active = _active;
    if (active == null) return;
    _recordSession(SessionOutcome.completed);
    _cancelSession();
    final task = _tasks.where((t) => t.id == active.taskId).firstOrNull;
    if (task != null) onSessionComplete?.call(task, active.plannedSec ~/ 60);
    settleGrowth();
    if (startBreak && autoBreak) {
      _startBreak(); // 집중이 끝나면 자동으로 휴식 — 차단도 이때 풀린다
    } else {
      notifyListeners();
    }
    _persist();
  }

  /// 폰: 보상 시트의 "5분 휴식"
  void startBreak() {
    if (_active != null || _breakEndsAt != null) return;
    _startBreak();
  }

  /// 휴식 시작. 이 동안 차단은 비활성 (shouldBlock == false).
  void _startBreak() {
    _breakEndsAt = clock.now().add(Duration(seconds: _breakTotalSeconds));
    _startTicker();
    notifyListeners();
  }

  void _endBreak() {
    _ticker?.cancel();
    _breakEndsAt = null;
    onBreakEnd?.call();
    notifyListeners();
  }

  /// 휴식 건너뛰고 바로 대기 상태로
  void skipBreak() {
    if (_breakEndsAt == null) return;
    _endBreak();
  }

  void setBreakMinutes(int minutes) {
    _breakTotalSeconds = minutes * 60;
    notifyListeners();
  }

  /// 휴식 종료 콜백 (알림용, main에서 주입)
  void Function()? onBreakEnd;

  // ---- Blocker 설정 ----
  void setBlockerEnabled(bool enabled) {
    _blockerSettings = _blockerSettings.copyWith(enabled: enabled);
    notifyListeners();
    _persist();
  }

  void setBlockerAutoKill(bool autoKill) {
    _blockerSettings = _blockerSettings.copyWith(autoKill: autoKill);
    notifyListeners();
    _persist();
  }

  void addBlockedApp(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _blockerSettings.apps.contains(trimmed)) return;
    _blockerSettings = _blockerSettings.copyWith(
      apps: [..._blockerSettings.apps, trimmed],
    );
    notifyListeners();
    _persist();
  }

  void removeBlockedApp(String name) {
    _blockerSettings = _blockerSettings.copyWith(
      apps: _blockerSettings.apps.where((a) => a != name).toList(),
    );
    notifyListeners();
    _persist();
  }

  void addBlockedSite(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || _blockerSettings.sites.contains(trimmed)) return;
    _blockerSettings = _blockerSettings.copyWith(
      sites: [..._blockerSettings.sites, trimmed],
    );
    notifyListeners();
    _persist();
  }

  void removeBlockedSite(String keyword) {
    _blockerSettings = _blockerSettings.copyWith(
      sites: _blockerSettings.sites.where((s) => s != keyword).toList(),
    );
    notifyListeners();
    _persist();
  }

  /// 진행 세션을 기록으로 확정 (같은 세션 ID는 한 번만)
  void _recordSession(SessionOutcome outcome) {
    final a = _active;
    if (a == null || _sessions.any((s) => s.id == a.id)) return;
    // 완료는 예정 종료 시각으로 확정 — 다음 날 앱을 열어도 기록 날짜가 밀리지 않게
    final now = outcome == SessionOutcome.completed
        ? (a.plannedEnd ?? clock.now())
        : clock.now();
    final focused =
        outcome == SessionOutcome.completed ? a.plannedSec : a.focusedSec(now);
    final titleBefore = title;
    final focusedBefore = _activeDays.contains(dayKey(now));
    _sessions.add(FocusSession(
      id: a.id,
      taskId: a.taskId,
      taskTitle: a.taskTitle,
      minutes: (focused / 60).round(),
      endedAt: now,
      startedAt: a.startedAt,
      focusedSec: focused,
      scene: a.scene,
      outcome: outcome,
      tagId: a.tagId,
      companionId: outcome == SessionOutcome.completed ? a.companionId : null,
      segments: a.segmentsUntil(now),
    ));
    // 보상: 끝까지 완료한 세션만 — 친구 1 + 물방울(실집중 분). 기록과 같은 저장으로 확정.
    if (outcome == SessionOutcome.completed) {
      final owned = Map.of(_progress.owned);
      if (a.companionId != null) {
        owned[a.companionId!] = (owned[a.companionId!] ?? 0) + 1;
      }
      _progress = _progress.copyWith(
          owned: owned, drops: _progress.drops + focused ~/ 60);
      _lastReward = _sessions.last;
      _lastPromotion = title != titleBefore ? title : null;
      final streak = _growth.streak(dayKey(now), _activeDays);
      _lastStreakExtended = !focusedBefore && streak >= 2 ? streak : null;
      // 빠진 날을 먼저 판단한다 — 이번 보상으로 받은 얼음이 지난 공백에 쓰이지 않게
      _progress = _progress.copyWith(
          growth: _growth.settled(dayKey(now), _activeDays));
      _grantGoalRewards(dayKey(now));
      if (_growth.leagueJoined) {
        _progress = _progress.copyWith(
            growth: _growth
                .copyWith(leagueOutbox: {..._growth.leagueOutbox, a.id}));
      }
    }
  }

  // ---- 폰: 태그 · 친구 · 풍경 · 상점 ----
  List<Tag> get tags => _progress.tags;
  Tag? get currentTag =>
      _progress.tags.where((t) => t.id == _progress.currentTagId).firstOrNull;
  int get drops => _progress.drops;
  bool get lockEnabled => _progress.lockEnabled;

  /// 잠금이 실제로 걸릴 수 있는지 (권한·고른 앱). OS 쪽 상태라 저장하지 않는다.
  bool get lockReady => _lockReady;
  bool _lockReady = true;
  void setLockReady(bool v) {
    if (v == _lockReady) return;
    _lockReady = v;
    notifyListeners();
  }


  /// 폰 소리 선택. 'scene'이면 장면을 따라간다.
  String get soundId => _progress.soundId;
  void setSoundId(String id) => _setProgress(_progress.copyWith(soundId: id));
  String get soundAsset {
    // 다른 장면의 상황 소리를 골라 둔 채 장면을 바꾸면 장면 기본으로
    final other = FocusScene.values
        .any((sc) => sc != _scene && sc.situationSounds.contains(soundId));
    final id = soundId == 'scene' || other ? _scene.phoneSound : soundId;
    return 'sounds/$id.m4a';
  }
  void setLockEnabled(bool v) =>
      _setProgress(_progress.copyWith(lockEnabled: v));
  int ownedCount(String itemId) => Companion.byId(itemId)?.isStarter == true
      ? 1
      : _progress.owned[itemId] ?? 0;
  FocusSession? get lastReward => _lastReward;
  FocusTitle? get lastPromotion => _lastPromotion;

  /// 방금 완료로 연속일이 이어졌으면 그 일수 (오늘 첫 완료 · 2일 이상). 연속 배너용.
  int? get lastStreakExtended => _lastStreakExtended;
  int? _lastStreakExtended;
  void clearLastReward() {
    _lastReward = null;
    _lastStreakExtended = null;
    _lastPromotion = null;
    _lastQuestRewards = const [];
    notifyListeners();
  }

  void _setProgress(Progress p) {
    _progress = p;
    notifyListeners();
    _persist();
  }

  void addTag(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    final tag = Tag(id: _newId(), name: n, colorIndex: _progress.tags.length);
    _setProgress(_progress
        .copyWith(tags: [..._progress.tags, tag], currentTagId: () => tag.id));
  }

  void renameTag(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _setProgress(_progress.copyWith(tags: [
      for (final t in _progress.tags) t.id == id ? t.copyWith(name: n) : t
    ]));
  }

  /// 태그 삭제: 지난 기록의 tagId는 그대로 둔다(통계에서 "삭제된 태그"로 묶음)
  void deleteTag(String id) {
    final rest = _progress.tags.where((t) => t.id != id).toList();
    if (rest.isEmpty) return; // 마지막 태그는 지우지 않는다
    _tasks = [
      for (final t in _tasks)
        t.tagId == id
            ? Task(
                id: t.id,
                title: t.title,
                isDone: t.isDone,
                createdAt: t.createdAt,
                completedAt: t.completedAt)
            : t
    ];
    _setProgress(_progress.copyWith(
        tags: rest,
        currentTagId: () => _progress.currentTagId == id
            ? rest.first.id
            : _progress.currentTagId));
  }

  void selectTag(String id) =>
      _setProgress(_progress.copyWith(currentTagId: () => id));

  void setTaskTag(String taskId, String tagId) {
    _tasks = [
      for (final t in _tasks) t.id == taskId ? t.copyWith(tagId: tagId) : t
    ];
    notifyListeners();
    _persist();
  }

  /// 장면별 누적 완료 집중 분 (친구 해금 기준)
  int sceneMinutes(FocusScene s) => _sessions
      .where((x) => x.outcome == SessionOutcome.completed && x.scene == s.name)
      .fold(0, (sum, x) => sum + (x.focusedSec ?? x.minutes * 60) ~/ 60);

  /// 이미 만난 친구는 조건이 바뀌어도 잠기지 않는다
  bool isUnlocked(Companion c) =>
      sceneMinutes(c.scene) >= c.unlockMinutes ||
      xp >= Companion.unlockAllMinutes ||
      ownedCount(c.id) > 0 ||
      c.id == _progress.selectedCompanionId; // 고를 때 해금돼 있던 친구는 조건이 올라도 유지

  /// 이번 세션에 데려올 친구 — 선택이 현재 장면과 다르거나 잠겨 있으면 장면 첫 친구
  Companion get selectedCompanion {
    final c = Companion.byId(_progress.selectedCompanionId);
    if (c != null && c.scene == _scene && isUnlocked(c)) return c;
    return Companion.of(_scene).first;
  }

  void selectCompanion(String id) {
    final c = Companion.byId(id);
    if (c == null || !isUnlocked(c) || _active != null) return;
    _setProgress(_progress.copyWith(selectedCompanionId: () => id));
  }

  bool buyDecor(String id) {
    final d = Decor.byId(id);
    if (d == null || _progress.drops < d.price) return false;
    final owned = Map.of(_progress.owned)
      ..[id] = (_progress.owned[id] ?? 0) + 1;
    _setProgress(
        _progress.copyWith(owned: owned, drops: _progress.drops - d.price));
    return true;
  }

  List<Placement> get placements =>
      _progress.placements[Progress.boardKey] ?? const [];

  int placedCount(String itemId) =>
      placements.where((p) => p.itemId == itemId).length;

  /// 빈 칸에만, 보유 수를 넘지 않게 배치
  bool place(String itemId, int x, int y) {
    final inGrid = x >= 0 && y >= 0 && x < Placement.grid && y < Placement.grid;
    if (!inGrid || placements.any((p) => p.x == x && p.y == y)) return false;
    if (placedCount(itemId) >= ownedCount(itemId)) return false;
    return setPlacements([...placements, Placement(itemId, x, y)]);
  }

  /// 편집 완료: 배치를 한 번에 교체 (빈 칸·보유 수 검증 실패면 false, 아무것도 안 바꿈)
  bool setPlacements(List<Placement> list) {
    final cells = <(int, int)>{};
    final used = <String, int>{};
    for (final p in list) {
      final inGrid =
          p.x >= 0 && p.y >= 0 && p.x < Placement.grid && p.y < Placement.grid;
      if (!inGrid) return false;
      if (!cells.add((p.x, p.y))) return false;
      used[p.itemId] = (used[p.itemId] ?? 0) + 1;
    }
    for (final e in used.entries) {
      if (e.value > ownedCount(e.key)) return false;
    }
    _setProgress(_progress
        .copyWith(placements: {Progress.boardKey: List.of(list)}));
    return true;
  }

  /// 회수: 보관함으로 돌아갈 뿐 재지급·삭제 없음
  void unplace(int x, int y) {
    _setProgress(_progress.copyWith(placements: {
      Progress.boardKey:
          placements.where((p) => p.x != x || p.y != y).toList(),
    }));
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}
