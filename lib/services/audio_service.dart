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
    _currentBgm = fileName;
    if (!_isBgmEnabled) {
      debugPrint('BGM disabled, not playing: $fileName');
      return;
    }

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

  Future<void> playSfx(String fileName) async {
    if (!_isSfxEnabled) {
      debugPrint('SFX disabled, not playing: $fileName');
      return;
    }
    
    if (_sfxPlayerPool.isEmpty) {
      debugPrint('SFX player pool empty, creating new player for: $fileName');
      // 풀이 비어있으면 새 플레이어 생성 (AudioContext 포함)
      final player = AudioPlayer();
      try {
        await player.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ));
        await player.setVolume(0.7);
        await player.play(AssetSource('audio/$fileName'));
        debugPrint('SFX played with new player: $fileName');
      } catch (e) {
        debugPrint('Error playing SFX with new player: $e');
      }
      return;
    }

    try {
      debugPrint('Playing SFX: $fileName');
      // 풀에서 사용 가능한 플레이어 찾기 (재생 중이 아닌 것)
      AudioPlayer? availablePlayer;
      for (final player in _sfxPlayerPool) {
        final state = player.state;
        if (state != PlayerState.playing) {
          availablePlayer = player;
          break;
        }
      }
      
      // 모든 플레이어가 사용 중이면 첫 번째 플레이어 재사용
      availablePlayer ??= _sfxPlayerPool.first;
      
      await availablePlayer.stop();
      await availablePlayer.play(AssetSource('audio/$fileName'));
      debugPrint('SFX play command sent: $fileName');
    } catch (e) {
      debugPrint('Error playing SFX: $e');
    }
  }

  // Pre-defined sounds
  void playButtonSound() => playSfx('button.mp3');
  void playSuccessSound() => playSfx('bbabam.mp3');
  void playFailSound() => playSfx('fail.mp3');
  void playGetCoinSound() => playSfx('getcoin.mp3');
  
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
