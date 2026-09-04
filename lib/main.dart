import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String BACKEND_URL = "https://video-editor-agent.onrender.com";

void main() => runApp(const VideoEditorApp());

class VideoEditorApp extends StatelessWidget {
  const VideoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Video Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const EditorHomePage(),
    );
  }
}

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key});

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  File? _pickedVideo;
  bool _isProcessing = false;
  String? _resultUrl;
  String? _statusMessage;

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _pickedVideo = File(video.path);
        _resultUrl = null;
        _statusMessage = null;
      });
    }
  }

  Future<void> _uploadAndEdit() async {
    if (_pickedVideo == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Video edit ho rahi hai... (thoda time lagega)";
    });

    try {
      final uri = Uri.parse("$BACKEND_URL/edit");
      final request = http.MultipartRequest("POST", uri);
      request.files.add(
        await http.MultipartFile.fromPath("file", _pickedVideo!.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final downloadPath = _extractDownloadUrl(response.body);
        setState(() {
          _resultUrl = "$BACKEND_URL$downloadPath";
          _statusMessage = "Ho gaya! Silence hata di gayi.";
        });
      } else {
        setState(() => _statusMessage = "Error: ${response.body}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Kuch gadbad ho gayi: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _extractDownloadUrl(String jsonBody) {
    final match = RegExp(r'"download_url":\s*"([^"]+)"').firstMatch(jsonBody);
    return match?.group(1) ?? "";
  }

  Future<void> _openDownload() async {
    if (_resultUrl == null) return;
    final uri = Uri.parse(_resultUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Video Editor"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_pickedVideo != null)
              Text(
                "Selected: ${_pickedVideo!.path.split('/').last}",
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text("Video Chuno"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(220, 50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_pickedVideo != null && !_isProcessing)
                  ? _uploadAndEdit
                  : null,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text("Auto-Edit Karo"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(220, 50),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            if (_isProcessing) const CircularProgressIndicator(),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(_statusMessage!, textAlign: TextAlign.center),
            ],
            if (_resultUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openDownload,
                icon: const Icon(Icons.download),
                label: const Text("Edited Video Dekho / Download Karo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
