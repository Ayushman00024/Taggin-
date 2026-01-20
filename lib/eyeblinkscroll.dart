import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// ===============================================================
///  EyeBlinkScroll (Web + Mobile Safe Version)
/// ===============================================================
///
/// On Android/iOS → uses camera + ML Kit for blink detection.
/// On Web → safely disabled (no native imports, no compile errors).
///

/// Base interface used by both mobile and web implementations.
abstract class EyeBlinkScroll {
  factory EyeBlinkScroll({required VoidCallback onBlink}) {
    if (kIsWeb) return _EyeBlinkScrollWeb(onBlink);
    return _EyeBlinkScrollMobile(onBlink);
  }

  Future<void> start();
  Future<void> stop();
}

/// ===============================================================
///  ✅ Web Stub (no camera, compiles safely)
/// ===============================================================
class _EyeBlinkScrollWeb implements EyeBlinkScroll {
  final VoidCallback onBlink;
  _EyeBlinkScrollWeb(this.onBlink);

  @override
  Future<void> start() async {
    debugPrint("👁 EyeBlinkScroll disabled on Web — no camera access.");
  }

  @override
  Future<void> stop() async {
    // No-op for web
  }
}

/// ===============================================================
///  ✅ Mobile Implementation (Android/iOS only)
/// ===============================================================
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class _EyeBlinkScrollMobile implements EyeBlinkScroll {
  final VoidCallback onBlink;
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isProcessing = false;
  bool _enabled = false;
  Timer? _cooldownTimer;
  bool _blinkRecently = false;

  _EyeBlinkScrollMobile(this.onBlink) {
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  @override
  Future<void> start() async {
    if (_enabled) return;
    _enabled = true;

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);
      debugPrint("✅ EyeBlinkScroll started on mobile device.");
    } catch (e) {
      debugPrint("❌ Failed to start EyeBlinkScroll: $e");
    }
  }

  @override
  Future<void> stop() async {
    if (!_enabled) return;
    _enabled = false;
    try {
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      await _faceDetector.close();
      _cameraController = null;
      debugPrint("🛑 EyeBlinkScroll stopped.");
    } catch (e) {
      debugPrint("⚠️ Error stopping EyeBlinkScroll: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_enabled || _isProcessing || _blinkRecently) return;
    _isProcessing = true;

    try {
      final inputImage = _convertToInputImage(image, _cameraController!.description);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final left = face.leftEyeOpenProbability ?? 1.0;
        final right = face.rightEyeOpenProbability ?? 1.0;

        if (left < 0.25 && right < 0.25) _triggerBlink();
      }
    } catch (e) {
      debugPrint("Blink detection error: $e");
    }

    _isProcessing = false;
  }

  void _triggerBlink() {
    if (_blinkRecently) return;
    _blinkRecently = true;
    onBlink();
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 2), () {
      _blinkRecently = false;
    });
  }

  InputImage _convertToInputImage(CameraImage image, CameraDescription description) {
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final ui.Size imageSize = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final plane = image.planes.first;
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
