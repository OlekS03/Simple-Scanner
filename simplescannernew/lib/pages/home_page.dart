import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'pdf_viewer_page.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File> pdfFiles = [];
  late Directory pdfDir;

  GoogleSignInAccount? _currentUser;
  late GoogleSignIn _googleSignIn;

  final Map<String, String> uploadedFileIds = {};

  @override
  void initState() {
    super.initState();

    _googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );

    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() => _currentUser = account);
      if (account != null) _syncPdfsToDrive();
    });

    _googleSignIn.signInSilently();
    _loadPdfFiles();
  }

  Future<void> _loadPdfFiles() async {
    final docsDir = await getApplicationDocumentsDirectory();
    pdfDir = Directory("${docsDir.path}/pdfs");

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    pdfFiles = pdfDir
        .listSync()
        .where((f) => f.path.toLowerCase().endsWith(".pdf"))
        .map((f) => File(f.path))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {});
    _syncPdfsToDrive();
  }

  void _confirmDeletePdf(File file) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete PDF"),
        content: Text("Delete '${file.path.split("/").last}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              file.deleteSync();
              uploadedFileIds.remove(file.path);
              _loadPdfFiles();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _sharePdf(File file) {
    Share.shareXFiles([XFile(file.path)], text: "Simple Scanner PDF");
  }

  void _openPdf(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerPage(file: file)),
    );
  }

  Future<void> _login() async => await _googleSignIn.signIn();
  Future<void> _logout() async => await _googleSignIn.disconnect();

  Future<void> _uploadPdf(File file) async {
    if (_currentUser == null || uploadedFileIds.containsKey(file.path)) return;

    final client = GoogleAuthClient(await _currentUser!.authHeaders);
    final api = drive.DriveApi(client);

    final folderId = await _getOrCreateFolder(api, "Simple Scanner PDF");

    final uploaded = await api.files.create(
      drive.File()
        ..name = file.uri.pathSegments.last
        ..parents = [folderId],
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );

    uploadedFileIds[file.path] = uploaded.id!;
  }

  Future<String> _getOrCreateFolder(drive.DriveApi api, String name) async {
    final result = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$name'",
    );

    if (result.files!.isNotEmpty) return result.files!.first.id!;

    final folder = await api.files.create(
      drive.File()
        ..name = name
        ..mimeType = "application/vnd.google-apps.folder",
    );

    return folder.id!;
  }

  Future<void> _syncPdfsToDrive() async {
    for (final file in pdfFiles) {
      await _uploadPdf(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simple Scanner"),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPdfFiles,
          ),
          _currentUser == null
              ? IconButton(icon: const Icon(Icons.login), onPressed: _login)
              : GestureDetector(
            onTap: _logout,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                backgroundImage:
                NetworkImage(_currentUser!.photoUrl ?? ""),
              ),
            ),
          ),
        ],
      ),
      body: pdfFiles.isEmpty
          ? const Center(child: Text("No PDF files found"))
          : ListView.builder(
        itemCount: pdfFiles.length,
        itemBuilder: (_, i) {
          final file = pdfFiles[i];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(file.uri.pathSegments.last),
              subtitle:
              Text(file.lastModifiedSync().toLocal().toString()),
              onTap: () => _openPdf(file),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _sharePdf(file)),
                  IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDeletePdf(file)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this.headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(headers));
  }
}
