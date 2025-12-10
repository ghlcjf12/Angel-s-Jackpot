import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static const String _bgmKey = 'bgm_enabled';
  static const String _sfxKey = 'sfx_enabled';

  final AudioPlayer _bgmPlayer = AudioPlayer();
  
  // SFX 플레이어 풀 - 동시 재생을 위해 여러 개 준비
  final List<AudioPlayer> _sfxPlayerPool = [];
  static const int _maxSfxPlayers = 5;

  bool _isBgmEnabled = true;
  bool _isSfxEnabled = true;
  String? _currentBgm;
  bool _isInitialized = false;

  bool get isBgmEnabled => _isBgmEnabled;
  bool get isSfxEnabled => _isSfxEnabled;

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    // BGM 플레이어 설정 - 오디오 포커스 없이 재생 (효과음과 충돌 방지)
    await _bgmPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none, // 오디오 포커스 요청 안함 - 효과음과 동시 재생 가능
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    ));
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.5);
    
    // SFX 플레이어 풀 초기화
    for (int i = 0; i < _maxSfxPlayers; i++) {
      final player = AudioPlayer();
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // 오디오 포커스를 요청하지 않음
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));
      await player.setVolume(0.7);
      _sfxPlayerPool.add(player);
    }
    
    await _loadSettings();
    _isInitialized = true;
    debugPrint('AudioService initialized - BGM: $_isBgmEnabled, SFX: $_isSfxEnabled');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isBgmEnabled = prefs.getBool(_bgmKey) ?? true;
    _isSfxEnabled = prefs.getBool(_sfxKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleBgm() async {
    _isBgmEnabled = !_isBgmEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bgmKey, _isBgmEnabled);
    
    if (_isBgmEnabled) {
      if (_currentBgm != null) {
        playBgm(_currentBgm!);
      }
    } else {
      _bgmPlayer.stop();
    }
    notifyListeners();
  }

  Future<void> toggleSfx() async {
    _isSfxEnabled = !_isSfxEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxKey, _isSfxEnabled);
    notifyListeners();
  }

  Future<void> playBgm(String fileName) async {
    if (!_isBgmEnabled) {
      debugPrint('BGM disabled, not playing: $fileName');
      // Don't update _currentBgm if BGM is disabled
      return;
    }

    _currentBgm = fileName;

    try {
      debugPrint('Playing BGM: $fileName');
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('Error playing BGM: $e');
    }
  }

  Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer.stop();
  }

  Future<void> pauseBgm() async {
    if (_bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.pause();
    }
  }

  Future<void> resumeBgm() async {
    if (!_isBgmEnabled) return;
    if (_bgmPlayer.state == PlayerState.paused && _currentBgm != null) {
      await _bgmPlayer.resume();
    } else if (_currentBgm != null && _bgmPlayer.state != PlayerState.playing) {
      // If it wasn't paused but we have a current BGM (e.g. stopped), play it
      // but 'pause' usually means we want to resume exactly where we left off.
      // If state is stopped, resume() might not work depending on implementation, 
      // but play() works.
      // For now, let's trust resume() works for paused state.
      // If it fully stopped, we might need playBgm(_currentBgm!).
      await _bgmPlayer.resume(); 
    }
  }

  int _sfxPoolIndex = 0;

  Future<void> playSfx(String fileName, {Duration? seekTo, double volume = 0.7}) async {
    if (!_isSfxEnabled) {
      debugPrint('SFX disabled, not playing: $fileName');
      return;
    }
    
    if (_sfxPlayerPool.isEmpty) {
      // ... (existing creation logic if empty, though init covers it)
      return;
    }

    try {
      // Use round-robin to avoid race conditions and ensure polyphony
      final player = _sfxPlayerPool[_sfxPoolIndex];
      _sfxPoolIndex = (_sfxPoolIndex + 1) % _maxSfxPlayers;
      
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 3.0)); // Allow up to 3x volume
      await player.setPlaybackRate(1.0); // Reset to normal speed
      
      // Set source first to allow seeking
      await player.setSource(AssetSource('audio/$fileName'));
      if (seekTo != null) {
        await player.seek(seekTo);
      }
      await player.resume(); // Use resume after setting source
      
    } catch (e) {
      debugPrint('Error playing SFX: $e');
    }
  }

  Future<void> playPitchSfx(String fileName, {double volume = 1.0, double pitch = 1.0}) async {
    if (!_isSfxEnabled) return;
    if (_sfxPlayerPool.isEmpty) return;

    try {
      // Use round-robin
      final player = _sfxPlayerPool[_sfxPoolIndex];
      _sfxPoolIndex = (_sfxPoolIndex + 1) % _maxSfxPlayers;

      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setPlaybackRate(pitch.clamp(0.5, 2.0)); 
      await player.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('Error playing pitch SFX: $e');
    }
  }

  // Pre-defined sounds
  void playButtonSound() => playSfx('button.mp3');
  void playSuccessSound() => playSfx('bbabam.mp3');
  void playFailSound() => playSfx('fail.mp3');
  void playGetCoinSound() => playSfx('getcoin.mp3');
  void playBettingSound() => playSfx('batting.mp3', seekTo: const Duration(milliseconds: 200)); // For crash game (0.2s)
  void playBettingSoundLong() => playSfx('batting.mp3', seekTo: const Duration(milliseconds: 400)); // For other games (0.4s)
  
  void playWinSound() async {
    playSfx('bbabam.mp3');
    // "빠밤~" 효과음이 끝난 후 코인 소리 재생 (약 1.5초 딜레이)
    await Future.delayed(const Duration(milliseconds: 1500));
    playSfx('getcoin.mp3');
  }
  
  // BGM Helpers
  void playLobbyBgm() => playBgm('mainlobbybgm.mp3');
  void playGameBgm() => playBgm('housestyle.mp3');
  void playNervousBgm() => playBgm('nervous.mp3');
}
