import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/tracked_object.dart';

class GeminiService {
  final String _apiKey;
  GenerativeModel? _model;
  bool _isInitialized = false;

  // Keep track of the last time we made an API call to avoid too frequent calls
  DateTime _lastApiCallTime =
      DateTime.now().subtract(const Duration(seconds: 5));
  // Minimum time between API calls in milliseconds
  static const int _minCallIntervalMs = 3000;

  GeminiService(this._apiKey);

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
      );
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing Gemini model: $e');
      return false;
    }
  }

  Future<String> generateDescription(List<TrackedObject> objects) async {
    if (!_isInitialized || _model == null || objects.isEmpty) {
      return '';
    }

    // Check if we need to rate limit
    final now = DateTime.now();
    final timeSinceLastCall = now.difference(_lastApiCallTime).inMilliseconds;
    if (timeSinceLastCall < _minCallIntervalMs) {
      return ''; // Skip this call if it's too soon
    }

    _lastApiCallTime = now;

    try {
      // Create a prompt with objects detected
      final objectsText = objects
          .map((obj) =>
              "${obj.categoryName} (confidence: ${(obj.confidence * 100).toStringAsFixed(0)}%)")
          .join(", ");

      final prompt = """
      You are a visual assistant for a blind person. Analyze the following scene and provide a concise, natural-sounding voice announcement that would be helpful for a blind person navigating their environment.

      Detected objects: $objectsText

      Guidelines for your response:
      1. Focus on immediate spatial relationships and potential hazards
      2. Use natural, conversational language
      3. Be concise but informative
      4. Prioritize important objects and their relative positions
      5. Include any potential obstacles or safety concerns
      6. Keep the response under 150 characters
      7. Format the response as if it were being spoken directly to the user

      Example format: "There's a person about 3 meters ahead, and a chair to your right. Watch your step."
      """;

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      final responseText = response.text?.trim() ?? '';

      // If the response is very long, trim it
      if (responseText.length > 150) {
        return responseText.substring(0, 150);
      }

      return responseText;
    } catch (e) {
      print('Error generating description: $e');
      return objects.isNotEmpty
          ? '${objects.first.categoryName} detected.'
          : 'No objects detected.';
    }
  }
}
