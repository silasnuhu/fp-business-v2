import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:whoxa/main.dart';

class VoiceProvider extends ChangeNotifier {
  VoiceProvider() {
    init();
  }

  bool _isRecordPlaying = false,
      isRecording = false,
      isSending = false,
      isUploading = false;
  int _currentId = 999999;
  DateTime start = DateTime.now();
  DateTime end = DateTime.now();
  String _total = "";
  String get total => _total;
  var completedPercentage = 0.0;
  var currentDuration = 0;
  var totalDuration = 0;

  bool get isRecordPlaying => _isRecordPlaying;
  bool get isRecordingValue => isRecording;
  late final AudioPlayerService audioPlayerService;
  int get currentId => _currentId;

  void isRecordPlay(bool value) {
    _isRecordPlaying = value;
    notifyListeners();
  }

  void currentID(int value) {
    _currentId = value;
    notifyListeners();
  }

  void init() {
    audioPlayerService = AudioPlayerAdapter();

    audioPlayerService.getAudioPlayer.onDurationChanged.listen((duration) {
      totalDuration = duration.inMicroseconds;
      // Ensure totalDuration is not zero to prevent divide by zero
      if (totalDuration <= 0) {
        totalDuration = 1; // Prevent divide by zero or NaN
      }
    });

    audioPlayerService.getAudioPlayer.onPositionChanged.listen((duration) {
      currentDuration = duration.inMicroseconds;
      // Check if totalDuration is valid before calculating completedPercentage
      if (totalDuration > 0) {
        completedPercentage =
            currentDuration.toDouble() / totalDuration.toDouble();
      } else {
        completedPercentage = 0.0; // Handle as needed
      }
    });

    audioPlayerService.getAudioPlayer.onPlayerComplete.listen((event) async {
      await audioPlayerService.getAudioPlayer.seek(Duration.zero);
      isRecordPlay(false);
    });
    notifyListeners();
  }

  Future<void> changeProg() async {
    if (isRecordPlaying) {
      audioPlayerService.getAudioPlayer.onDurationChanged.listen((duration) {
        totalDuration = duration.inMicroseconds;
      });

      audioPlayerService.getAudioPlayer.onPositionChanged.listen((duration) {
        currentDuration = duration.inMicroseconds;
        // Check if totalDuration is valid before calculating completedPercentage
        if (totalDuration > 0) {
          completedPercentage =
              currentDuration.toDouble() / totalDuration.toDouble();
        } else {
          completedPercentage = 0.0; // Handle as needed
        }
      });
    }
    notifyListeners();
  }

  void onPressedPlayButton(int id, String content) async {
    currentID(id);
    if (isRecordPlaying) {
      await _pauseRecord();
    } else {
      isRecordPlay(true);
      try {
        await audioPlayerService.play(content);
        // Delay duration fetch to ensure it's loaded properly
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Adjust delay as needed
      } catch (e) {
        isRecordPlay(false);
        logger.v('Error playing audio: $e');
      }
    }
    notifyListeners();
  }

  void calcDuration() {
    var a = end.difference(start).inSeconds;
    format(Duration d) => d.toString().split('.').first.padLeft(8, "0");
    _total = format(Duration(seconds: a));
    notifyListeners();
  }

  Future<void> _pauseRecord() async {
    isRecordPlay(false);
    await audioPlayerService.pause();
    notifyListeners();
  }

  @override
  void dispose() {
    audioPlayerService.dispose();
    super.dispose();
  }
}

abstract class AudioPlayerService {
  void dispose();
  Future<void> play(String url);
  Future<void> resume();
  Future<void> pause();
  Future<void> release();

  AudioPlayer get getAudioPlayer;
}

class AudioPlayerAdapter implements AudioPlayerService {
  late AudioPlayer _audioPlayer;

  @override
  AudioPlayer get getAudioPlayer => _audioPlayer;

  AudioPlayerAdapter() {
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() async {
    await _audioPlayer.dispose();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> play(String url) async {
    try {
      await _audioPlayer
          .play(UrlSource(url))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("Audio playback timed out");
            },
          );
    } catch (e) {
      logger.v('Error during audio play: $e');
      rethrow;
    }
  }

  @override
  Future<void> release() async {
    await _audioPlayer.release();
  }

  @override
  Future<void> resume() async {
    await _audioPlayer.resume();
  }
}

class AudioDuration {
  static double calculate(Duration soundDuration) {
    if (soundDuration.inSeconds > 60) {
      return 70;
    } else if (soundDuration.inSeconds > 50) {
      return 65;
    } else if (soundDuration.inSeconds > 40) {
      return 60;
    } else if (soundDuration.inSeconds > 30) {
      return 55;
    } else if (soundDuration.inSeconds > 20) {
      return 50;
    } else if (soundDuration.inSeconds > 10) {
      return 45;
    } else {
      return 40;
    }
  }
}
