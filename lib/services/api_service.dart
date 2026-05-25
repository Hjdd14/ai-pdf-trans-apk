import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/server_info.dart';
import '../models/task.dart';

class ApiService extends ChangeNotifier {
  ServerInfo? _server;
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 30)));

  ServerInfo? get server => _server;
  bool get isConnected => _server != null;

  Future<bool> testConnection(ServerInfo server) async {
    try {
      final resp = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)))
          .get('${server.baseUrl}/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect(ServerInfo server) async {
    _server = server;
    notifyListeners();
  }

  void disconnect() {
    _server = null;
    notifyListeners();
  }

  Future<TaskStatus> uploadPdf(
    String filePath, {
    String sourceLang = 'English',
    String targetLang = 'Chinese',
    void Function(int, int)? onProgress,
  }) async {
    if (_server == null) throw Exception('Not connected');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'source.pdf'),
      'source_lang': sourceLang,
      'target_lang': targetLang,
    });

    final resp = await _dio.post(
      '${_server!.baseUrl}/translate',
      data: formData,
      onSendProgress: onProgress,
    );

    return TaskStatus.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TaskStatus> getTask(String taskId) async {
    if (_server == null) throw Exception('Not connected');
    final resp = await _dio.get('${_server!.baseUrl}/tasks/$taskId');
    return TaskStatus.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> cancelTask(String taskId) async {
    if (_server == null) throw Exception('Not connected');
    await _dio.delete('${_server!.baseUrl}/tasks/$taskId');
  }

  Future<String> downloadPdf(String taskId, String savePath, {void Function(int, int)? onProgress}) async {
    if (_server == null) throw Exception('Not connected');
    await _dio.download(
      '${_server!.baseUrl}/tasks/$taskId/download',
      savePath,
      onReceiveProgress: onProgress,
    );
    return savePath;
  }

  WebSocketChannel connectWs(String taskId) {
    if (_server == null) throw Exception('Not connected');
    return WebSocketChannel.connect(Uri.parse('${_server!.wsUrl}/tasks/$taskId/ws'));
  }
}
