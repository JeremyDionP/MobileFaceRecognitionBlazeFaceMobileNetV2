import 'package:FaceRecognitionPrototype/data/services/face_recognition_services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/database_repository.dart';
import 'providers/auth_provider.dart';
import 'features/camera/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbRepository = DatabaseRepository();
  await dbRepository.init();

  final mlService = FaceRecognitionService();
  await mlService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(mlService, dbRepository),
        ),
      ],
      child: const FaceAuthApp(),
    ),
  );
}

class FaceAuthApp extends StatelessWidget {
  const FaceAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Face Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}
