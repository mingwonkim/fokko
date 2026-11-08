// lib/services/session_notifier.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/collection.dart';
import '../state/app_state.dart';

/// 폰: 세션 종료 시각에 로컬 알림 1개. 일시정지·그만두기·완료면 취소, 재개하면 다시 예약.
/// 알림 도착은 완료 처리가 아니다 — 완료 기록은 앱이 켜질 때 AppState가 시각으로 확정한다.
class SessionNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;
  static const _liveId = 2;
  static const _liveChannel = MethodChannel('focusone/break'); // 이름은 휴식 전용이던 때 그대로
  // 지금 띄운 남은 시간 표시(종류·기준값). 처음엔 '모름'으로 두어 앱이 꺼진 사이 남은 표시를 첫 동기화에서 정리
  String? _liveKind = '?';
  int _liveRef = 0;
  String? _scheduledFor; // "세션ID@종료시각" — 같은 예약 반복 방지
  bool _asked = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // 첫 집중 시작 때 묻는다
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// AppState 변화마다 호출
  Future<void> sync(AppState s) async {
    await _syncLive(s);
    final a = s.activeSession;
    if (a == null || !a.isRunning) {
      if (_scheduledFor != null) {
        _scheduledFor = null;
        await _plugin.cancel(id: _id);
      }
      return;
    }
    final endsAt = DateTime.now().add(Duration(seconds: s.remainingSeconds));
    final key = '${a.id}@${endsAt.millisecondsSinceEpoch ~/ 60000}';
    if (key == _scheduledFor) return;
    _scheduledFor = key;
    if (!_asked) {
      _asked = true;
      await _requestPermission();
    }
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
      title: '집중 완료',
      body: a.taskTitle.isEmpty ? '친구가 기다려요. 열어서 데려오세요.' : '"${a.taskTitle}" 끝! 친구를 데려오세요.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('session', '집중 종료',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      // 정확 알람 권한 없이도 동작 (몇 분 늦을 수 있음)
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 잠금 화면에 남은 시간 — 집중(진행·일시정지)·휴식.
  /// iOS는 Dynamic Island·잠금 화면(Live Activity), Android는 줄어드는 시계 알림.
  Future<void> _syncLive(AppState s) async {
    final remaining = s.remainingSeconds;
    if (s.phase == FocusPhase.idle || remaining <= 0) {
      if (_liveKind == null) return;
      _liveKind = null;
      if (Platform.isIOS) {
        await _liveChannel.invokeMethod('end');
      } else {
        await _plugin.cancel(id: _liveId);
      }
      return;
    }
    final focus = s.phase == FocusPhase.focus;
    final paused = focus && !s.isRunning;
    final full = focus ? s.activeSession!.taskTitle : '';
    // Live Activity 내용은 4KB 제한 — 넘으면 카드가 조용히 안 뜬다
    final title = full.length > 80 ? '${full.substring(0, 80)}…' : full;
    final endsAt = DateTime.now().add(Duration(seconds: remaining));
    // 매 초 호출되니 표시가 실제로 바뀐 경우(시작·일시정지·재개·시간 변경)만 다시 띄운다
    // 앱 링과 같은 친구: 진행 중엔 세션에 고정된 친구
    // 색도 그 친구의 장면에서 — 캐릭터와 카드 색이 어긋나지 않게
    final companion =
        Companion.byId(s.activeSession?.companionId) ?? s.selectedCompanion;
    final kind = '${focus ? 'focus' : 'break'}:$paused:$title:${companion.id}';
    final ref = paused ? remaining : endsAt.millisecondsSinceEpoch ~/ 1000;
    if (kind == _liveKind && (ref - _liveRef).abs() < 3) return;
    _liveKind = kind;
    _liveRef = ref;
    if (Platform.isIOS) {
      final style = companion.scene.style;
      await _liveChannel.invokeMethod('start', {
        'endsAt': endsAt.millisecondsSinceEpoch.toDouble(),
        'focus': focus,
        'title': title,
        if (paused) 'pausedSec': remaining,
        'totalSec': s.totalSeconds,
        // 링·머리글은 강조색 — 옅은 ringProgress는 잠금 화면에서 묻힌다
        'ring': style.accent.toARGB32(),
        'card': style.cardBg.toARGB32(),
        'text': style.textStrong.toARGB32(),
        'companion': companion.id,
      });
      return;
    }
    final head = focus ? (paused ? '일시정지' : '집중 중') : '휴식 중';
    await _plugin.show(
      id: _liveId,
      title: title.isEmpty ? head : '$head · $title',
      body: paused
          ? '남은 시간 ${remaining ~/ 60}분 ${remaining % 60}초'
          : (focus ? '끝나면 알려 드릴게요' : '끝나면 다시 집중해요'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
            focus ? 'focus' : 'break', focus ? '집중 남은 시간' : '휴식 남은 시간',
            importance: Importance.low,
            visibility: NotificationVisibility.public, // 잠금 화면에서도 내용까지
            ongoing: true,
            onlyAlertOnce: true,
            showWhen: !paused,
            when: endsAt.millisecondsSinceEpoch,
            usesChronometer: !paused,
            chronometerCountDown: true,
            timeoutAfter: paused ? null : remaining * 1000),
      ),
    );
  }
}
