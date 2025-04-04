// Object Detection Constants
const double DETECTION_SCORE_THRESHOLD = 0.5;
const int MAX_DETECTION_RESULTS = 20;

// Object Tracking Constants
const double TRACKING_IOU_THRESHOLD = 0.3;
const double CENTER_DISTANCE_THRESHOLD = 50.0;
const int MAX_PREDICTION_FRAMES = 3;
const int MEASUREMENT_INTERVAL = 10;

// Proximity Warning Constants
const double VERY_CLOSE_RATIO = 0.15;
const double GETTING_CLOSE_RATIO = 0.08;

// Speech Synthesis Constants
const int announcementDelay = 5000;          // Minimum milliseconds between announcements
const double speechRate = 1.2;               // Speech rate for normal announcements
const double urgentSpeechRate = 1.3;         // Speech rate for urgent announcements

// Track Management Constants
const int MAX_POSITION_HISTORY = 30;
const int TRACK_CLEANUP_DELAY = 1500;
const int MAX_STALE_TIME = 5000; // Milliseconds
const int MAX_MISSING_FRAMES = 30;

// Movement Constants
const double MIN_SPEED_THRESHOLD = 5.0;
const double SPEED_THRESHOLD = 50.0;

// Scene Analysis Constants
const int SCENE_ANALYSIS_INTERVAL = 20000;
const int SCENE_CLIP_DURATION = 3000;
const int MAX_FRAMES_PER_CLIP = 10;

// Speech Warning Constants
const int speechUpdateInterval = 20;         // Frames between speech updates
const int collisionPredictionTime = 500;     // Time in ms to predict potential collisions
const double overlapThreshold = 0.3;         // IoU threshold to consider objects overlapping
const double approachSpeedThreshold = 50.0;  // Pixels per second to consider object approaching

// Priority levels for speech
enum SpeechPriority {
  normal,
  urgent,
  gemini
}

// Direction indicators
const List<String> directionIndicators = ['→', '↗', '↑', '↖', '←', '↙', '↓', '↘']; 