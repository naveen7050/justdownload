import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_info.dart';

/// Service that uses the Cobalt API to extract video download URLs
/// from platforms like Facebook, Instagram, Twitter, etc.
///
/// Cobalt is an open-source media downloader: https://github.com/imputnet/cobalt
/// Instance list sourced from: https://cobalt.directory/api/working?type=api
class CobaltApiService {
  // Verified working community Cobalt API instances (from cobalt.directory).
  // These are the actual API endpoints, not frontend URLs.
  // Ordered by reliability score for Facebook + Instagram support.
  static const List<String> _fallbackInstances = [
    'https://nuko-c.meowing.de',
    'https://subito-c.meowing.de',
    'https://lime.clxxped.lol',
    'https://dog.kittycat.boo',
    'https://cobaltapi.kittycat.boo',
    'https://cobaltapi.squair.xyz',
    'https://api.dl.woof.monster',
    'https://grapefruit.clxxped.lol',
    'https://melon.clxxped.lol',
    'https://nachos.imput.net',
    'https://sunny.imput.net',
    'https://kityune.imput.net',
    'https://apicobalt.mgytr.top',
    'https://api.cobalt.liubquanti.click',
    'https://api.qwkuns.me',
    'https://cobaltapi.cjs.nz',
    'https://fox.kittycat.boo',
    'https://api.cobalt.blackcat.sweeux.org',
  ];

