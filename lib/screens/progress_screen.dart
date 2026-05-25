import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class ProgressScreen extends StatefulWidget {
  final String taskId;
  const ProgressScreen({super.key, required this.taskId});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _stage = '';
  int _progress = 0;
  String _message = 'Starting...';
  String _status = 'running';
  WebSocketChannel? _channel;
  Timer? _pollTimer;
  DateTime _lastWsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _connectWs();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || _status != 'running') return;

      // Only poll if WebSocket hasn't sent updates recently
      if (DateTime.now().difference(_lastWsUpdate).inSeconds < 3) return;

      try {
        final task = await context.read<ApiService>().getTask(widget.taskId);
        if (!mounted) return;
        setState(() {
          _stage = task.stage ?? _stage;
          _progress = task.progress ?? _progress;
          _message = task.message ?? _message;
          _status = task.status ?? _status;
        });
        if (task.status == 'completed' ||
            task.status == 'failed' ||
            task.status == 'cancelled') {
          _navigateToResult();
        }
      } catch (_) {
        // Poll errors are expected if WebSocket is working fine
      }
    });
  }

  void _connectWs() {
    try {
      final api = context.read<ApiService>();
      _channel = api.connectWs(widget.taskId);
      _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          _lastWsUpdate = DateTime.now();
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;
          if (type == 'progress') {
            setState(() {
              _stage = msg['stage'] as String? ?? _stage;
              _progress = (msg['progress'] as num?)?.toInt() ?? _progress;
              _message = msg['message'] as String? ?? _message;
            });
          } else if (type == 'completed') {
            setState(() => _status = 'completed');
            _navigateToResult();
          } else if (type == 'error') {
            setState(() {
              _status = 'failed';
              _message = msg['message'] as String? ?? 'Unknown error';
            });
            _navigateToResult();
          } else if (type == 'cancelled') {
            setState(() => _status = 'cancelled');
            _navigateToResult();
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _status = 'failed';
              _message = 'Connection lost';
            });
            // Don't navigate immediately — polling might recover status
          }
        },
        onDone: () {
          // Don't navigate on done — polling might still get status
        },
      );
    } catch (_) {
      setState(() {
        _status = 'failed';
        _message = 'Could not connect to server';
      });
    }
  }

  void _navigateToResult() {
    _pollTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(taskId: widget.taskId)),
      );
    });
  }

  Future<void> _cancel() async {
    try {
      await context.read<ApiService>().cancelTask(widget.taskId);
      setState(() => _status = 'cancelled');
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  String get _stageLabel {
    switch (_stage) {
      case 'agent_started':
        return 'Initializing agent...';
      case 'agent_running':
        return 'Analyzing PDF...';
      case 'tool_call':
        return 'Extracting content...';
      case 'done':
        return 'Complete!';
      default:
        return _message.isNotEmpty ? _message : 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translation Progress')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status icon
              if (_status == 'running') ...[
                const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 4)),
                const SizedBox(height: 24),
              ] else if (_status == 'completed') ...[
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 24),
              ] else if (_status == 'cancelled') ...[
                const Icon(Icons.cancel, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
              ] else ...[
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 24),
              ],

              // Stage label
              Text(_stageLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text('$_progress%',
                  style: Theme.of(context).textTheme.bodySmall),

              const SizedBox(height: 24),

              // Message
              Text(_message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),

              const SizedBox(height: 32),

              // Cancel
              if (_status == 'running')
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel Translation'),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
