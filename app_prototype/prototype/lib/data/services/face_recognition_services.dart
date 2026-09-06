import 'dart:math';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'dart:ui';

class FaceRecognitionService {
  tfl.Interpreter? _faceInterpreter;
  tfl.Interpreter? _embeddingInterpreter;

  final double threshold = 0.45;

  final List<List<List<List<double>>>> _faceInput = List.generate(
      1,
      (i) => List.generate(
          128, (y) => List.generate(128, (x) => List.generate(3, (c) => 0.0))));
  final List<List<List<double>>> _faceBoxes =
      List.generate(1, (i) => List.generate(896, (j) => List.filled(16, 0.0)));
  final List<List<List<double>>> _faceScores =
      List.generate(1, (i) => List.generate(896, (j) => List.filled(1, 0.0)));

  final List<List<List<List<double>>>> _embedInput = List.generate(
      1,
      (i) => List.generate(
          160, (y) => List.generate(160, (x) => List.generate(3, (c) => 0.0))));
  final List<List<double>> _embedOutput =
      List.generate(1, (i) => List.filled(128, 0.0));

  Future<void> init() async {
    _faceInterpreter = await tfl.Interpreter.fromAsset(
        'assets/models/blaze_face_short_range.tflite');
    _embeddingInterpreter = await tfl.Interpreter.fromAsset(
        'assets/models/face_embedding_model.tflite');
  }

  Future<Map<String, dynamic>?> processFrame(
      CameraImage image, Map<String, List<List<double>>> database) async {
    if (_faceInterpreter == null || _embeddingInterpreter == null) return null;

    img.Image rgbImage = _convertYUV420ToImage(image);

    final rect =
        await _detectFaceWithBlazeFace(rgbImage, image.width, image.height);
    if (rect == null) return null;

    img.Image? croppedFace = await _cropFace(rgbImage, rect);
    if (croppedFace == null) return null;

    List<double> vector = _extractFeatureVector(croppedFace);
    final result = _findBestMatch(vector, database);

    return result;
  }

  Future<List<double>?> extractVectorFromFrame(CameraImage image) async {
    if (_faceInterpreter == null || _embeddingInterpreter == null) return null;

    img.Image rgbImage = _convertYUV420ToImage(image);

    final rect =
        await _detectFaceWithBlazeFace(rgbImage, image.width, image.height);
    if (rect == null) return null;

    img.Image? croppedFace = await _cropFace(rgbImage, rect);
    if (croppedFace == null) return null;

    return _extractFeatureVector(croppedFace);
  }

  Future<Rect?> _detectFaceWithBlazeFace(
      img.Image rgbImage, int originalWidth, int originalHeight) async {
    try {
      img.Image resizedFaceInput =
          img.copyResize(rgbImage, width: 128, height: 128);

      for (int y = 0; y < 128; y++) {
        for (int x = 0; x < 128; x++) {
          final pixel = resizedFaceInput.getPixel(x, y);
          _faceInput[0][y][x][0] = (pixel.r / 127.5) - 1.0;
          _faceInput[0][y][x][1] = (pixel.g / 127.5) - 1.0;
          _faceInput[0][y][x][2] = (pixel.b / 127.5) - 1.0;
        }
      }

      Map<int, Object> outputs = {0: _faceBoxes, 1: _faceScores};
      _faceInterpreter?.runForMultipleInputs([_faceInput], outputs);

      double maxScore = -999.0;
      int bestBoxIndex = -1;
      for (int i = 0; i < 896; i++) {
        double score = _faceScores[0][i][0];
        if (score > maxScore) {
          maxScore = score;
          bestBoxIndex = i;
        }
      }

      if (maxScore < 0.5) return null;

      var box = _faceBoxes[0][bestBoxIndex];
      double ymin = box[0] * originalHeight;
      double xmin = box[1] * originalWidth;
      double ymax = box[2] * originalHeight;
      double xmax = box[3] * originalWidth;

      return Rect.fromLTRB(xmin, ymin, xmax, ymax);
    } catch (e) {
      return null;
    }
  }

  List<double> _extractFeatureVector(img.Image image) {
    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = image.getPixel(x, y);
        _embedInput[0][y][x][0] = (pixel.r / 127.5) - 1.0;
        _embedInput[0][y][x][1] = (pixel.g / 127.5) - 1.0;
        _embedInput[0][y][x][2] = (pixel.b / 127.5) - 1.0;
      }
    }

    _embeddingInterpreter?.run(_embedInput, _embedOutput);
    return List.from(_embedOutput[0]);
  }

  Map<String, dynamic> _findBestMatch(
      List<double> liveVector, Map<String, List<List<double>>> database) {
    String bestName = "No match";
    double lowestDistance = double.infinity;

    database.forEach((name, angles) {
      for (var refVector in angles) {
        double distance = _euclideanDistance(liveVector, refVector);
        if (distance < lowestDistance) {
          lowestDistance = distance;
          bestName = name;
        }
      }
    });

    if (lowestDistance < threshold) {
      return {
        'isMatch': true,
        'name': bestName,
        'distance': lowestDistance,
        'vector': liveVector
      };
    } else {
      return {
        'isMatch': false,
        'name': 'No match',
        'distance': lowestDistance,
        'vector': liveVector
      };
    }
  }

  Future<img.Image?> _cropFace(
      img.Image convertedImage, Rect boundingBox) async {
    int x = boundingBox.left.toInt();
    int y = boundingBox.top.toInt();
    int w = boundingBox.width.toInt();
    int h = boundingBox.height.toInt();

    int margin = 20;
    x = max(0, x - margin);
    y = max(0, y - margin);
    w = min(convertedImage.width - x, w + 2 * margin);
    h = min(convertedImage.height - y, h + 2 * margin);

    if (w <= 0 || h <= 0) return null;

    img.Image cropped =
        img.copyCrop(convertedImage, x: x, y: y, width: w, height: h);
    return img.copyResize(cropped, width: 160, height: 160);
  }

  double _euclideanDistance(List<double> v1, List<double> v2) {
    double sum = 0.0;
    for (int i = 0; i < v1.length; i++) {
      double diff = v1[i] - v2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  void dispose() {
    _faceInterpreter?.close();
    _embeddingInterpreter?.close();
  }

  img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    final convertedImage = img.Image(width: width, height: height);

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final index = h * yRowStride + w;

        final y = yPlane[index];
        final u = uPlane[uvIndex];
        final v = vPlane[uvIndex];

        int r = (y + ((v * 1436) >> 10) - 179).clamp(0, 255);
        int g = (y - ((u * 46549) >> 17) + 44 - ((v * 93604) >> 17) + 91)
            .clamp(0, 255);
        int b = (y + ((u * 1814) >> 10) - 227).clamp(0, 255);

        convertedImage.setPixelRgb(w, h, r, g, b);
      }
    }
    return convertedImage;
  }
}
