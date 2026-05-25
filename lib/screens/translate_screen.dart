import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import 'progress_screen.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  String? _filePath;
  String? _fileName;
  String _sourceLang = 'English';
  String _targetLang = 'Chinese';
  bool _uploading = false;
  double _uploadProgress = 0;

  static const _languages = [
    'English', 'Chinese', 'Japanese', 'Korean', 'French', 'German',
    'Spanish', 'Russian', 'Arabic', 'Portuguese', 'Italian', 'Dutch',
    'Turkish', 'Thai', 'Vietnamese',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _startTranslation() async {
    if (_filePath == null) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final api = context.read<ApiService>();
      final task = await api.uploadPdf(
        _filePath!,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProgressScreen(taskId: task.taskId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ApiService>().server;
    return Scaffold(
      appBar: AppBar(title: const Text('New Translation')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // Server info
        Card(
          child: ListTile(
            leading: const Icon(Icons.dns, color: Colors.green),
            title: Text('Connected to ${server?.displayLabel ?? ""}'),
            subtitle: Text(server?.baseUrl ?? ""),
          ),
        ),
        const SizedBox(height: 16),

        // File picker
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('PDF File', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_fileName != null)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(_fileName!),
                  trailing: TextButton(onPressed: _pickFile, child: const Text('Change')),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Select PDF File'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Languages
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Languages', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sourceLang,
                decoration: const InputDecoration(labelText: 'Source Language'),
                items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _sourceLang = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _targetLang,
                decoration: const InputDecoration(labelText: 'Target Language'),
                items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _targetLang = v!),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // Upload progress / start button
        if (_uploading)
          Column(children: [
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 8),
            Text('Uploading... ${(_uploadProgress * 100).toInt()}%'),
          ])
        else
          FilledButton.icon(
            onPressed: _filePath == null ? null : _startTranslation,
            icon: const Icon(Icons.translate),
            label: const Text('Start Translation'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
      ]),
    );
  }
}
