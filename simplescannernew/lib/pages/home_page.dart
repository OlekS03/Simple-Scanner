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

class _HomePageState extends State<HomePage> {
  List<File> pdfFiles = [];
  late Directory pdfDir;

  GoogleSignInAccount? _currentUser;
  late GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();

    // Initialize Google Sign-In with Drive scope
    _googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );

    // Listen for login changes
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      if (account != null) {
        _uploadAllPdfsToDrive();
      }
      setState(() {}); // Refresh UI
    });

    // Try silent sign-in to remember user
    _googleSignIn.signInSilently();

    _loadPdfFiles();
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
  }

  void _confirmDeletePdf(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete PDF"),
        content: Text(
            "Are you sure you want to delete '${file.path.split("/").last}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              file.deleteSync();
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

  /// Login with Google
  Future<void> _loginWithGoogle() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      print("Google sign-in error: $e");
    }
  }

  /// Logout from Google
  Future<void> _logoutFromGoogle() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    setState(() {});
  }

  /// Upload a single PDF file to Google Drive into the folder "Simple Scanner PDF"
  Future<void> _uploadPdfToDrive(File file) async {
    if (_currentUser == null) return;

    final authHeaders = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    // Ensure folder exists
    String folderId = await _getOrCreateFolder(driveApi, "Simple Scanner PDF");

    // Upload file
    final pdfFile = drive.File()
      ..name = file.path.split("/").last
      ..parents = [folderId];

    await driveApi.files.create(
      pdfFile,
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );
  }

  /// Check if folder exists, create if not
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

  /// Upload all PDFs automatically (after login or app start)
  Future<void> _uploadAllPdfsToDrive() async {
    for (final file in pdfFiles) {
      await _uploadPdfToDrive(file);
    }
    print("All PDFs uploaded to Google Drive!");
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
              : GestureDetector(
            onTap: () {
              // Show logout option
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content:
                  const Text("Do you want to logout from Google?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        _logoutFromGoogle();
                        Navigator.pop(context);
                      },
                      child:
                      const Text("Logout", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ""),
              ),
            ),
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
            margin:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf,
                  size: 40, color: Colors.red),
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
                    icon:
                    const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeletePdf(file),
                  ),
                  IconButton(
                    icon:
                    const Icon(Icons.share, color: Colors.blue),
                    onPressed: () => _sharePdf(file),
                  ),
                  if (_currentUser != null)
                    IconButton(
                      icon: const Icon(Icons.cloud_upload,
                          color: Colors.green),
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

/// Helper class for authenticated HTTP client
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
