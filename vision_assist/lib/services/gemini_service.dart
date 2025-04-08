import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/tracked_object.dart';
import '../models/bounding_box.dart';

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

  Future<Map<String, dynamic>> generateVoiceDescription(
      List<TrackedObject> objects, String? imageBase64) async {
    if (!_isInitialized || _model == null || objects.isEmpty) {
      return {'text': '', 'audioUrl': ''};
    }

    // Check if we need to rate limit
    final now = DateTime.now();
    final timeSinceLastCall = now.difference(_lastApiCallTime).inMilliseconds;
    if (timeSinceLastCall < _minCallIntervalMs) {
      return {'text': '', 'audioUrl': ''}; // Skip this call if it's too soon
    }

    _lastApiCallTime = now;

    try {
      // Group objects by category and sort by confidence
      final groupedObjects = <String, List<TrackedObject>>{};
      for (var obj in objects) {
        groupedObjects.putIfAbsent(obj.categoryName, () => []).add(obj);
      }

      // Format objects with more detailed information
      final objectsText = groupedObjects.entries.map((entry) {
        final category = entry.key;
        final objects = entry.value;
        // Sort by confidence
        objects.sort((a, b) => b.confidence.compareTo(a.confidence));

        // Format each object with confidence and position
        final objectsList = objects.map((obj) {
          final confidence = (obj.confidence * 100).toStringAsFixed(0);
          final position = _getRelativePosition(obj.lastBox);
          return "$category (${confidence}% confidence, $position)";
        }).join(", ");

        return "$category: $objectsList";
      }).join("\n");

      final promptText = """
      You are a visual assistant for a blind person. Analyze both the scene image and the detected objects list to provide a concise, natural-sounding voice announcement that would be helpful for a blind person navigating their environment.

      Detected objects:
      $objectsText
      
      Focus on immediate spatial relationships, potential hazards, and use conversational language. Keep responses concise and informative.
      
      Guidelines:
      - Analyze the image to understand the full scene context
      - Describe the scene layout and relationship between objects
      - Prioritize important objects and their general locations
      - Include potential obstacles in the person's path
      - Format the response as if you're speaking directly to the user
      - Keep descriptions under 100 words
      - Don't start with phrases like "I see" or "I detect"
      - Mention approximate distances and directions when useful
      - Use natural speech patterns a human guide would use
      - Use the voice of a friendly male guide
      """;

      // Generate the text description using Gemini 2.0 Flash with multimodal input
      List<Content> content = [];

      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // Create multimodal content with both image and text
        final bytes = base64Decode(imageBase64);

        final imagePart = DataPart('image/jpeg', bytes);
        final textPart = TextPart(promptText);

        content.add(Content.multi([imagePart, textPart]));
      } else {
        // Fallback to text-only content
        content.add(Content.text(promptText));
      }

      final response = await _model!.generateContent(content);
      final text = response.text?.trim() ?? '';

      if (text.isEmpty) {
        return {'text': '', 'audioUrl': ''};
      }

      // Generate audio from the text using Google Cloud Text-to-Speech API
      final audioUrl = await _generateAudioUrl(text);

      return {
        'text': text,
        'audioUrl': audioUrl,
      };
    } catch (e) {
      print('Error generating description: $e');
      return {'text': '', 'audioUrl': ''};
    }
  }

  String _getRelativePosition(BoundingBox box) {
    // Calculate relative position based on bounding box coordinates
    final centerX = box.left + (box.width / 2);
    final centerY = box.top + (box.height / 2);

    String horizontal = 'center';
    if (centerX < 0.33) {
      horizontal = 'left';
    } else if (centerX > 0.66) {
      horizontal = 'right';
    }

    String vertical = 'center';
    if (centerY < 0.33) {
      vertical = 'top';
    } else if (centerY > 0.66) {
      vertical = 'bottom';
    }

    return '$vertical $horizontal';
  }

  Future<String> _generateAudioUrl(String text) async {
    try {
      // Create a unique ID for this audio file using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use Google Cloud Text-to-Speech API with the Gemini API key
      final url =
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey';

      final payload = {
        'input': {'text': text},
        'voice': {
          'languageCode': 'en-US',
          'name': 'en-US-Neural2-D', // Male voice
          'ssmlGender': 'MALE'
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': 1.0,
          'pitch': 0.0
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = data['audioContent'] ?? '';

        // Create a data URL that can be used directly by an audio element
        if (audioContent.isNotEmpty) {
          return 'data:audio/mp3;base64,$audioContent';
        }
      } else {
        print(
            'Error generating audio: ${response.statusCode} ${response.body}');
      }

      return '';
    } catch (e) {
      print('Error in _generateAudioUrl: $e');
      return '';
    }
  }
}
