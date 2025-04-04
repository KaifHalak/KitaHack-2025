import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;

class AccessibilityProvider extends ChangeNotifier {
  bool _highContrastMode = false;
  double _textScaleFactor = 1.2;  // Start with slightly larger text by default
  double _iconScaleFactor = 1.2;   // Start with slightly larger icons by default
  double _uiScaleFactor = 1.2;     // Start with slightly larger UI elements
  double _fontSizeDelta = 2.0;     // Additional size increase for all text
  bool _audioConfirmation = true;  // Enable audio feedback by default
  
  // Gesture navigation settings
  bool _swipeNavigation = true;
  
  // Access to the Web Speech API for audio feedback
  void speakText(String text, {bool interrupt = false}) {
    if (!_audioConfirmation) return;
    
    js.context.callMethod('speakText', [text, interrupt, 1.0, 1.0]);
  }
  
  // Getters for all properties
  bool get highContrastMode => _highContrastMode;
  double get textScaleFactor => _textScaleFactor;
  double get iconScaleFactor => _iconScaleFactor;
  double get uiScaleFactor => _uiScaleFactor;
  double get fontSizeDelta => _fontSizeDelta;
  bool get audioConfirmation => _audioConfirmation;
  bool get swipeNavigation => _swipeNavigation;
  
  // Toggle high contrast mode
  void toggleHighContrastMode() {
    _highContrastMode = !_highContrastMode;
    
    if (_audioConfirmation) {
      speakText(_highContrastMode 
          ? "High contrast mode enabled" 
          : "High contrast mode disabled", 
        interrupt: true);
    }
    
    notifyListeners();
  }
  
  // Toggle audio confirmation
  void toggleAudioConfirmation() {
    _audioConfirmation = !_audioConfirmation;
    
    if (_audioConfirmation) {
      speakText("Audio feedback enabled", interrupt: true);
    }
    
    notifyListeners();
  }
  
  // Toggle swipe navigation
  void toggleSwipeNavigation() {
    _swipeNavigation = !_swipeNavigation;
    
    if (_audioConfirmation) {
      speakText(_swipeNavigation 
          ? "Swipe navigation enabled" 
          : "Swipe navigation disabled", 
        interrupt: true);
    }
    
    notifyListeners();
  }
  
  // Increase text size
  void increaseTextSize() {
    if (_textScaleFactor < 2.5) {
      _textScaleFactor += 0.1;
      _fontSizeDelta += 0.5;
      
      if (_audioConfirmation) {
        speakText("Text size increased");
      }
      
      notifyListeners();
    } else {
      if (_audioConfirmation) {
        speakText("Maximum text size reached");
      }
    }
  }
  
  // Decrease text size
  void decreaseTextSize() {
    if (_textScaleFactor > 0.8) {
      _textScaleFactor -= 0.1;
      _fontSizeDelta -= 0.5;
      
      if (_audioConfirmation) {
        speakText("Text size decreased");
      }
      
      notifyListeners();
    } else {
      if (_audioConfirmation) {
        speakText("Minimum text size reached");
      }
    }
  }
  
  // Increase UI scale
  void increaseUIScale() {
    if (_uiScaleFactor < 2.0) {
      _uiScaleFactor += 0.1;
      _iconScaleFactor += 0.1;
      
      if (_audioConfirmation) {
        speakText("Interface size increased");
      }
      
      notifyListeners();
    } else {
      if (_audioConfirmation) {
        speakText("Maximum interface size reached");
      }
    }
  }
  
  // Decrease UI scale
  void decreaseUIScale() {
    if (_uiScaleFactor > 0.8) {
      _uiScaleFactor -= 0.1;
      _iconScaleFactor -= 0.1;
      
      if (_audioConfirmation) {
        speakText("Interface size decreased");
      }
      
      notifyListeners();
    } else {
      if (_audioConfirmation) {
        speakText("Minimum interface size reached");
      }
    }
  }
  
  // Reset all settings to defaults
  void resetSettings() {
    _highContrastMode = false;
    _textScaleFactor = 1.2;
    _iconScaleFactor = 1.2;
    _uiScaleFactor = 1.2;
    _fontSizeDelta = 2.0;
    
    if (_audioConfirmation) {
      speakText("Settings reset to defaults");
    }
    
    notifyListeners();
  }
} 