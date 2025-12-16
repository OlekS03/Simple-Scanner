import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatelessWidget {
  final File file;

  const PdfViewerPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final pdfController = PdfController(
      document: PdfDocument.openFile(file.path),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(file.path.split("/").last),
      ),
      body: PdfView(
        controller: pdfController,
      ),
    );
  }
}
