import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';
import '../models/media_info.dart';
import 'history_service.dart';

class DownloadService {
  static final Dio _dio = Dio();
  static final YoutubeExplode _yt = YoutubeExplode();

  // Active downloads tracked by their item ID
  static final Map<String, CancelToken> _cancelTokens = {};
  static final Map<String, ValueNotifier<double>> _progressNotifiers = {};

  static ValueNotifier<double>? getProgressNotifier(String id) => _progressNotifiers[id];

  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      // For Android 13+
      final videosStatus = await Permission.videos.request();
      if (videosStatus.isGranted) return true;

      // If both denied, try manage external storage
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;

      return false;
    }
    return true;
  }

  static Future<String> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final targetDir = Directory('${directory!.path}/justDownload');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }


  static Future<DownloadItem> startDownload({
    required MediaInfo info,
    required MediaFormat format,
    required String type,
    required Function(DownloadItem item) onProgress,
    required Function(DownloadItem item) onComplete,
    required Function(String error) onError,
  }) async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('Storage permission denied.');
    }

    final dirPath = await _getDownloadDirectory();

    // Clean title for filename
    final RegExp regex = RegExp(r'[^\w\s]+');
    final cleanTitle = info.title.replaceAll(regex, '').replaceAll(' ', '_');
    final fileName = '${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.${format.ext}';
    final filePath = '$dirPath/$fileName';

    final id = const Uuid().v4();
    final cancelToken = CancelToken();
    final progressNotifier = ValueNotifier<double>(0.0);

    _cancelTokens[id] = cancelToken;
    _progressNotifiers[id] = progressNotifier;

    final item = DownloadItem(
      id: id,
      title: info.title,
      url: format.url,
      savedDir: dirPath,
      fileName: fileName,
      format: format.formatName,
      type: type,
      date: DateTime.now(),
      status: DownloadStatus.running,
    );

    await HistoryService.saveItem(item);

    // Use youtube_explode stream client for YouTube URLs (where streamInfo is available), dio for others
    if (format.streamInfo != null) {
      _downloadYouTubeStream(
        streamInfo: format.streamInfo,
        filePath: filePath,
        totalBytes: format.sizeBytes ?? 0,
        item: item,
        progressNotifier: progressNotifier,
        onProgress: onProgress,
        onComplete: onComplete,
        onError: onError,
      );
    } else {
      _downloadWithDio(
        url: format.url,
        filePath: filePath,
        cancelToken: cancelToken,
        progressNotifier: progressNotifier,
        item: item,
        onProgress: onProgress,
        onComplete: onComplete,
        onError: onError,
      );
    }

    return item;
  }

  /// Downloads YouTube streams using youtube_explode's stream client
  /// which handles the authentication/signature properly.
  static Future<void> _downloadYouTubeStream({
    required dynamic streamInfo,
    required String filePath,
    required int totalBytes,
    required DownloadItem item,
    required ValueNotifier<double> progressNotifier,
    required Function(DownloadItem item) onProgress,
    required Function(DownloadItem item) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      final stream = _yt.videos.streamsClient.get(streamInfo);

      final file = File(filePath);
      final fileStream = file.openWrite();

      int received = 0;

      await for (final chunk in stream) {
        fileStream.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          final progress = (received / totalBytes * 100).roundToDouble();
          progressNotifier.value = progress;
          onProgress(item.copyWith(progress: progress.toInt(), status: DownloadStatus.running));
        }
      }

      await fileStream.flush();
      await fileStream.close();

      final completedItem = item.copyWith(progress: 100, status: DownloadStatus.completed);
      await HistoryService.saveItem(completedItem);
      onComplete(completedItem);
    } catch (e) {
      final failedItem = item.copyWith(status: DownloadStatus.failed);
      await HistoryService.saveItem(failedItem);
      onError('Download failed: $e');
    } finally {
      _cancelTokens.remove(item.id);
      _progressNotifiers.remove(item.id);
    }
  }

  /// Downloads non-YouTube files (Facebook etc.) using dio
  static Future<void> _downloadWithDio({
    required String url,
    required String filePath,
    required CancelToken cancelToken,
    required ValueNotifier<double> progressNotifier,
    required DownloadItem item,
    required Function(DownloadItem item) onProgress,
    required Function(DownloadItem item) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).roundToDouble();
            progressNotifier.value = progress;
            onProgress(item.copyWith(progress: progress.toInt(), status: DownloadStatus.running));
          }
        },
      );

      final completedItem = item.copyWith(progress: 100, status: DownloadStatus.completed);
      await HistoryService.saveItem(completedItem);
      onComplete(completedItem);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        final canceledItem = item.copyWith(status: DownloadStatus.canceled);
        await HistoryService.saveItem(canceledItem);
        onError('Download canceled');
      } else {
        final failedItem = item.copyWith(status: DownloadStatus.failed);
        await HistoryService.saveItem(failedItem);
        onError('Download failed: ${e.message}');
      }
    } catch (e) {
      final failedItem = item.copyWith(status: DownloadStatus.failed);
      await HistoryService.saveItem(failedItem);
      onError('Download failed: $e');
    } finally {
      _cancelTokens.remove(item.id);
      _progressNotifiers.remove(item.id);
    }
  }

  static void cancelDownload(String id) {
    _cancelTokens[id]?.cancel();
  }
}
