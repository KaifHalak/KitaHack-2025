import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import '../services/gemini_service.dart';
import '../models/tracked_object.dart';
import '../models/navigation_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;

class GeminiProvider extends ChangeNotifier {
  String _apiKey;
  late GeminiService _geminiService;
  bool _isInitialized = false;
  String _latestDescription = '';
  String _latestAudioUrl = '';
  NavigationState? _navigationState;
  static const String _apiKeyPrefKey = 'gemini_api_key';
  AudioPlayer? _audioPlayer;

  String get latestDescription => _latestDescription;
  String get latestAudioUrl => _latestAudioUrl;
  bool get isInitialized => _isInitialized;
  NavigationState? get navigationState => _navigationState;

  GeminiProvider({required String apiKey}) : _apiKey = apiKey {
    _geminiService = GeminiService(_apiKey);
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if we have a saved API key
    if (_apiKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedApiKey = prefs.getString(_apiKeyPrefKey);
      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        _apiKey = savedApiKey;
        _geminiService = GeminiService(_apiKey);
      }
    }

    // Initialize the service if we have an API key
    if (_apiKey.isNotEmpty) {
      _isInitialized = await _geminiService.initialize();
      notifyListeners();
    }
  }

  Future<void> updateApiKey(String newApiKey) async {
    if (newApiKey.isEmpty) return;

    // Save the API key
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, newApiKey);

    // Create a new service with the new API key
    final newService = GeminiService(newApiKey);
    await newService.initialize();

    // Update our state
    _apiKey = newApiKey;
    _geminiService = newService;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> generateDescription(
      List<TrackedObject> objects, String? imageBase64) async {
    if (!_isInitialized || objects.isEmpty) {
      print(
          'Cannot generate description: initialized=$_isInitialized, objects=${objects.length}');
      return;
    }

    print('Generating description for ${objects.length} objects');
    try {
      final result = await _geminiService.generateVoiceDescription(
        objects,
        imageBase64,
        _navigationState,
      );

      final text = result['text'] as String?;
      final textPreview = text != null && text.isNotEmpty
          ? text.substring(0, math.min<int>(50, text.length))
          : '';
      print('Description result: $textPreview...');
      print('Audio URL available: ${result['audioUrl']?.isNotEmpty == true}');

      if (result['text']?.isNotEmpty == true) {
        _latestDescription = result['text']!;
        _latestAudioUrl = result['audioUrl'] ?? '';
        notifyListeners();

        // Store description in JavaScript for fallback
        js.context['lastGeminiDescription'] = _latestDescription;

        // Use Web Speech API for voice announcements
        if (_latestAudioUrl.isNotEmpty) {
          try {
            final audio = html.AudioElement(_latestAudioUrl);
            audio.onPlaying.listen((_) {
              print('Audio playback started');
            });
            audio.onEnded.listen((_) {
              print('Audio playback completed');
            });
            audio.onError.listen((event) {
              print('Audio playback error: $event');

              // Fallback to Web Speech API if audio element fails
              if (_latestDescription.isNotEmpty) {
                _speakWithWebSpeechAPI(_latestDescription);
              }
            });

            // Start playback
            final playPromise = audio.play();
            if (playPromise != null) {
              print('Audio play() returned a promise');
            } else {
              print('Audio play() started');
            }
          } catch (e) {
            print('Error playing audio: $e');

            // Fallback to Web Speech API
            if (_latestDescription.isNotEmpty) {
              _speakWithWebSpeechAPI(_latestDescription);
            }
          }
        } else if (_latestDescription.isNotEmpty) {
          // No audio URL, use Web Speech API as fallback
          print('No audio URL, using Web Speech API fallback');
          _speakWithWebSpeechAPI(_latestDescription);
        }
      } else {
        print('Empty description received from Gemini service');
      }
    } catch (e) {
      print('Error generating description: $e');
    }
  }

  void _speakWithWebSpeechAPI(String text) {
    try {
      // Call the JavaScript speech synthesis function directly
      js.context.callMethod('speakText', [text, true, 1.0, 1.0]);
    } catch (e) {
      print('Error using speech synthesis: $e');
    }
  }

  void updateNavigationState(NavigationState? state) {
    _navigationState = state;
    notifyListeners();
  }

  void stopAudio() {
    // Stop any ongoing audio playback
    if (_audioPlayer != null) {
      _audioPlayer?.stop();
    }
  }
}
