import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'pdf_viewer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<File> pdfFiles = [];
  late Directory pdfDir;

  GoogleSignInAccount? _currentUser;
  late GoogleSignIn _googleSignIn;

  // Track uploaded files to avoid duplicates
  Map<String, String> uploadedFileIds = {}; // local path -> Drive file ID

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );

    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        _syncPdfsToDrive();
      }
    });

    _googleSignIn.signInSilently();
    _loadPdfFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPdfsToDrive();
    }
  }

  Future<void> _loadPdfFiles() async {
    final docsDir = await getApplicationDocumentsDirectory();
    pdfDir = Directory("${docsDir.path}/pdfs");

    if (!(await pdfDir.exists())) {
      await pdfDir.create(recursive: true);
    }

    final List<FileSystemEntity> files = pdfDir.listSync();

    pdfFiles = files
        .where((f) => f.path.toLowerCase().endsWith(".pdf"))
        .map((f) => File(f.path))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {});

    // Sync after loading files
    _syncPdfsToDrive();
  }

  void _confirmDeletePdf(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete PDF"),
        content: Text("Are you sure you want to delete '${file.path.split("/").last}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              file.deleteSync();
              uploadedFileIds.remove(file.path); // Remove from uploaded tracking
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
    Share.shareXFiles([XFile(file.path)], text: "Simple Scanner PDF!");
  }

  void _openPdf(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(file: file),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      print("Google sign-in error: $e");
    }
  }

  Future<void> _logoutGoogle() async {
    await _googleSignIn.disconnect();
    setState(() {
      _currentUser = null;
      uploadedFileIds.clear();
    });
  }

  Future<void> _uploadPdfToDrive(File file) async {
    if (_currentUser == null) return;

    // Already uploaded?
    if (uploadedFileIds.containsKey(file.path)) return;

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    String folderId = await _getOrCreateFolder(driveApi, "Simple Scanner PDF");

    final pdfFile = drive.File()
      ..name = file.path.split("/").last
      ..parents = [folderId];

    final createdFile = await driveApi.files.create(
      pdfFile,
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );

    uploadedFileIds[file.path] = createdFile.id!;
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi, String folderName) async {
    final folderList = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$folderName'",
      spaces: 'drive',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    } else {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = "application/vnd.google-apps.folder";

      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id!;
    }
  }

  Future<void> _syncPdfsToDrive() async {
    if (_currentUser == null) return;

    for (final file in pdfFiles) {
      await _uploadPdfToDrive(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simple Scanner"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPdfFiles,
          ),
          _currentUser == null
              ? IconButton(
            icon: const Icon(Icons.login),
            onPressed: _loginWithGoogle,
          )
              : Row(
            children: [
              GestureDetector(
                onTap: _logoutGoogle,
                child: CircleAvatar(
                  backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ""),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: pdfFiles.isEmpty
          ? const Center(
        child: Text(
          "No PDF files found.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        itemCount: pdfFiles.length,
        itemBuilder: (context, index) {
          final file = pdfFiles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
              title: Text(
                file.path.split("/").last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                "Modified: ${file.lastModifiedSync().toLocal()}",
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _openPdf(file),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeletePdf(file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    onPressed: () => _sharePdf(file),
                  ),
                  if (_currentUser != null)
                    IconButton(
                      icon: const Icon(Icons.cloud_upload, color: Colors.green),
                      onPressed: () => _uploadPdfToDrive(file),
                    ),
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
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
