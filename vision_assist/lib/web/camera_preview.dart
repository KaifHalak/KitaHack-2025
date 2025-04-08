import 'dart:html' as html;
import 'dart:ui' as ui;

void registerCameraPreview(html.VideoElement videoElement) {
  // Register the video element as a platform view
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'camera-preview',
    (int viewId) => videoElement,
  );
}
