import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_info.dart';
import 'cobalt_api_service.dart';

class MediaExtractor {
  static final _yt = YoutubeExplode();

  /// List of supported platforms and their URL patterns
  static const _supportedPlatforms = {
    'YouTube': ['youtube.com', 'youtu.be'],
    'Facebook': ['facebook.com', 'fb.watch', 'fb.com'],
    'Instagram': ['instagram.com', 'instagr.am'],
    'Twitter/X': ['twitter.com', 'x.com'],
    'TikTok': ['tiktok.com'],
  };

  static Future<MediaInfo> extract(String url) async {
    final platform = _detectPlatform(url);

    switch (platform) {
      case 'YouTube':
        return _extractYouTube(url);
      case 'Facebook':
      case 'Instagram':
      case 'Twitter/X':
      case 'TikTok':
        // Use Cobalt API for all non-YouTube platforms
        return CobaltApiService.extract(url);
      default:
        throw Exception(
          'Unsupported URL. Supported platforms: YouTube, Facebook, Instagram, Twitter/X, TikTok.',
        );
    }
  }

  /// Detects the platform from a given URL.
  static String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    for (final entry in _supportedPlatforms.entries) {
      for (final pattern in entry.value) {
        if (lower.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return 'Unknown';
  }

  static Future<MediaInfo> _extractYouTube(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      List<MediaFormat> formats = [];

      // Add muxed (Video + Audio) streams
      for (final stream in manifest.muxed) {
        formats.add(
          MediaFormat(
            formatName:
                '${stream.videoQuality.name} (${stream.container.name})',
            url: stream.url.toString(),
            ext: stream.container.name,
            sizeBytes: stream.size.totalBytes,
            streamInfo: stream,
          ),
        );
      }

      // Add video-only streams (higher quality options)
      for (final stream in manifest.videoOnly) {
        formats.add(
          MediaFormat(
            formatName:
                '${stream.videoQuality.name} Video Only (${stream.container.name})',
            url: stream.url.toString(),
            ext: stream.container.name,
            sizeBytes: stream.size.totalBytes,
            streamInfo: stream,
          ),
        );
      }

      // Add audio-only streams
      for (final stream in manifest.audioOnly) {
        formats.add(
          MediaFormat(
            formatName:
                'Audio ${stream.bitrate.kiloBitsPerSecond.toStringAsFixed(0)}kbps (${stream.container.name})',
            url: stream.url.toString(),
            ext: stream.container.name,
            sizeBytes: stream.size.totalBytes,
            streamInfo: stream,
          ),
        );
      }

      // Get thumbnail - use a safe approach
      String thumbnailUrl = '';
      try {
        thumbnailUrl = video.thumbnails.highResUrl;
      } catch (_) {
        try {
          thumbnailUrl = video.thumbnails.mediumResUrl;
        } catch (_) {
          thumbnailUrl =
              'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
        }
      }

      return MediaInfo(
        title: video.title,
        thumbnailUrl: thumbnailUrl,
        duration: video.duration,
        formats: formats,
        source: 'YouTube',
      );
    } catch (e) {
      throw Exception('Failed to extract YouTube video: $e');
    }
  }
}
