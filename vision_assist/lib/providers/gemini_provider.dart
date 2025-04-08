import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../models/tracked_object.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiProvider extends ChangeNotifier {
  String apiKey;
  late GeminiService _geminiService;
  bool _isInitialized = false;
  String _latestDescription = '';
  String _latestAudioUrl = '';
  static const String _apiKeyPrefKey = 'gemini_api_key';

  GeminiProvider({required this.apiKey}) {
    _geminiService = GeminiService(apiKey);
    _initialize();
  }

  String get latestDescription => _latestDescription;
  String get latestAudioUrl => _latestAudioUrl;
  bool get isInitialized => _isInitialized;

  Future<void> _initialize() async {
    // Check if we have a saved API key
    if (apiKey.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedApiKey = prefs.getString(_apiKeyPrefKey);
      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        apiKey = savedApiKey;
        _geminiService = GeminiService(apiKey);
      }
    }

    // Initialize the service if we have an API key
    if (apiKey.isNotEmpty) {
      _isInitialized = await _geminiService.initialize();
      notifyListeners();
    }
  }

  Future<void> updateApiKey(String newApiKey) async {
    if (newApiKey.isEmpty) {
      throw Exception('API key cannot be empty');
    }

    // Create a new service with the new API key
    final newService = GeminiService(newApiKey);

    // Test if the API key works
    final success = await newService.initialize();
    if (!success) {
      throw Exception('Failed to initialize with new API key');
    }

    // Save the API key
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, newApiKey);

    // Update our state
    apiKey = newApiKey;
    _geminiService = newService;
    _isInitialized = true;

    notifyListeners();
  }

  Future<Map<String, dynamic>> generateVoiceDescription(
      List<TrackedObject> objects,
      {String? imageBase64}) async {
    if (!_isInitialized || objects.isEmpty) {
      return {'text': '', 'audioUrl': ''};
    }

    final result =
        await _geminiService.generateVoiceDescription(objects, imageBase64);
    if (result['text'].isNotEmpty) {
      _latestDescription = result['text'];
      _latestAudioUrl = result['audioUrl'];
      notifyListeners();
    }

    return result;
  }
}