  /// Cached list of instances fetched dynamically from cobalt.directory.
  static List<String>? _cachedInstances;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 30);

  /// Gets the best instances for a given platform by querying cobalt.directory.
  /// Falls back to the hardcoded list if the directory is unreachable.
  static Future<List<String>> _getInstances(String platform) async {
    // Check cache validity
    if (_cachedInstances != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedInstances!;
    }

    try {
      final response = await http
          .get(Uri.parse('https://cobalt.directory/api/working?type=api'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;

        // Get instances that work for the requested platform
        final platformKey = _platformToServiceKey(platform);
        final instances =
            (data[platformKey] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];

        if (instances.isNotEmpty) {
          _cachedInstances = instances;
          _cacheTime = DateTime.now();
          return instances;
        }
      }
    } catch (_) {
      // Directory unreachable, use fallback
    }

    return _fallbackInstances;
  }

  /// Maps platform name to cobalt.directory service key.
  static String _platformToServiceKey(String platform) {
    switch (platform) {
      case 'Facebook':
        return 'facebook';
      case 'Instagram':
        return 'instagram';
      case 'Twitter/X':
        return 'twitter';
      case 'TikTok':
        return 'tiktok';
      default:
        return platform.toLowerCase();
    }
  }

  /// Extracts media info from a URL using the Cobalt API.
  /// Dynamically fetches working instances and tries them in order.
  static Future<MediaInfo> extract(String url) async {
    final platform = _detectPlatform(url);
    final instances = await _getInstances(platform);
    Exception? lastError;

    for (final instance in instances) {
      try {
        return await _tryExtract(instance, url, platform);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Try next instance
        continue;
      }
    }

    throw lastError ??
        Exception(
          'All Cobalt API instances failed for $platform. Please try again later.',
        );
  }

  static Future<MediaInfo> _tryExtract(
    String apiBase,
    String url,
    String platform,
  ) async {
    final List<MediaFormat> allFormats = [];
    String title = '$platform Video';

    // Get the best available video
    final mainResult = await _makeRequest(apiBase, url, videoQuality: 'max');

    if (mainResult['status'] == 'error') {
      final errorCode = mainResult['error']?['code'] ?? 'unknown';
      throw Exception(
        'Failed to extract $platform video: $errorCode. The video may be private, age-restricted, or the link is invalid.',
      );
    }

    // Extract title from filename if available
    if (mainResult['filename'] != null) {
      title = _cleanFilename(mainResult['filename']);
    }

    if (mainResult['status'] == 'tunnel' ||
        mainResult['status'] == 'redirect') {
      final downloadUrl = mainResult['url'] as String;
      final filename = mainResult['filename'] as String? ?? 'video.mp4';
      final ext = _getExtension(filename);

      allFormats.add(
        MediaFormat(
          formatName: 'Best Quality ($ext)',
          url: downloadUrl,
          ext: ext,
        ),
      );
    } else if (mainResult['status'] == 'picker') {
      // Multiple items (e.g., carousel posts on Instagram)
      final picker = mainResult['picker'] as List<dynamic>;
      int index = 1;
      for (final item in picker) {
        final itemUrl = item['url'] as String;
        final type = item['type'] as String? ?? 'video';
        final ext = type == 'photo' ? 'jpg' : 'mp4';
        allFormats.add(
          MediaFormat(
            formatName: '$type #$index ($ext)',
            url: itemUrl,
            ext: ext,
          ),
        );
        index++;
      }

      // Background audio (e.g., TikTok slideshows)
      if (mainResult['audio'] != null) {
        allFormats.add(
          MediaFormat(
            formatName: 'Background Audio (mp3)',
            url: mainResult['audio'] as String,
            ext: 'mp3',
          ),
        );
      }
    }

    // Run audio-only and SD quality requests IN PARALLEL for speed
    final futures = await Future.wait([
      _makeRequest(apiBase, url, downloadMode: 'audio')
          .timeout(const Duration(seconds: 10))
          .catchError((_) => <String, dynamic>{}),
      _makeRequest(apiBase, url, videoQuality: '480')
          .timeout(const Duration(seconds: 10))
          .catchError((_) => <String, dynamic>{}),
    ]);

    final audioResult = futures[0];
    final sdResult = futures[1];

    // Process audio result
    if (audioResult.isNotEmpty &&
        (audioResult['status'] == 'tunnel' ||
            audioResult['status'] == 'redirect')) {
      final audioUrl = audioResult['url'] as String;
      final audioFilename = audioResult['filename'] as String? ?? 'audio.mp3';
      final audioExt = _getExtension(audioFilename);

      if (!allFormats.any((f) => f.url == audioUrl)) {
        allFormats.add(
          MediaFormat(
            formatName: 'Audio Only ($audioExt)',
            url: audioUrl,
            ext: audioExt,
          ),
        );
      }
    }

    // Process SD result
    if (sdResult.isNotEmpty &&
        (sdResult['status'] == 'tunnel' || sdResult['status'] == 'redirect')) {
      final sdUrl = sdResult['url'] as String;
      final sdFilename = sdResult['filename'] as String? ?? 'video.mp4';
      final sdExt = _getExtension(sdFilename);

      if (!allFormats.any((f) => f.url == sdUrl)) {
        allFormats.insert(
          allFormats.length > 1 ? 1 : allFormats.length,
          MediaFormat(
            formatName: 'SD Quality ($sdExt)',
            url: sdUrl,
            ext: sdExt,
          ),
        );
      }
    }

    if (allFormats.isEmpty) {
      throw Exception(
        'No downloadable streams found for this $platform URL. The content may be private or unsupported.',
      );
    }

    // Fetch file sizes in parallel for all formats (non-blocking)
    final sizeFutures = allFormats.map((f) => _fetchFileSize(f.url)).toList();
    final sizes = await Future.wait(sizeFutures);

    final formatsWithSize = <MediaFormat>[];
    for (int i = 0; i < allFormats.length; i++) {
      formatsWithSize.add(
        MediaFormat(
          formatName: allFormats[i].formatName,
          url: allFormats[i].url,
          ext: allFormats[i].ext,
          sizeBytes: sizes[i],
          streamInfo: allFormats[i].streamInfo,
        ),
      );
    }

    return MediaInfo(
      title: title,
      thumbnailUrl: '',
      duration: null,
      formats: formatsWithSize,
      source: platform,
    );
  }

  /// Makes a single request to the Cobalt API.
  static Future<Map<String, dynamic>> _makeRequest(
    String apiBase,
    String url, {
    String videoQuality = '1080',
    String downloadMode = 'auto',
  }) async {
    final response = await http
        .post(
          Uri.parse(apiBase),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'url': url,
            'videoQuality': videoQuality,
            'downloadMode': downloadMode,
            'filenameStyle': 'pretty',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      throw Exception('Rate limited. Please try again in a moment.');
    } else {
      // Try to parse error body
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        if (errorBody['status'] == 'error') {
          return errorBody;
        }
      } catch (_) {}
      throw Exception('API request failed with status ${response.statusCode}');
    }
  }

  /// Detects the source platform from a URL.
  static String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('facebook.com') ||
        lower.contains('fb.watch') ||
        lower.contains('fb.com')) {
      return 'Facebook';
    } else if (lower.contains('instagram.com') ||
        lower.contains('instagr.am')) {
      return 'Instagram';
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'Twitter/X';
    } else if (lower.contains('tiktok.com')) {
      return 'TikTok';
    }
    return 'Social Media';
  }

  /// Gets file extension from filename.
  static String _getExtension(String filename) {
    final parts = filename.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'mp4';
  }

  /// Cleans a filename to extract a human-readable title.
  static String _cleanFilename(String filename) {
    // Remove extension
    final withoutExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Replace underscores and dashes with spaces
    final cleaned = withoutExt
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'Downloaded Video';
  }

  /// Fetches file size via HTTP HEAD request.
  /// Returns null if the size cannot be determined.
  static Future<int?> _fetchFileSize(String url) async {
    try {
      final request = http.Request('HEAD', Uri.parse(url));
      final streamed = await request.send().timeout(const Duration(seconds: 5));

      // Check Content-Length header
      final contentLength = streamed.headers['content-length'];
      if (contentLength != null) {
        return int.tryParse(contentLength);
      }

      // Check Estimated-Content-Length (Cobalt-specific header)
      final estimated = streamed.headers['estimated-content-length'];
      if (estimated != null) {
        return int.tryParse(estimated);
      }
    } catch (_) {
      // Size fetch failed, not critical
    }
    return null;
  }
}
