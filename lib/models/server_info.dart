class ServerInfo {
  final String host;
  final int port;
  final String? name;
  final DateTime savedAt;

  ServerInfo({
    required this.host,
    required this.port,
    this.name,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  String get baseUrl => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port';
  String get displayLabel => name ?? '$host:$port';

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'name': name,
        'saved_at': savedAt.toIso8601String(),
      };

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        host: json['host'] as String,
        port: json['port'] as int,
        name: json['name'] as String?,
        savedAt: DateTime.tryParse(json['saved_at'] as String? ?? ''),
      );

  factory ServerInfo.fromUrl(String url) {
    final uri = Uri.parse(url);
    return ServerInfo(host: uri.host, port: uri.port != 0 ? uri.port : 8654);
  }
}
