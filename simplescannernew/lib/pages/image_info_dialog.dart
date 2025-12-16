import 'dart:io';
import 'package:flutter/material.dart';

void showImageInfoDialog(BuildContext context, File file) async {
  final stat = await file.stat();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Image Info"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Name: ${file.path.split('/').last}"),
          Text("Size: ${(stat.size / 1024).toStringAsFixed(2)} KB"),
          Text("Modified: ${stat.modified}"),
          Text("Path: ${file.path}"),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}
