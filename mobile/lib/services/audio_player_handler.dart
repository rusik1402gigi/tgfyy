import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class SpotigramAudioHandler extends BaseAudioHandler with ChangeNotifier, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  List<Track> get queueTracks => _queue;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  AudioPlayer get player => _player;

  SpotigramAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to playback state changes
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
      notifyListeners();
    });

    // Auto advance when song finishes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          seek(Duration.zero);
          play();
        } else {
          skipToNext();
        }
      }
    });

    _player.positionStream.listen((_) => notifyListeners());
  }

  Future<void> playTrackList(List<Track> tracks, int initialIndex) async {
    _queue = List.from(tracks);
    _currentIndex = initialIndex;
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    final track = currentTrack;
    if (track == null) return;

    // Set lock screen media item metadata for iOS Now Playing Info Center
    final item = MediaItem(
      id: track.id,
      album: "Telegram Музыка",
      title: track.title,
      artist: track.artist,
      duration: Duration(seconds: track.duration),
      artUri: track.coverUrl != null ? Uri.parse(track.coverUrl!) : null,
    );
    mediaItem.add(item);

    try {
      await _player.setUrl(track.streamUrl);
      await _player.play();
    } catch (e) {
      print("[AudioHandler] Error playing ${track.title}: $e");
    }
    notifyListeners();
  }

  @override
  Future<void> play() async {
    await _player.play();
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      if (_currentIndex + 1 < _queue.length) {
        _currentIndex++;
      } else if (_loopMode == LoopMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    await _playCurrentTrack();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = _queue.length - 1;
    }
    await _playCurrentTrack();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void cycleRepeatMode() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  void toggleFavorite() {
    final track = currentTrack;
    if (track != null) {
      track.isFavorite = !track.isFavorite;
      notifyListeners();
    }
  }
}

late SpotigramAudioHandler audioHandler;
