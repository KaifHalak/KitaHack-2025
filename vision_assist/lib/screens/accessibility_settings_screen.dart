import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';
import 'dart:js' as js;

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context);
    
    // Announce screen when opened for blind users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      js.context.callMethod('speakText', [
        "Accessibility Settings Screen. Swipe up or down to navigate options. Double tap to toggle settings.",
        true,
        1.0,
        1.0
      ]);
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              accessibilityProvider.resetSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 0) {
            Navigator.of(context).pop();
            js.context.callMethod('speakText', ["Returning to previous screen", true]);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              title: 'Vision Assistance',
              children: [
                _buildSwitchTile(
                  context: context,
                  title: 'High Contrast Mode',
                  subtitle: 'Use yellow text on black background for better visibility',
                  value: accessibilityProvider.highContrastMode,
                  onChanged: (value) {
                    accessibilityProvider.toggleHighContrastMode();
                  },
                ),
                
                _buildSliderTile(
                  context: context,
                  title: 'Text Size',
                  subtitle: 'Adjust the size of text throughout the app',
                  value: (accessibilityProvider.textScaleFactor - 0.8) / 1.7, // Normalize to 0.0-1.0
                  onChanged: (value) {
                    // Denormalize value range
                    final normalizedValue = 0.8 + (value * 1.7);
                    final textScaleFactor = accessibilityProvider.textScaleFactor;
                    
                    if (normalizedValue > textScaleFactor) {
                      accessibilityProvider.increaseTextSize();
                    } else if (normalizedValue < textScaleFactor) {
                      accessibilityProvider.decreaseTextSize();
                    }
                  },
                  leadingIcon: Icons.text_fields,
                  trailingBuilder: (context) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: accessibilityProvider.decreaseTextSize,
                        tooltip: 'Decrease text size',
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: accessibilityProvider.increaseTextSize,
                        tooltip: 'Increase text size',
                      ),
                    ],
                  ),
                ),
                
                _buildSliderTile(
                  context: context,
                  title: 'UI Size',
                  subtitle: 'Adjust the size of buttons and controls',
                  value: (accessibilityProvider.uiScaleFactor - 0.8) / 1.2, // Normalize to 0.0-1.0
                  onChanged: (value) {
                    // Denormalize value range
                    final normalizedValue = 0.8 + (value * 1.2);
                    final uiScaleFactor = accessibilityProvider.uiScaleFactor;
                    
                    if (normalizedValue > uiScaleFactor) {
                      accessibilityProvider.increaseUIScale();
                    } else if (normalizedValue < uiScaleFactor) {
                      accessibilityProvider.decreaseUIScale();
                    }
                  },
                  leadingIcon: Icons.phonelink_setup,
                  trailingBuilder: (context) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: accessibilityProvider.decreaseUIScale,
                        tooltip: 'Decrease UI size',
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: accessibilityProvider.increaseUIScale,
                        tooltip: 'Increase UI size',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            _buildSection(
              title: 'Audio & Controls',
              children: [
                _buildSwitchTile(
                  context: context,
                  title: 'Audio Confirmation',
                  subtitle: 'Speak feedback when interacting with the app',
                  value: accessibilityProvider.audioConfirmation,
                  onChanged: (value) {
                    accessibilityProvider.toggleAudioConfirmation();
                  },
                ),
                
                _buildSwitchTile(
                  context: context,
                  title: 'Swipe Navigation',
                  subtitle: 'Use swipe gestures to navigate between screens',
                  value: accessibilityProvider.swipeNavigation,
                  onChanged: (value) {
                    accessibilityProvider.toggleSwipeNavigation();
                  },
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  _showGestureGuide(context);
                },
                icon: const Icon(Icons.touch_app),
                label: const Text('Gesture Navigation Guide'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? leadingIcon,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      secondary: leadingIcon != null ? Icon(leadingIcon) : null,
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
  
  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    IconData? leadingIcon,
    Widget Function(BuildContext)? trailingBuilder,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
      leading: leadingIcon != null ? Icon(leadingIcon) : null,
      trailing: trailingBuilder != null ? trailingBuilder(context) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
  
  void _showGestureGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesture Navigation Guide'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _GestureItem(
                icon: Icons.swipe_right,
                name: 'Swipe Right',
                description: 'Go back to previous screen',
              ),
              _GestureItem(
                icon: Icons.swipe,
                name: 'Swipe Up/Down',
                description: 'Navigate between options',
              ),
              _GestureItem(
                icon: Icons.touch_app,
                name: 'Double Tap',
                description: 'Select current option',
              ),
              _GestureItem(
                icon: Icons.touch_app,
                name: 'Triple Tap',
                description: 'Stop all audio narration',
              ),
              _GestureItem(
                icon: Icons.touch_app,
                name: 'Long Press',
                description: 'Get detailed description',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GestureItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  
  const _GestureItem({
    Key? key,
    required this.icon,
    required this.name,
    required this.description,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 