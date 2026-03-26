import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/media_info.dart';

class MediaExtractor {
  static final _yt = YoutubeExplode();

  static Future<MediaInfo> extract(String url) async {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _extractYouTube(url);
    } else if (url.contains('facebook.com') || url.contains('fb.watch') || url.contains('fb.com')) {
      return _extractFacebook(url);
    } else {
      throw Exception('Unsupported URL. Only YouTube and Facebook are supported.');
    }
  }

  static Future<MediaInfo> _extractYouTube(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      List<MediaFormat> formats = [];

      // Add muxed (Video + Audio) streams
      for (final stream in manifest.muxed) {
        formats.add(MediaFormat(
          formatName: '${stream.videoQuality.name} (${stream.container.name})',
          url: stream.url.toString(),
          ext: stream.container.name,
          sizeBytes: stream.size.totalBytes,
          streamInfo: stream,
        ));
      }

      // Add video-only streams (higher quality options)
      for (final stream in manifest.videoOnly) {
        formats.add(MediaFormat(
          formatName: '${stream.videoQuality.name} Video Only (${stream.container.name})',
          url: stream.url.toString(),
          ext: stream.container.name,
          sizeBytes: stream.size.totalBytes,
          streamInfo: stream,
        ));
      }

      // Add audio-only streams
      for (final stream in manifest.audioOnly) {
        formats.add(MediaFormat(
          formatName: 'Audio ${stream.bitrate.kiloBitsPerSecond.toStringAsFixed(0)}kbps (${stream.container.name})',
          url: stream.url.toString(),
          ext: stream.container.name,
          sizeBytes: stream.size.totalBytes,
          streamInfo: stream,
        ));
      }

      // Get thumbnail - use a safe approach
      String thumbnailUrl = '';
      try {
        thumbnailUrl = video.thumbnails.highResUrl;
      } catch (_) {
        try {
          thumbnailUrl = video.thumbnails.mediumResUrl;
        } catch (_) {
          thumbnailUrl = 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg';
        }
      }

      return MediaInfo(
        title: video.title,
        thumbnailUrl: thumbnailUrl,
        duration: video.duration,
        formats: formats,
      );
    } catch (e) {
      throw Exception('Failed to extract YouTube video: $e');
    }
  }

  static Future<MediaInfo> _extractFacebook(String url) async {
    try {
      String title = 'Facebook Video';
      String thumbnailUrl = '';
      List<MediaFormat> formats = [];

      // Fetch the page HTML to extract OG meta tags and video URLs
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final body = response.body;
        final document = html_parser.parse(body);

        // Extract OG meta tags
        final titleElement = document.querySelector('meta[property="og:title"]');
        if (titleElement != null) {
          title = titleElement.attributes['content'] ?? title;
        }

        final imageElement = document.querySelector('meta[property="og:image"]');
        if (imageElement != null) {
          thumbnailUrl = imageElement.attributes['content'] ?? '';
        }

        // Try to find video URLs in the page source
        // Look for HD video URL
        final hdPattern = RegExp(r'hd_src:"([^"]+)"');
        final hdMatch = hdPattern.firstMatch(body);
        if (hdMatch != null) {
          final hdUrl = hdMatch.group(1)!.replaceAll(r'\/', '/');
          formats.add(MediaFormat(
            formatName: 'HD Video (mp4)',
            url: hdUrl,
            ext: 'mp4',
          ));
        }

        // Look for SD video URL
        final sdPattern = RegExp(r'sd_src:"([^"]+)"');
        final sdMatch = sdPattern.firstMatch(body);
        if (sdMatch != null) {
          final sdUrl = sdMatch.group(1)!.replaceAll(r'\/', '/');
          formats.add(MediaFormat(
            formatName: 'SD Video (mp4)',
            url: sdUrl,
            ext: 'mp4',
          ));
        }

        // Alternative pattern
        if (formats.isEmpty) {
          final altPattern = RegExp(r'"playable_url(?:_quality_hd)?":"([^"]+)"');
          for (final match in altPattern.allMatches(body)) {
            final videoUrl = match.group(1)!.replaceAll(r'\/', '/').replaceAll(r'\\u0025', '%');
            final isHd = match.group(0)!.contains('quality_hd');
            formats.add(MediaFormat(
              formatName: isHd ? 'HD Video (mp4)' : 'SD Video (mp4)',
              url: videoUrl,
              ext: 'mp4',
            ));
          }
        }
      }

      if (formats.isEmpty) {
        throw Exception('Could not find downloadable video streams for this Facebook URL. The video may be private or the URL format is not supported.');
      }

      return MediaInfo(
        title: title,
        thumbnailUrl: thumbnailUrl,
        duration: null,
        formats: formats,
      );
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Failed to extract Facebook video: $e');
    }
  }
}
