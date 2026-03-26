class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String savedDir;
  final String fileName;
  final String format;
  final String type; // 'Video' or 'Audio'
  final DateTime date;
  final String taskId;
  final int progress;
  final DownloadStatus status;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.savedDir,
    required this.fileName,
    required this.format,
    required this.type,
    required this.date,
    this.taskId = '',
    this.progress = 0,
    this.status = DownloadStatus.queued,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'savedDir': savedDir,
      'fileName': fileName,
      'format': format,
      'type': type,
      'date': date.toIso8601String(),
      'taskId': taskId,
      'progress': progress,
      'status': status.index,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      savedDir: map['savedDir'],
      fileName: map['fileName'],
      format: map['format'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      taskId: map['taskId'],
      progress: map['progress'],
      status: DownloadStatus.values[map['status']],
    );
  }

  DownloadItem copyWith({
    String? id,
    String? title,
    String? url,
    String? savedDir,
    String? fileName,
    String? format,
    String? type,
    DateTime? date,
    String? taskId,
    int? progress,
    DownloadStatus? status,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      savedDir: savedDir ?? this.savedDir,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      type: type ?? this.type,
      date: date ?? this.date,
      taskId: taskId ?? this.taskId,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

enum DownloadStatus {
  queued,
  running,
  completed,
  failed,
  canceled,
}
