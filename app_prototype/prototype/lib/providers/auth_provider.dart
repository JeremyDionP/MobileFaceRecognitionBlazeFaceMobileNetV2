import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../data/services/face_recognition_services.dart';
import '../data/repositories/database_repository.dart';

class AuthProvider extends ChangeNotifier {
  final FaceRecognitionService _mlService;
  final DatabaseRepository _dbRepository;

  CameraController? cameraController;
  bool isProcessing = false;

  bool showRegistrationGuide = false;
  bool isRegistering = false;
  bool requiresNameInput = false;
  final List<List<double>> _tempVectors = [];

  int _registrationSteps = 0;
  final int _requiredRegistrationSteps = 5;

  final List<String> _registrationPrompts = [
    "Look straight at the camera.",
    "Turn your head slightly LEFT.",
    "Turn your head slightly RIGHT.",
    "Tilt your head slightly UP.",
    "Tilt your head slightly DOWN."
  ];

  String authMessage = "Initializing Camera...";
  Color resultColor = Colors.grey;
  bool isAuthenticated = false;
  String authenticatedUser = "";

  AuthProvider(this._mlService, this._dbRepository);

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras
          .firstWhere((c) => c.lensDirection == CameraLensDirection.front);

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // Essential for fast processing speeds
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await cameraController!.initialize();
      authMessage = "Scanning...";
      notifyListeners();

      startScanning();
    } catch (e) {
      authMessage = "Camera Error: $e";
      resultColor = Colors.red;
      notifyListeners();
    }
  }

  void startRegistering() {
    showRegistrationGuide = true;
    requiresNameInput = false;
    isRegistering = false;
    notifyListeners();
  }

  void beginCapture() {
    showRegistrationGuide = false;
    isRegistering = true;
    _tempVectors.clear();
    _registrationSteps = 0;

    authMessage = _registrationPrompts[_registrationSteps];
    resultColor = Colors.blue;
    notifyListeners();
  }

  void startScanning() {
    cameraController?.startImageStream((CameraImage image) async {
      if (isProcessing || isAuthenticated) return;
      isProcessing = true;

      if (isRegistering) {
        final vector = await _mlService.extractVectorFromFrame(image);

        if (vector != null) {
          _tempVectors.add(vector);
          _registrationSteps++;

          if (_registrationSteps >= _requiredRegistrationSteps) {
            isRegistering = false;
            requiresNameInput = true;
            authMessage = "Multi-Pose Captured! Enter Identity Name.";
            resultColor = Colors.green;
            cameraController?.stopImageStream();
          } else {
            authMessage = "Great! ${_registrationPrompts[_registrationSteps]}";
            resultColor = Colors.purpleAccent;
            notifyListeners();

            await Future.delayed(const Duration(milliseconds: 1500));
          }
        } else {
          authMessage = "Face not clear. Hold still and face the light.";
          resultColor = Colors.orange;
        }

        isProcessing = false;
        notifyListeners();
        return;
      }

      if (!showRegistrationGuide && !requiresNameInput) {
        final database = _dbRepository.getAllUsers();
        final result = await _mlService.processFrame(image, database);

        if (result == null) {
          authMessage = "No face detected";
          resultColor = Colors.orange;
        } else if (result['isMatch']) {
          authMessage = "Success: ${result['name']}";
          resultColor = Colors.green;
          isAuthenticated = true;
          authenticatedUser = result['name'];
          await cameraController?.stopImageStream();
        } else {
          if (database.isEmpty) {
            authMessage = "Database Empty. Press '+' to Register.";
            resultColor = Colors.blue;
          } else {
            authMessage = "Unknown (${result['distance'].toStringAsFixed(2)})";
            resultColor = Colors.red;
          }
        }
      }

      isProcessing = false;
      notifyListeners();
    });
  }

  Future<void> finalizeRegistration(String name) async {
    for (var vec in _tempVectors) {
      await _dbRepository.registerUser(name, vec);
    }

    _tempVectors.clear();
    requiresNameInput = false;
    authMessage = "Successfully enrolled $name!";
    resultColor = Colors.green;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    startScanning();
  }

  void cancelRegistration() {
    _tempVectors.clear();
    requiresNameInput = false;
    isRegistering = false;
    showRegistrationGuide = false;
    authMessage = "Registration Cancelled";
    resultColor = Colors.orange;
    notifyListeners();

    startScanning();
  }

  Future<void> logoutAndClearData() async {
    await _dbRepository.clearAllUsers();
    isAuthenticated = false;
    authenticatedUser = "";
    authMessage = "Database Cleared. Scanning...";
    resultColor = Colors.blue;
    isProcessing = false;
    notifyListeners();
  }

  Future<void> teardownCamera() async {
    if (cameraController != null) {
      try {
        if (cameraController!.value.isStreamingImages) {
          await cameraController!.stopImageStream();
        }
        await cameraController!.dispose();
      } catch (e) {}
      cameraController = null;
      isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    teardownCamera();
    super.dispose();
  }
}
