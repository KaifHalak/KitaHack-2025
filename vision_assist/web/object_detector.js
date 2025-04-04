// Use TensorFlow.js COCO-SSD model for real object detection
let model = null;
let isModelLoading = false;
let lastAnnouncementTime = {}; // Track last announcement time per object class

// Initialize detector - load the COCO-SSD model
window.initDetector = async function () {
  if (model !== null) {
    // Model already loaded
    if (typeof window.onDetectorInitialized === "function") {
      window.onDetectorInitialized(true);
    }

    // Announce that the system is ready
    if (window.speakText) {
      window.speakText(
        "Vision assist system ready. Upload a video to begin analysis.",
        true,
        1.0,
        1.0
      );
    }

    return true;
  }

  if (isModelLoading) {
    console.log("Model is already loading...");
    return false;
  }

  isModelLoading = true;
  console.log("Loading COCO-SSD model...");

  try {
    // Check if cocoSsd is available globally
    if (!window.cocoSsd) {
      throw new Error(
        "COCO-SSD model not loaded. Make sure the script is included in the HTML."
      );
    }

    // Load the model using the global cocoSsd object
    model = await cocoSsd.load();

    console.log("COCO-SSD model loaded successfully");
    isModelLoading = false;

    // Call the callback if it exists
    if (typeof window.onDetectorInitialized === "function") {
      window.onDetectorInitialized(true);
    }

    // Announce that the system is ready
    if (window.speakText) {
      window.speakText(
        "Vision assist system ready. Upload a video to begin analysis.",
        true,
        1.0,
        1.0
      );
    }

    return true;
  } catch (error) {
    console.error("Error loading COCO-SSD model:", error);
    isModelLoading = false;

    // Call the callback if it exists with failure status
    if (typeof window.onDetectorInitialized === "function") {
      window.onDetectorInitialized(false);
    }

    // Announce the error
    if (window.speakText) {
      window.speakText(
        "Error initializing object detection. Please try again.",
        true,
        1.0,
        1.0
      );
    }

    return false;
  }
};

// Helper function to create an image element from a URL
const createImageFromUrl = (url) => {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = (e) => reject(e);
    img.src = url;
  });
};

// High-priority objects that should be announced more frequently
const IMPORTANT_OBJECTS = [
  "person",
  "car",
  "truck",
  "bus",
  "motorcycle",
  "bicycle",
  "dog",
  "chair",
  "couch",
  "bed",
  "toilet",
  "door",
  "stairs",
];

// Detect objects from an image URL
window.detectObjectsFromImage = async function (imageUrl) {
  console.log(
    "Detecting objects from image:",
    imageUrl.substring(0, 50) + "..."
  );

  if (!model) {
    await window.initDetector();
    if (!model) {
      console.error("Model not loaded, cannot detect objects");
      return { detections: [] };
    }
  }

  try {
    // Create image element from URL
    const img = await createImageFromUrl(imageUrl);

    // Run detection
    const predictions = await model.detect(img);

    // Convert to our expected format
    const detections = predictions.map((prediction) => {
      const [x, y, width, height] = prediction.bbox;

      return {
        boundingBox: {
          left: x,
          top: y,
          width: width,
          height: height,
        },
        categoryName: prediction.class,
        confidence: prediction.score,
        center: {
          x: x + width / 2,
          y: y + height / 2,
        },
      };
    });

    const result = { detections };

    // Call the callback if it exists
    if (typeof window.onDetectionComplete === "function") {
      window.onDetectionComplete(JSON.stringify(result));
    }

    return result;
  } catch (error) {
    console.error("Error during object detection:", error);

    // Call the callback if it exists
    if (typeof window.onDetectionComplete === "function") {
      window.onDetectionComplete(JSON.stringify({ detections: [] }));
    }

    return { detections: [] };
  }
};

