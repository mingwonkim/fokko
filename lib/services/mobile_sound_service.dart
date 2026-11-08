// lib/services/mobile_sound_service.dart
// AudioDeviceType은 audio_session에서 실험 표시 — 버전은 pubspec.lock에 고정
// ignore_for_file: experimental_member_use
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// 폰 집중 소리. 화면이 꺼져도 계속(iOS 백그라운드 오디오 + 재생 세션),
/// 반복 이음새 없이(just_audio LoopMode.one). 데스크탑은 AmbientSoundService(audioplayers) 그대로.
class MobileSoundService {
  final _player = AudioPlayer();
  String? _loaded; // 플레이어에 올라간 애셋
  String? _want; // 지금 나와야 할 애셋, null = 무음
  Future<void> _queue = Future.value(); // 로딩·재생을 한 줄로 (빠른 전환·로딩 중 정지 경합 방지)
  double _volume = 1;
  // 이어폰이 끊겨 소리를 죽인 상태. 멈추지 않고 무음으로 계속 재생해야 iOS가 앱을 재우지 않아
  // 화면이 꺼진 채로도 이어폰이 다시 붙을 때 알아챈다 (멈추면 그때부터 안 남: 실사용 11/08).
  // 이어폰이 다시 잡히거나 사용자가 소리를 다시 켜면 풀린다. 다시 켤 땐 iOS가 연결된 블루투스로 보내고,
  // 아무것도 안 붙어 있을 때만 스피커로 나온다.
  bool _muted = false;
  AudioSession? _session; // init 실패 시 null

  Future<void> init() async {
    final session = _session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      // 다른 음악과 섞어 들을 수 있게 (집중 소리는 배경음)
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
    ));
    // 전화·Siri·알림음 등으로 끊겼다가 끝나면 다시 재생. iOS가 '재개해도 됨'을 안 주는 경우가 있어
    // 그대로 두면 화면이 꺼진 채 무음 → 앱도 잠들어 화면을 켤 때까지 안 돌아옴 (실사용 10/15).
    session.interruptionEventStream.listen((e) {
      if (!e.begin && _want != null && _want == _loaded) _player.play();
    });
    // 이어폰 분리: just_audio가 멈춘 뒤 무음으로 다시 돌린다
    session.becomingNoisyEventStream.listen((_) async {
      if (_want == null) return;
      _muted = true;
      await _player.setVolume(0);
      // just_audio도 같은 알림에 pause를 건다 — 그게 먼저 끝난 뒤 다시 돌린다
      await _player.playingStream
          .firstWhere((p) => !p)
          .timeout(const Duration(seconds: 1), onTimeout: () => false);
      if (_muted && _want != null && _want == _loaded) _player.play();
    });
    session.devicesChangedEventStream.listen((_) => recheckEarphones());
    await _player.setLoopMode(LoopMode.one);
  }

  /// 이어폰이 끊겨 죽인 소리를, 이어폰(폰 스피커·수화부가 아닌 출력)이 지금 잡혀 있으면 되살린다.
  /// 장치 변화 알림이 빠질 수 있어 앱으로 돌아올 때도 부른다.
  Future<void> recheckEarphones() async {
    final session = _session;
    if (!_muted || session == null) return;
    final Set<AudioDevice> outs;
    try {
      outs = await session.getDevices(includeInputs: false);
    } catch (e) {
      debugPrint('sound devices: $e');
      return;
    }
    const phone = {
      AudioDeviceType.builtInSpeaker,
      AudioDeviceType.builtInEarpiece,
      AudioDeviceType.telephony,
      AudioDeviceType.unknown,
    };
    if (!_muted || !outs.any((d) => d.isOutput && !phone.contains(d.type))) return;
    _muted = false;
    await _player.setVolume(_volume);
    if (_want != null && _want == _loaded && !_player.playing) _player.play();
  }

  Future<void> setVolume(double v) async {
    if (v == _volume) return;
    _volume = v;
    if (!_muted) await _player.setVolume(v);
  }

  /// null이면 멈춤. 매 초 불려도 바뀔 때만 동작한다.
  void set(String? asset) {
    if (asset == _want) return;
    _want = asset;
    if (asset != null && _muted) {
      _muted = false;
      _player.setVolume(_volume);
    }
    _queue = _queue.then((_) => _apply());
  }

  Future<void> _apply() async {
    final want = _want;
    try {
      if (want == null) {
        if (_player.playing) await _player.pause();
        return;
      }
      if (_loaded != want) {
        _loaded = null;
        await _player.setAsset('assets/$want');
        _loaded = want;
      }
      // 로딩하는 사이 멈추거나 다른 소리로 바뀌었으면 다음 차례가 처리
      if (_want == want && !_player.playing) _player.play(); // play()는 멈출 때 끝나므로 기다리지 않는다
    } catch (e) {
      debugPrint('sound: $e');
      if (_want == want) _want = null; // 다음 set()에서 다시 시도
    }
  }

  void dispose() => _player.dispose();
}
