import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:another_flushbar/flushbar.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initCamera;
  late Directory scansDirectory;

  @override
  void initState() {
    super.initState();
    _initCamera = _setupCamera();
  }

  Future<void> _setupCamera() async {
    // Prepare camera
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();

    // Prepare persistent scans folder
    final appDir = await getApplicationDocumentsDirectory();
    scansDirectory = Directory("${appDir.path}/scans");

    if (!(await scansDirectory.exists())) {
      await scansDirectory.create(recursive: true);
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();

    // Unique file name
    final String filePath =
        "${scansDirectory.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg";

    // Save image to the scans folder
    await File(image.path).copy(filePath);

    if (!mounted) return;

    Flushbar(
      message: "Saved to scans folder:\n$filePath",
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      flushbarPosition: FlushbarPosition.TOP,
      backgroundColor: Colors.black87,
    ).show(context);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _initCamera,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_controller!.value.isInitialized) {
            return const Center(child: Text("Camera could not be initialized"));
          }

          return CameraPreview(_controller!);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
