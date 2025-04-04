import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class VideoService {
  VideoPlayerController? _controller;
  final ImagePicker _picker = ImagePicker();
  bool _isPlaying = false;

  Future<File?> pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return null;

    return File(video.path);
  }

  Future<void> initializeVideo(File videoFile) async {
    _controller = VideoPlayerController.file(videoFile);
    await _controller!.initialize();
  }

  Future<void> play() async {
    if (_controller == null) return;
    await _controller!.play();
    _isPlaying = true;
  }

  Future<void> pause() async {
    if (_controller == null) return;
    await _controller!.pause();
    _isPlaying = false;
  }

  Future<void> seekTo(Duration position) async {
    if (_controller == null) return;
    await _controller!.seekTo(position);
  }

  Future<Duration?> getPosition() async {
    if (_controller == null) return null;
    return _controller!.value.position;
  }

  Future<Duration?> getDuration() async {
    if (_controller == null) return null;
    return _controller!.value.duration;
  }

  bool get isPlaying => _isPlaying;

  VideoPlayerController? get controller => _controller;

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isPlaying = false;
  }

  Future<String?> captureFrame() async {
    if (_controller == null) return null;

    try {
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/frame.jpg';
      
      // Capture the current frame
      final image = await _controller!.value.image;
      await image.saveTo(filePath);
      
      return filePath;
    } catch (e) {
      print('Error capturing frame: $e'); 
      return null;
    }
  }
} 