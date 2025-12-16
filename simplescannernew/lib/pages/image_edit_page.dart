import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';

class ImageEditPage extends StatefulWidget {
  final File imageFile;

  const ImageEditPage({super.key, required this.imageFile});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  double brightness = 0.0; // -1 .. 1
  double contrast = 1.0;   // 0.5 .. 2

  late File workingFile;

  @override
  void initState() {
    super.initState();
    workingFile = widget.imageFile;
  }

  /// 🎯 SAME math as before (ColorMatrix)
  List<double> _colorMatrix() {
    final b = brightness * 255;
    final c = contrast;

    return [
      c, 0, 0, 0, b,
      0, c, 0, 0, b,
      0, 0, c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  /// 🔥 Apply ColorMatrix to pixels (matches preview)
  img.Image _applyMatrix(img.Image src, List<double> m) {
    final out = img.Image.from(src);

    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);

        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final a = p.a.toDouble();

        final nr = (m[0] * r + m[4]).clamp(0, 255);
        final ng = (m[6] * g + m[9]).clamp(0, 255);
        final nb = (m[12] * b + m[14]).clamp(0, 255);

        out.setPixelRgba(
          x,
          y,
          nr.toInt(),
          ng.toInt(),
          nb.toInt(),
          a.toInt(),
        );
      }
    }

    return out;
  }

  Future<void> _cropImage() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: workingFile.path,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (cropped != null) {
      setState(() {
        workingFile = File(cropped.path);
      });
    }
  }

  Future<void> _saveImage() async {
    final bytes = await workingFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final edited = _applyMatrix(decoded, _colorMatrix());

    final provider = FileImage(widget.imageFile);
    await provider.evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    await widget.imageFile.writeAsBytes(
      img.encodeJpg(edited, quality: 95),
      flush: true,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Image")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_colorMatrix()),
                child: Image.file(
                  workingFile,
                  key: ValueKey('${workingFile.path}-${brightness}-${contrast}'),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Brightness"),
                Slider(
                  min: -1,
                  max: 1,
                  divisions: 20,
                  value: brightness,
                  onChanged: (v) => setState(() => brightness = v),
                ),

                const Text("Contrast"),
                Slider(
                  min: 0.5,
                  max: 2,
                  divisions: 15,
                  value: contrast,
                  onChanged: (v) => setState(() => contrast = v),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.crop),
                        label: const Text("Crop"),
                        onPressed: _cropImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Save"),
                        onPressed: _saveImage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
