import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import 'translate_screen.dart';

const _downloadsChannel = MethodChannel('com.hjdd14.ai_pdf_trans/downloads');

class ResultScreen extends StatefulWidget {
  final String taskId;
  const ResultScreen({super.key, required this.taskId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  TaskStatus? _task;
  bool _loading = true;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _savedPath;
  String? _downloadError;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() { _loading = true; _fetchError = null; });
    try {
      final api = context.read<ApiService>();
      final task = await api.getTask(widget.taskId);
      if (mounted) setState(() { _task = task; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _fetchError = '$e'; });
    }
  }

  Future<void> _download() async {
    setState(() { _downloading = true; _downloadProgress = 0; _downloadError = null; });
    try {
      // Step 1: Download to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'translated_${widget.taskId.substring(0, 8)}.pdf';
      final tempPath = '${tempDir.path}/$fileName';
      final api = context.read<ApiService>();
      await api.downloadPdf(
        widget.taskId,
        tempPath,
        onProgress: (received, total) {
          if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
        },
      );

      // Step 2: Save to public Downloads folder via platform channel
      String displayPath;
      try {
        displayPath = await _downloadsChannel.invokeMethod<String>('saveToDownloads', {
          'sourcePath': tempPath,
          'fileName': fileName,
        }) as String;
        // Clean up temp file
        try { await File(tempPath).delete(); } catch (_) {}
      } catch (e) {
        // Fallback: keep in temp dir if platform channel fails
        displayPath = tempPath;
      }

      if (mounted) setState(() { _savedPath = displayPath; _downloading = false; });
    } catch (e) {
      if (mounted) setState(() { _downloadError = '$e'; _downloading = false; });
    }
  }

  Future<void> _share() async {
    if (_savedPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_savedPath!)],
        subject: 'Translated PDF',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  Future<void> _open() async {
    if (_savedPath == null) return;
    try {
      await OpenFilex.open(_savedPath!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load task status', style: TextStyle(fontSize: 18)),
              if (_fetchError != null) ...[
                const SizedBox(height: 12),
                Text(_fetchError!, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _fetchStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ]),
          ),
        ),
      );
    }

    final task = _task!;
    final isSuccess = task.isCompleted;
    final isFailed = task.isFailed || task.isCancelled;
    final hasFile = _savedPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              size: 80,
              color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
            ),
            const SizedBox(height: 24),
            Text(
              isSuccess ? 'Translation Complete!' : (task.isCancelled ? 'Cancelled' : 'Failed'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(task.message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 32),

            if (_downloading) ...[
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text('Downloading... ${(_downloadProgress * 100).toInt()}%'),
            ] else if (hasFile) ...[
              // File saved to Downloads — show path + actions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _savedPath!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                OutlinedButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ]),
            ] else if (_downloadError != null) ...[
              Text(_downloadError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Download'),
              ),
            ] else ...[
              // Initial state — download button
              if (isSuccess)
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Download & Open PDF'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
            ],

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const TranslateScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('New Translation'),
            ),
          ]),
        ),
      ),
    );
  }
}
