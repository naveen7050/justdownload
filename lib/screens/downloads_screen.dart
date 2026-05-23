import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/download_item.dart';
import '../services/history_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadItem> _history = [];
  Map<String, bool> _fileExistsCache = {};
  Map<String, int> _fileActualSizes = {};
  String _selectedCategory = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    final fileExistsCache = <String, bool>{};
    final fileActualSizes = <String, int>{};

    for (final item in history) {
      final filePath = '${item.savedDir}/${item.fileName}';
      final file = File(filePath);
      try {
        final exists = await file.exists();
        fileExistsCache[item.id] = exists;
        if (exists) {
          fileActualSizes[item.id] = await file.length();
        }
      } catch (_) {
        fileExistsCache[item.id] = false;
      }
    }

    if (mounted) {
      setState(() {
        _history = history;
        _fileExistsCache = fileExistsCache;
        _fileActualSizes = fileActualSizes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItemAndFile(DownloadItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete File & History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This will permanently delete the file from your device storage and remove it from history. This action cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE',
                  style: TextStyle(
                      color: Color(0xFFEF4444), fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    // Delete physical file
    try {
      final filePath = '${item.savedDir}/${item.fileName}';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    // Remove from history
    await HistoryService.deleteItem(item.id);
    _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File and history entry deleted'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _deleteHistoryOnly(DownloadItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Remove this item from your history? The file will remain safe on your device storage.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('REMOVE',
                  style: TextStyle(
                      color: Color(0xFF9C6AFF), fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    // Remove from history
    await HistoryService.deleteItem(item.id);
    _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from history'),
          backgroundColor: Color(0xFF9C6AFF),
        ),
      );
    }
  }

  Future<void> _openFile(DownloadItem item) async {
    final filePath = '${item.savedDir}/${item.fileName}';
    final result = await OpenFilex.open(filePath);

    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String successMsg) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF9C6AFF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    if (i == 0) {
      return '${bytes.toInt()} B';
    } else {
      return '${size.toStringAsFixed(2)} ${suffixes[i]}';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String? _getYouTubeVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.host.contains('youtube.com')) {
        if (uri.path.startsWith('/shorts/')) {
          return uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        }
        return uri.queryParameters['v'];
      }
    } catch (_) {}
    return null;
  }

  Widget _buildThumbnail(DownloadItem item, bool isVideo) {
    final url = item.thumbnailUrl ?? '';
    final hasValidUrl = url.startsWith('http://') || url.startsWith('https://');
    
    String? finalThumbnailUrl;
    if (hasValidUrl) {
      finalThumbnailUrl = url;
    } else {
      final ytId = _getYouTubeVideoId(item.url);
      if (ytId != null) {
        finalThumbnailUrl = 'https://img.youtube.com/vi/$ytId/mqdefault.jpg';
      }
    }

    Widget thumbnailWidget;
    if (finalThumbnailUrl != null) {
      thumbnailWidget = Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            finalThumbnailUrl,
            width: 64,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(isVideo),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 64,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white30),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      thumbnailWidget = _buildFallbackIcon(isVideo);
    }

    final platform = _detectPlatform(item.url);
    if (platform == 'Unknown') {
      return thumbnailWidget;
    }

    final logoIcon = _getPlatformIcon(platform);
    final logoColor = _getPlatformColor(platform);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        thumbnailWidget,
        Positioned(
          top: -3,
          left: -3,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0B1E),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              logoIcon,
              size: 8.5,
              color: logoColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackIcon(bool isVideo) {
    return Container(
      width: 64,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: (isVideo
                ? const Color(0xFF60A5FA)
                : const Color(0xFFFF9800))
            .withValues(alpha: 0.12),
      ),
      child: Icon(
        isVideo ? Icons.movie_rounded : Icons.audiotrack_rounded,
        color: isVideo ? const Color(0xFF60A5FA) : const Color(0xFFFF9800),
        size: 20,
      ),
    );
  }

  Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return const Color(0xFF4ADE80);
      case DownloadStatus.running:
        return const Color(0xFF60A5FA);
      case DownloadStatus.failed:
        return const Color(0xFFEF4444);
      case DownloadStatus.canceled:
        return const Color(0xFFFBBF24);
      case DownloadStatus.queued:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icons.check_circle_rounded;
      case DownloadStatus.running:
        return Icons.downloading_rounded;
      case DownloadStatus.failed:
        return Icons.error_rounded;
      case DownloadStatus.canceled:
        return Icons.cancel_rounded;
      case DownloadStatus.queued:
        return Icons.schedule_rounded;
    }
  }

  List<DownloadItem> get _filteredHistory {
    if (_selectedCategory == 'All') return _history;
    if (_selectedCategory == 'Videos') {
      return _history.where((item) => item.type == 'Video').toList();
    }
    if (_selectedCategory == 'Audios') {
      return _history.where((item) => item.type == 'Audio').toList();
    }
    return _history;
  }

  void _showItemOptions(DownloadItem item, ColorScheme cs) {
    final fileExists = _fileExistsCache[item.id] ?? false;
    final isDownloading = item.status == DownloadStatus.running || item.status == DownloadStatus.queued;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF120B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        item.type == 'Video' ? Icons.movie_rounded : Icons.audiotrack_rounded,
                        color: item.type == 'Video' ? const Color(0xFF60A5FA) : const Color(0xFFFF9800),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                if (fileExists && !isDownloading)
                  ListTile(
                    leading: const Icon(Icons.play_arrow_rounded, color: Color(0xFF4ADE80)),
                    title: const Text('Open File', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _openFile(item);
                    },
                  ),
                if (fileExists)
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded, color: Colors.white60),
                    title: const Text('Copy File Path', style: TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      _copyToClipboard('${item.savedDir}/${item.fileName}', 'File path copied to clipboard');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: Colors.white60),
                  title: const Text('Copy Download URL', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyToClipboard(item.url, 'Download URL copied');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Colors.white60),
                  title: const Text('View Details', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    _showItemDetails(item, cs);
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                if (fileExists)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                    title: const Text('Delete File & History', style: TextStyle(color: Color(0xFFEF4444))),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteItemAndFile(item);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: Text(fileExists ? 'Remove from History Only' : 'Remove from History', style: const TextStyle(color: Color(0xFFEF4444))),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteHistoryOnly(item);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showItemDetails(DownloadItem item, ColorScheme cs) {
    final fileExists = _fileExistsCache[item.id] ?? false;
    final sizeOnDisk = _fileActualSizes[item.id];
    final sizeString = sizeOnDisk != null
        ? _formatSize(sizeOnDisk)
        : (item.sizeBytes != null ? '${_formatSize(item.sizeBytes!)} (Estimated)' : 'Unknown');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.info_rounded, color: Color(0xFF9C6AFF)),
            const SizedBox(width: 8),
            const Text('Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Title', item.title),
              _buildDetailRow('File Name', item.fileName),
              _buildDetailRow('Format', item.format),
              _buildDetailRow('Type', item.type),
              _buildDetailRow('Status', item.status.name.toUpperCase(), valueColor: _statusColor(item.status)),
              _buildDetailRow('File Size', sizeString),
              _buildDetailRow('Storage State', fileExists ? 'Saved on Disk' : 'File Missing / Deleted',
                  valueColor: fileExists ? const Color(0xFF4ADE80) : const Color(0xFFEF4444)),
              _buildDetailRow('Save Path', '${item.savedDir}/${item.fileName}'),
              _buildDetailRow('Download Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(item.date)),
              _buildDetailRow('Source URL', item.url),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Color(0xFF9C6AFF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(ColorScheme cs) {
    final totalCount = _history.length;
    final totalBytes = _fileActualSizes.values.fold<int>(0, (a, b) => a + b);
    final spaceSavedString = _formatSize(totalBytes);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C6AFF), Color(0xFF3730A3)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C6AFF).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disk Space Occupied',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  spaceSavedString,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalCount files',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme cs) {
    final categories = ['All', 'Videos', 'Audios'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.15)
                      : const Color(0xFF1A1230),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Downloads',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        _ActionChip(
                          icon: Icons.delete_sweep_rounded,
                          label: 'Clear',
                          color: const Color(0xFFEF4444),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1638),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Clear History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: const Text(
                                    'Remove all items from history? Files will not be deleted from device storage.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('CLEAR',
                                          style: TextStyle(
                                              color: cs.error, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await HistoryService.clearHistory();
                              _loadHistory();
                            }
                          },
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: cs.primary),
                        )
                      : _history.isEmpty
                          ? _buildEmptyState(cs)
                          : Column(
                              children: [
                                _buildDashboard(cs),
                                _buildFilterChips(cs),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                                    itemCount: _filteredHistory.length,
                                    itemBuilder: (context, index) {
                                      final item = _filteredHistory[index];
                                      return _buildDownloadCard(item, cs, index);
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  const Color(0xFF3730A3).withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(
              Icons.download_rounded,
              size: 36,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No downloads yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your download history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem item, ColorScheme cs, int index) {
    final isVideo = item.type == 'Video';
    final dateStr = DateFormat('MMM dd · HH:mm').format(item.date);
    final stColor = _statusColor(item.status);
    final fileExists = _fileExistsCache[item.id] ?? false;
    final isDownloading = item.status == DownloadStatus.running || item.status == DownloadStatus.queued;

    // Formatting size
    String sizeDisplay = '';
    if (isDownloading) {
      sizeDisplay = item.sizeBytes != null ? _formatSize(item.sizeBytes!) : 'Downloading...';
    } else {
      if (fileExists) {
        final sizeBytes = _fileActualSizes[item.id];
        sizeDisplay = sizeBytes != null ? _formatSize(sizeBytes) : 'Unknown';
      } else {
        sizeDisplay = 'File Missing';
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF160E28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: fileExists && !isDownloading ? () => _openFile(item) : () => _showItemOptions(item, cs),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Online Thumbnail or Type Fallback Icon
                  _buildThumbnail(item, isVideo),
                  const SizedBox(width: 14),

                  // Info details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title (Up to 2 lines to prevent cutoffs)
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.95),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        
                        // Row 1: Format & Duration
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.format,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_formatDuration(item.durationSeconds).isNotEmpty) ...[
                              Container(
                                width: 3,
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white24,
                                ),
                              ),
                              Text(
                                _formatDuration(item.durationSeconds),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Row 2: Status & Size
                        Row(
                          children: [
                            Icon(_statusIcon(item.status), size: 12, color: stColor),
                            const SizedBox(width: 4),
                            Text(
                              item.status.name.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: stColor,
                                  letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                            ),
                            Text(
                              sizeDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: fileExists && !isDownloading ? FontWeight.w600 : FontWeight.normal,
                                color: fileExists
                                    ? Colors.white54
                                    : (isDownloading ? cs.primary : const Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Row 3: Date (Fully visible in its own line)
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        if (isDownloading) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: item.progress / 100,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Option Menu
                  GestureDetector(
                    onTap: () => _showItemOptions(item, cs),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'YouTube';
    } else if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return 'Instagram';
    } else if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) {
      return 'Facebook';
    } else if (lower.contains('tiktok.com')) {
      return 'TikTok';
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'Twitter/X';
    }
    return 'Unknown';
  }

  IconData _getPlatformIcon(String source) {
    switch (source) {
      case 'YouTube':
        return FontAwesomeIcons.youtube.data;
      case 'Instagram':
        return FontAwesomeIcons.instagram.data;
      case 'Facebook':
        return FontAwesomeIcons.facebook.data;
      case 'TikTok':
        return FontAwesomeIcons.tiktok.data;
      case 'Twitter/X':
        return FontAwesomeIcons.xTwitter.data;
      default:
        return Icons.video_library_rounded;
    }
  }

  Color _getPlatformColor(String source) {
    switch (source) {
      case 'YouTube':
        return const Color(0xFFFF0000);
      case 'Instagram':
        return const Color(0xFFE4405F);
      case 'Facebook':
        return const Color(0xFF1877F2);
      case 'TikTok':
        return const Color(0xFFEE1D52);
      case 'Twitter/X':
        return const Color(0xFFFFFFFF);
      default:
        return const Color(0xFF9C6AFF);
    }
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