// Track objects - implemented as a simple pass-through for now
window.trackObjects = function (resultsJson, frameWidth, frameHeight) {
  try {
    const results =
      typeof resultsJson === "string" ? JSON.parse(resultsJson) : resultsJson;
    const detections = results.detections || [];
    const currentTime = Date.now();
    const announcementCooldown = 3000; // 3 seconds between announcements of the same class

    // Sort detections by priority and proximity
    detections.sort((a, b) => {
      // Calculate area ratios (proxy for proximity)
      const areaA =
        (a.boundingBox.width * a.boundingBox.height) /
        (frameWidth * frameHeight);
      const areaB =
        (b.boundingBox.width * b.boundingBox.height) /
        (frameWidth * frameHeight);

      // Check if objects are important
      const aImportance = IMPORTANT_OBJECTS.includes(a.categoryName) ? 1 : 0;
      const bImportance = IMPORTANT_OBJECTS.includes(b.categoryName) ? 1 : 0;

      // Sort by importance first, then by proximity
      if (aImportance !== bImportance) {
        return bImportance - aImportance;
      }

      // Sort by proximity (area ratio)
      return areaB - areaA;
    });

    // For simplicity, we'll just use the detection results directly
    // A more advanced implementation would track objects across frames
    const trackedObjects = detections.map((detection, index) => {
      const objectClass = detection.categoryName;
      const confidence = detection.confidence;
      const center = detection.center;

      // Calculate ratio of object size to frame size (proxy for distance)
      const areaRatio =
        (detection.boundingBox.width * detection.boundingBox.height) /
        (frameWidth * frameHeight);

      // Determine proximity status
      let proximityStatus = "Safe Distance";
      if (areaRatio > 0.15) {
        proximityStatus = "VERY CLOSE!";
      } else if (areaRatio > 0.08) {
        proximityStatus = "Getting Close";
      }

      // Get direction relative to center of frame
      const direction = window.getRelativeDirection
        ? window.getRelativeDirection(center.x, frameWidth)
        : "front";

      // Announce important objects with audio feedback
      if (
        window.announceObject &&
        (IMPORTANT_OBJECTS.includes(objectClass) || areaRatio > 0.1)
      ) {
        // Limit announcement frequency
        const lastTime = lastAnnouncementTime[objectClass] || 0;
        if (currentTime - lastTime > announcementCooldown) {
          lastAnnouncementTime[objectClass] = currentTime;
          window.announceObject(
            objectClass,
            confidence,
            direction,
            proximityStatus
          );
        }
      }

      return {
        id: index,
        label: objectClass,
        confidence: confidence,
        speed: 0,
        direction: 0,
        lastBox: detection.boundingBox,
        center: center,
        isMoving: false,
        proximityStatus: proximityStatus,
        directionIndicator: "•",
        areaRatio: areaRatio,
        relativeDirection: direction,
      };
    });

    // Call the callback if it exists
    if (typeof window.onTrackingComplete === "function") {
      window.onTrackingComplete(JSON.stringify(trackedObjects));
    }

    return trackedObjects;
  } catch (error) {
    console.error("Error during tracking:", error);

    // Call the callback if it exists
    if (typeof window.onTrackingComplete === "function") {
      window.onTrackingComplete(JSON.stringify([]));
    }

    return [];
  }
};

// Class for tracking object persistence and movement across frames
// Original tracking helpers are kept for reference if needed
class ObjectTracker {
  constructor() {
    // Constants
    this.TRACKING_IOU_THRESHOLD = 0.3;
    this.CENTER_DISTANCE_THRESHOLD = 50;
    this.MAX_PREDICTION_FRAMES = 3;
    this.MAX_POSITION_HISTORY = 30;
    this.TRACK_CLEANUP_DELAY = 1500;
    this.MIN_SPEED_THRESHOLD = 5.0;
    this.VERY_CLOSE_RATIO = 0.15;
    this.GETTING_CLOSE_RATIO = 0.08;

    // Tracking state
    this.trackedObjects = new Map();
    this.objectIdCounter = 0;
  }

  // Helper methods
  calculateDistance(point1, point2) {
    return Math.sqrt(
      Math.pow(point2.x - point1.x, 2) + Math.pow(point2.y - point1.y, 2)
    );
  }

  calculateIoU(box1, box2) {
    // Calculate intersection coordinates
    const xLeft = Math.max(box1.originX, box2.originX);
    const yTop = Math.max(box1.originY, box2.originY);
    const xRight = Math.min(
      box1.originX + box1.width,
      box2.originX + box2.width
    );
    const yBottom = Math.min(
      box1.originY + box1.height,
      box2.originY + box2.height
    );

    // Check if there is no intersection
    if (xRight < xLeft || yBottom < yTop) {
      return 0;
    }

    // Calculate intersection area
    const intersectionArea = (xRight - xLeft) * (yBottom - yTop);

    // Calculate union area
    const box1Area = box1.width * box1.height;
    const box2Area = box2.width * box2.height;
    const unionArea = box1Area + box2Area - intersectionArea;

    // Return IoU
    return intersectionArea / unionArea;
  }

  calculateSpeed(velocity) {
    return Math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y);
  }

  calculateDirection(velocity) {
    return (Math.atan2(velocity.y, velocity.x) * 180) / Math.PI;
  }

  getDirectionIndicator(direction, speed) {
    if (speed < this.MIN_SPEED_THRESHOLD) {
      return "•"; // Stationary
    }
    const directions = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"];
    const index = Math.round(((direction + 180) % 360) / 45) % 8;
    return directions[index];
  }

  getProximityStatus(areaRatio) {
    if (areaRatio > this.VERY_CLOSE_RATIO) {
      return "VERY CLOSE!";
    } else if (areaRatio > this.GETTING_CLOSE_RATIO) {
      return "Getting Close";
    } else {
      return "Safe Distance";
    }
  }
}

// Create global tracking instance
const tracker = new ObjectTracker();
