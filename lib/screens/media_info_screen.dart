import 'package:flutter/material.dart';
import '../models/media_info.dart';
import '../services/download_service.dart';

class MediaInfoScreen extends StatefulWidget {
  final MediaInfo mediaInfo;

  const MediaInfoScreen({super.key, required this.mediaInfo});

  @override
  State<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends State<MediaInfoScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isDownloading = false;
  double _progress = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (widget.mediaInfo.formats.isEmpty) return;

    final format = widget.mediaInfo.formats[_selectedIndex];

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      final type =
          format.formatName.toLowerCase().contains('audio') ? 'Audio' : 'Video';
      await DownloadService.startDownload(
        info: widget.mediaInfo,
        format: format,
        type: type,
        onProgress: (item) {
          if (mounted) {
            setState(() {
              _progress = item.progress.toDouble();
            });
          }
        },
        onComplete: (item) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _progress = 100;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFFA5F3C4)),
                    const SizedBox(width: 8),
                    const Text('Download complete!'),
                  ],
                ),
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  IconData _getPlatformIcon(String source) {
    switch (source) {
      case 'YouTube':
        return Icons.play_circle_fill_rounded;
      case 'Instagram':
        return Icons.camera_alt_rounded;
      case 'Facebook':
        return Icons.facebook_rounded;
      case 'TikTok':
        return Icons.music_note_rounded;
      case 'Twitter/X':
        return Icons.tag_rounded;
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
        return const Color(0xFF00F2EA);
      case 'Twitter/X':
        return const Color(0xFF8899AA);
      default:
        return const Color(0xFF9C6AFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = widget.mediaInfo;
    final platColor = _getPlatformColor(info.source);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Media Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Source badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: platColor.withValues(alpha: 0.15),
                      border: Border.all(color: platColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getPlatformIcon(info.source),
                            size: 14, color: platColor),
                        const SizedBox(width: 5),
                        Text(
                          info.source,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: platColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: _animController, curve: Curves.easeOutCubic)),
                child: FadeTransition(
                  opacity: _animController,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            if (info.thumbnailUrl.isNotEmpty)
                              Image.network(
                                info.thumbnailUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildPlaceholderThumb(cs),
                              )
                            else
                              _buildPlaceholderThumb(cs),
                            // Duration badge
                            if (info.duration != null)
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                  child: Text(
                                    '${info.duration!.inMinutes}:${(info.duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 24),

                      // Format selector header
                      Text(
                        'AVAILABLE FORMATS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Format list
                      ...List.generate(info.formats.length, (index) {
                        final format = info.formats[index];
                        final isSelected = _selectedIndex == index;
                        final isAudio =
                            format.formatName.toLowerCase().contains('audio');

                        return GestureDetector(
                          onTap: _isDownloading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isSelected
                                  ? cs.primary.withValues(alpha: 0.12)
                                  : const Color(0xFF1A1230),
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.06),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: (isAudio
                                            ? const Color(0xFFFF9800)
                                            : cs.primary)
                                        .withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    isAudio
                                        ? Icons.audiotrack_rounded
                                        : Icons.videocam_rounded,
                                    size: 20,
                                    color: isAudio
                                        ? const Color(0xFFFF9800)
                                        : cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        format.formatName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        format.sizeString,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: cs.primary, size: 22),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom download bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0A1E),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  if (_isDownloading) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress / 100,
                              backgroundColor:
                                  cs.primary.withValues(alpha: 0.1),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cs.primary),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_progress.toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Download button
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isDownloading
                              ? [
                                  cs.primary.withValues(alpha: 0.3),
                                  const Color(0xFF3730A3).withValues(alpha: 0.3),
                                ]
                              : [cs.primary, const Color(0xFF3730A3)],
                        ),
                        boxShadow: _isDownloading
                            ? []
                            : [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isDownloading ? null : _startDownload,
                          child: Center(
                            child: _isDownloading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Downloading...',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download_rounded,
                                          color: Colors.white, size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        'Download',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumb(ColorScheme cs) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            const Color(0xFF3730A3).withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_file_rounded,
              size: 48, color: cs.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            widget.mediaInfo.source,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
