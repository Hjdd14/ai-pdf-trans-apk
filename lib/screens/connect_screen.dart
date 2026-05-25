import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/server_info.dart';
import 'translate_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController(text: '192.168.');
  final _portController = TextEditingController(text: '8654');
  List<ServerInfo> _savedServers = [];
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  void _loadSaved() {
    final storage = context.read<StorageService>();
    setState(() => _savedServers = storage.loadServers());
  }

  Future<void> _testAndConnect() async {
    final host = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8654;
    if (host.isEmpty) return;

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final server = ServerInfo(host: host, port: port);
    final api = context.read<ApiService>();
    final ok = await api.testConnection(server);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testResult = ok ? 'Connected!' : 'Cannot reach server';
    });

    if (ok) {
      await api.connect(server);
      await context.read<StorageService>().saveServer(server);
      _loadSaved();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TranslateScreen()));
    }
  }

  void _onQrScan(String? raw) {
    if (raw == null) return;
    try {
      final uri = Uri.parse(raw);
      if (uri.host.isNotEmpty) {
        setState(() {
          _showScanner = false;
          _ipController.text = uri.host;
          _portController.text = (uri.port != 0 ? uri.port : 8654).toString();
        });
        _testAndConnect();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) return _buildScanner();

    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // QR scan button
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner, size: 32),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Scan the QR code shown on desktop'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _showScanner = true),
            ),
          ),
          const SizedBox(height: 16),

          // Manual entry
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Manual Entry', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(labelText: 'IP Address', hintText: '192.168.1.100', prefixIcon: Icon(Icons.computer)),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: 'Port', prefixIcon: Icon(Icons.settings_ethernet)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _testing ? null : _testAndConnect,
                    icon: _testing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(_testing ? 'Testing...' : 'Connect & Test'),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(_testOk ? Icons.check_circle : Icons.error, color: _testOk ? Colors.green : Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(_testResult!, style: TextStyle(color: _testOk ? Colors.green : Colors.red)),
                    ]),
                    if (!_testOk) ...[
                      const SizedBox(height: 8),
                      const Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                      const Text('1. Phone and PC on same WiFi?', style: TextStyle(fontSize: 12)),
                      const Text('2. Firewall allowing port?', style: TextStyle(fontSize: 12)),
                      const Text('3. IP address correct?', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Saved servers
          if (_savedServers.isNotEmpty) ...[
            Text('Saved Servers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...(_savedServers.map((s) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(s.displayLabel),
                    subtitle: Text('${s.host}:${s.port}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        await context.read<StorageService>().removeServer(s.host, s.port);
                        _loadSaved();
                      },
                    ),
                    onTap: () {
                      _ipController.text = s.host;
                      _portController.text = s.port.toString();
                      _testAndConnect();
                    },
                  ),
                ))),
          ],
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code'), actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showScanner = false)),
      ]),
      body: MobileScanner(onDetect: (capture) {
        final barcode = capture.barcodes.firstOrNull;
        if (barcode?.rawValue != null) {
          _onQrScan(barcode!.rawValue);
        }
      }),
    );
  }
}
