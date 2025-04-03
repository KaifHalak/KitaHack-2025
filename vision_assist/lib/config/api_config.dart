class ApiConfig {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  
  // Add other API keys and configuration values here
  static const bool isDevelopment = bool.fromEnvironment('DEVELOPMENT', defaultValue: true);
  
  // API endpoints
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );
} 