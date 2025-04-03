import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';

enum SpeechPriority {
  low,
  medium,
  high,
  urgent,
}

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  final List<SpeechItem> _queue = [];
  bool _isSpeaking = false;

  SpeechService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
  }

  void speak(String text, SpeechPriority priority) {
    final item = SpeechItem(text: text, priority: priority);
    _queue.add(item);
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isSpeaking || _queue.isEmpty) return;

    _isSpeaking = true;
    final item = _queue.removeAt(0);
    await _tts.speak(item.text);
    await Future.delayed(Duration(milliseconds: item.text.length * 50));
    _isSpeaking = false;

    if (_queue.isNotEmpty) {
      _processQueue();
    }
  }

  void dispose() {
    _tts.stop();
  }
}

class SpeechItem {
  final String text;
  final SpeechPriority priority;
  final DateTime timestamp;

  SpeechItem({
    required this.text,
    required this.priority,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
} 