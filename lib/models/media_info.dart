class MediaInfo {
  final String title;
  final String thumbnailUrl;
  final Duration? duration;
  final List<MediaFormat> formats;
  final String source; // 'YouTube', 'Facebook', 'Instagram', etc.

  MediaInfo({
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    required this.formats,
    this.source = 'Unknown',
  });
}

class MediaFormat {
  final String formatName; // e.g., '1080p', '720p', 'Audio (MP3)'
  final String url;
  final String ext; // e.g., 'mp4', 'mp3'
  final int? sizeBytes;
  final dynamic streamInfo; // Holds YouTube StreamInfo for authenticated downloads

  MediaFormat({
    required this.formatName,
    required this.url,
    required this.ext,
    this.sizeBytes,
    this.streamInfo,
  });

  String get sizeString {
    if (sizeBytes == null || sizeBytes == 0) return 'Unknown size';
    if (sizeBytes! < 1024 * 1024) return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
