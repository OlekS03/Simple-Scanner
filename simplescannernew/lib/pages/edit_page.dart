import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'image_edit_page.dart';
import 'image_info_dialog.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  List<File> images = [];
  Set<File> selectedImages = {};

  late Directory scansDir;
  late Directory pdfDir;

  @override
  void initState() {
    super.initState();
    _setupFolders();
  }

  Future<void> _setupFolders() async {
    final appDir = await getApplicationDocumentsDirectory();

    scansDir = Directory("${appDir.path}/scans");
    pdfDir = Directory("${appDir.path}/pdfs");

    if (!await scansDir.exists()) await scansDir.create(recursive: true);
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    _loadImages();
  }

  void _loadImages() {
    images = scansDir
        .listSync()
        .where((f) => f.path.endsWith(".jpg"))
        .map((f) => File(f.path))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {});
  }

  void _toggleSelect(File file) {
    setState(() {
      selectedImages.contains(file)
          ? selectedImages.remove(file)
          : selectedImages.add(file);
    });
  }

  Future<void> _confirmDelete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Image"),
        content: const Text("Are you sure you want to delete this image?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await file.delete();
      selectedImages.remove(file);
      _loadImages();
    }
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final temp = images[index - 1];
      images[index - 1] = images[index];
      images[index] = temp;
    });
  }

  void _moveDown(int index) {
    if (index >= images.length - 1) return;
    setState(() {
      final temp = images[index + 1];
      images[index + 1] = images[index];
      images[index] = temp;
    });
  }

  Future<void> _combineSelected() async {
    if (selectedImages.isEmpty) return;

    String? pdfName = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempName = "";
        return AlertDialog(
          title: const Text("Enter PDF name"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "PDF name"),
            onChanged: (value) => tempName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempName),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (pdfName == null || pdfName.trim().isEmpty) return;

    final pdf = pw.Document();

    // Only include selected images in current order
    final files = images.where((img) => selectedImages.contains(img)).toList();

    for (final imgFile in files) {
      final bytes = await imgFile.readAsBytes();
      final image = pw.MemoryImage(Uint8List.fromList(bytes));

      // Force a new page for each image and scale proportionally
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              width: PdfPageFormat.a4.width,
              height: PdfPageFormat.a4.height,
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(image),
              ),
            );
          },
        ),
      );
    }

    final path = "${pdfDir.path}/$pdfName.pdf";
    await File(path).writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved:\n$path")),
    );

    setState(() => selectedImages.clear());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: images.isEmpty
          ? const Center(child: Text("No saved pictures found."))
          : ListView.builder(
        itemCount: images.length,
        itemBuilder: (_, index) {
          final file = images[index];
          final selected = selectedImages.contains(file);

          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () => _moveUp(index),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: () => _moveDown(index),
                    ),
                  ),
                ],
              ),
              title: null, // remove text in the middle
              subtitle: Image.file(
                file,
                key: UniqueKey(),
                width: 200,
                height: 200,
                fit: BoxFit.fitHeight, // keep aspect ratio
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelect(file),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final updated =
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ImageEditPage(imageFile: file),
                          ),
                        );

                        if (updated == true) _loadImages();
                      }
                      if (value == 'info') {
                        showImageInfoDialog(context, file);
                      }
                      if (value == 'delete') {
                        _confirmDelete(file);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'info',
                        child: Text('Info'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text("Combine into PDF"),
          onPressed: _combineSelected,
        ),
      ),
    );
  }
}