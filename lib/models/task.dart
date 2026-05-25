class TaskStatus {
  final String taskId;
  final String status;
  final String stage;
  final int progress;
  final String message;
  final String sourceLang;
  final String targetLang;

  TaskStatus({
    required this.taskId,
    this.status = 'unknown',
    this.stage = '',
    this.progress = 0,
    this.message = '',
    this.sourceLang = 'English',
    this.targetLang = 'Chinese',
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isRunning => status == 'running' || status == 'queued';

  factory TaskStatus.fromJson(Map<String, dynamic> json) => TaskStatus(
        taskId: json['task_id'] as String,
        status: json['status'] as String? ?? 'unknown',
        stage: json['stage'] as String? ?? '',
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        message: json['message'] as String? ?? '',
        sourceLang: json['source_lang'] as String? ?? 'English',
        targetLang: json['target_lang'] as String? ?? 'Chinese',
      );
}
