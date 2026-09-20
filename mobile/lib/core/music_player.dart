import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class MusicPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  String? title;
  String? performer;
  int? fileId;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool loading = false;
  bool playing = false;

  MusicPlayerController() {
    _stateSubscription = _player.playerStateStream.listen((state) {
      playing = state.playing;
      if (state.processingState == ProcessingState.completed) {
        playing = false;
        _player.seek(Duration.zero);
      }
      notifyListeners();
    });
    _positionSubscription = _player.positionStream.listen((value) {
      position = value;
      notifyListeners();
    });
    _player.durationStream.listen((value) {
      duration = value ?? Duration.zero;
      notifyListeners();
    });
  }

  bool get hasTrack => title != null;

  Future<void> playFile({required int id, required String path, required String trackTitle, String? trackPerformer}) async {
    loading = true;
    title = trackTitle;
    performer = trackPerformer;
    fileId = id;
    notifyListeners();
    try {
      await _player.setFilePath(path);
      await _player.play();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration value) => _player.seek(value);

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
