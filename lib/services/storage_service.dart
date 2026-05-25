import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_info.dart';

class StorageService {
  static const _serversKey = 'saved_servers';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<ServerInfo> loadServers() {
    final raw = _prefs?.getStringList(_serversKey);
    if (raw == null || raw.isEmpty) return [];
    return raw
        .map((s) => ServerInfo.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveServer(ServerInfo server) async {
    final servers = loadServers();
    servers.removeWhere((s) => s.host == server.host && s.port == server.port);
    servers.insert(0, server);
    if (servers.length > 10) servers.removeRange(10, servers.length);
    await _prefs?.setStringList(
      _serversKey,
      servers.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<void> removeServer(String host, int port) async {
    final servers = loadServers();
    servers.removeWhere((s) => s.host == host && s.port == port);
    await _prefs?.setStringList(
      _serversKey,
      servers.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }
}
