import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  MediaFormat? _selectedFormat;
  bool _isDownloading = false;
  double _progress = 0;
  late AnimationController _animController;
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.mediaInfo.formats.isNotEmpty ? widget.mediaInfo.formats.first : null;
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
    final format = _selectedFormat;
    if (format == null) return;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = widget.mediaInfo;
    final platColor = _getPlatformColor(info.source);
    final size = MediaQuery.of(context).size;
    final isShort = size.height < 650;
    final btnTextColor = platColor == const Color(0xFFFFFFFF) ? const Color(0xFF0F0A1E) : Colors.white;


    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
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
                                    height: isShort ? 130 : 200,
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

                          // File Type Filter Chips (Animated sliding segmented control)
                          _buildFilterChipsStacked(cs, platColor),
                          const SizedBox(height: 14),

                          // Horizontal Sliding Formats Container
                          _buildFormatsSlider(_getFilteredFormats(info.formats), cs, platColor),

                          const SizedBox(height: 16),
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
                                      platColor.withValues(alpha: 0.1),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(platColor),
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
                                  color: platColor,
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
                                      platColor.withValues(alpha: 0.3),
                                      platColor.withValues(alpha: 0.15),
                                    ]
                                  : [platColor, platColor.withValues(alpha: 0.7)],
                            ),
                            boxShadow: _isDownloading
                                ? []
                                : [
                                    BoxShadow(
                                      color: platColor.withValues(alpha: 0.25),
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
                                              color: btnTextColor
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Downloading...',
                                            style: TextStyle(
                                              color: btnTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_rounded,
                                              color: btnTextColor, size: 22),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Download',
                                            style: TextStyle(
                                              color: btnTextColor,
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
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumb(ColorScheme cs) {
    final isShort = MediaQuery.of(context).size.height < 650;
    return Container(
      height: isShort ? 130 : 200,
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

  // Filter formats based on selected filter (checks names & extensions)
  List<MediaFormat> _getFilteredFormats(List<MediaFormat> formats) {
    if (_filterType == 'Videos') {
      return formats.where((f) {
        final isAudio = f.formatName.toLowerCase().contains('audio') ||
            f.ext.toLowerCase() == 'mp3' ||
            f.ext.toLowerCase() == 'm4a' ||
            f.ext.toLowerCase() == 'ogg' ||
            f.ext.toLowerCase() == 'wav' ||
            f.ext.toLowerCase() == 'aac';
        return !isAudio;
      }).toList();
    } else if (_filterType == 'Audios') {
      return formats.where((f) {
        final isAudio = f.formatName.toLowerCase().contains('audio') ||
            f.ext.toLowerCase() == 'mp3' ||
            f.ext.toLowerCase() == 'm4a' ||
            f.ext.toLowerCase() == 'ogg' ||
            f.ext.toLowerCase() == 'wav' ||
            f.ext.toLowerCase() == 'aac';
        return isAudio;
      }).toList();
    }
    return formats;
  }

  int get _filterIndex {
    switch (_filterType) {
      case 'Videos':
        return 1;
      case 'Audios':
        return 2;
      case 'All':
      default:
        return 0;
    }
  }

  Widget _buildFilterChipsStacked(ColorScheme cs, Color platColor) {
    final selectedIdx = _filterIndex;
    final options = ['All', 'Videos', 'Audios'];
    final selectedColor = platColor == const Color(0xFFFFFFFF) ? Colors.white : platColor;
    
    return Center(
      child: Container(
        width: 278,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          children: [
            // Sliding Background Pill
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              left: 4 + (selectedIdx * 90),
              top: 4,
              bottom: 4,
              width: 90,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: platColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: platColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Interactive Labels
            Row(
              children: List.generate(options.length, (index) {
                final option = options[index];
                final isSelected = selectedIdx == index;
                return SizedBox(
                  width: 90,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _filterType = option;
                        final filtered = _getFilteredFormats(widget.mediaInfo.formats);
                        if (filtered.isNotEmpty) {
                          if (!filtered.contains(_selectedFormat)) {
                            _selectedFormat = filtered.first;
                          }
                        } else {
                          _selectedFormat = null;
                        }
                      });
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? selectedColor
                              : cs.onSurface.withValues(alpha: 0.6),
                        ),
                        child: Text(option),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatsSlider(List<MediaFormat> filteredFormats, ColorScheme cs, Color platColor) {
    if (filteredFormats.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        child: Text(
          'No formats available',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: filteredFormats.length,
      itemBuilder: (context, index) {
        final format = filteredFormats[index];
        final isSelected = _selectedFormat == format;
        final isAudio = format.formatName.toLowerCase().contains('audio');

        return GestureDetector(
          onTap: _isDownloading
              ? null
              : () {
                  setState(() {
                    _selectedFormat = format;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? platColor.withValues(alpha: 0.12)
                  : const Color(0xFF160E28),
              border: Border.all(
                color: isSelected
                    ? platColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.05),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: platColor.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (isAudio ? const Color(0xFFFF9800) : platColor)
                        .withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    isAudio ? Icons.audiotrack_rounded : Icons.videocam_rounded,
                    size: 18,
                    color: isAudio ? const Color(0xFFFF9800) : platColor,
                  ),
                ),
                const SizedBox(width: 14),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        format.formatName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            child: Text(
                              format.ext.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            format.sizeString,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                if (isSelected)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: 1.0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: platColor,
                      size: 24,
                    ),
                  )
                else
                  const SizedBox(width: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
