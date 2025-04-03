import 'package:flutter_tts/flutter_tts.dart';
import 'constants.dart';

class SpeechUtils {
  final FlutterTts _flutterTts = FlutterTts();
  final List<SpeechItem> _speechQueue = [];
  bool _isSpeaking = false;
  DateTime _lastAnnouncement = DateTime.now();

  Future<void> initialize() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(speechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> speak(String text, {SpeechPriority priority = SpeechPriority.normal}) async {
    final now = DateTime.now();
    
    // Create speech item
    final speechItem = SpeechItem(
      text: text,
      priority: priority,
      timestamp: now,
    );

    // Handle Gemini priority
    if (priority == SpeechPriority.gemini) {
      // Clear non-Gemini items from queue
      _speechQueue.removeWhere((item) => item.priority != SpeechPriority.gemini);
      
      // Add Gemini message to queue
      _speechQueue.add(speechItem);
      
      // If something is currently speaking and it's not Gemini
      if (_isSpeaking && _speechQueue.first.priority != SpeechPriority.gemini) {
        await _flutterTts.stop();
      }
      
      if (!_isSpeaking) {
        await _processNextInQueue();
      }
      return;
    }

    // Handle normal and urgent priorities
    if (now.difference(_lastAnnouncement).inMilliseconds < announcementDelay &&
        priority != SpeechPriority.urgent) {
      return; // Skip non-urgent messages if too soon
    }

    // Don't interrupt Gemini speech
    if (_isSpeaking && _speechQueue.isNotEmpty &&
        _speechQueue.first.priority == SpeechPriority.gemini) {
      return;
    }

    // Add to queue
    _speechQueue.add(speechItem);

    // If nothing is speaking, start speaking
    if (!_isSpeaking) {
      await _processNextInQueue();
    }
  }

  Future<void> _processNextInQueue() async {
    if (_speechQueue.isEmpty) {
      _isSpeaking = false;
      return;
    }

    // Get next speech item
    final speechItem = _speechQueue.removeAt(0);
    
    // Set speech parameters based on priority
    if (speechItem.priority == SpeechPriority.gemini) {
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setPitch(1.0);
    } else if (speechItem.priority == SpeechPriority.urgent) {
      await _flutterTts.setSpeechRate(urgentSpeechRate);
      await _flutterTts.setPitch(1.2);
    } else {
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setPitch(1.0);
    }

    _isSpeaking = true;
    await _flutterTts.speak(speechItem.text);
    _lastAnnouncement = speechItem.timestamp;

    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _processNextInQueue();
    });

    // Set up error handler
    _flutterTts.setErrorHandler((msg) {
      print('Speech error: $msg');
      _isSpeaking = false;
      _processNextInQueue();
    });
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _speechQueue.clear();
  }
}

class SpeechItem {
  final String text;
  final SpeechPriority priority;
  final DateTime timestamp;

  SpeechItem({
    required this.text,
    required this.priority,
    required this.timestamp,
  });
} 