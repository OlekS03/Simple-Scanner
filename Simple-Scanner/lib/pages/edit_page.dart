import 'package:flutter/material.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "✏️ Edit Page",
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    );
  }
}
