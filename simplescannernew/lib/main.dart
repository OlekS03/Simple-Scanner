import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/edit_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainTabs(),
    );
  }
}

class MainTabs extends StatefulWidget {
  @override
  _MainTabsState createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    CameraPage(),
    EditPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: Text("Simple Scanner")),
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),

        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera), label: "Camera"),
          BottomNavigationBarItem(
              icon: Icon(Icons.edit), label: "Edit"),
        ],
      ),
    );
  }
}
