import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      authProvider.teardownCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (authProvider.cameraController == null &&
          !authProvider.isAuthenticated) {
        authProvider.initCamera();
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.teardownCamera().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !authProvider.isAuthenticated) {
          authProvider.initCamera();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (context, authProvider, child) {
      if (authProvider.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    HomeScreen(userName: authProvider.authenticatedUser)),
          );
        });
      }

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (authProvider.cameraController != null &&
                authProvider.cameraController!.value.isInitialized)
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(authProvider.cameraController!),
              )
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            if (authProvider.isRegistering)
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 350,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: authProvider.resultColor.withOpacity(0.8),
                            width: 4),
                        borderRadius:
                            const BorderRadius.all(Radius.elliptical(250, 350)),
                        boxShadow: [
                          BoxShadow(
                            color: authProvider.resultColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ]),
                  ),
                ),
              ),
            if (!authProvider.requiresNameInput &&
                !authProvider.showRegistrationGuide)
              Positioned(
                bottom: 50,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: authProvider.resultColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: authProvider.resultColor.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]),
                  child: Text(
                    authProvider.authMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: authProvider.resultColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (authProvider.showRegistrationGuide)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.face_retouching_natural,
                              color: Colors.blue, size: 60),
                          const SizedBox(height: 16),
                          const Text(
                            "Face Registration",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const ListTile(
                            leading:
                                Icon(Icons.light_mode, color: Colors.orange),
                            title: Text("Find a well-lit area"),
                            dense: true,
                          ),
                          const ListTile(
                            leading: Icon(Icons.center_focus_strong,
                                color: Colors.blue),
                            title: Text("Fit your face inside the oval"),
                            dense: true,
                          ),
                          const ListTile(
                            leading: Icon(Icons.sentiment_neutral,
                                color: Colors.grey),
                            title: Text("Keep a neutral expression"),
                            dense: true,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    authProvider.cancelRegistration(),
                                child: const Text("Cancel",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue),
                                onPressed: () => authProvider.beginCapture(),
                                child: const Text("I'm Ready",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (authProvider.requiresNameInput)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 60),
                          const SizedBox(height: 16),
                          const Text(
                            "Face Captured Successfully!",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Enter Identity Name",
                              hintText: "e.g. Jeremy",
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _nameController.clear();
                                  authProvider.cancelRegistration();
                                },
                                child: const Text("Cancel",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                onPressed: () {
                                  if (_nameController.text.trim().isNotEmpty) {
                                    authProvider.finalizeRegistration(
                                        _nameController.text.trim());
                                    _nameController.clear();
                                  }
                                },
                                child: const Text("Save Identity",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!authProvider.isRegistering &&
                !authProvider.requiresNameInput &&
                !authProvider.showRegistrationGuide)
              Positioned(
                top: 50,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () => authProvider.startRegistering(),
                ),
              )
          ],
        ),
      );
    });
  }
}
