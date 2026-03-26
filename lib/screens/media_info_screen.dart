import 'package:flutter/material.dart';
import '../models/media_info.dart';
import '../services/download_service.dart';

class MediaInfoScreen extends StatefulWidget {
  final MediaInfo mediaInfo;

  const MediaInfoScreen({super.key, required this.mediaInfo});

  @override
  State<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends State<MediaInfoScreen> {
  int _selectedIndex = 0;
  bool _isDownloading = false;
  double _progress = 0;

  Future<void> _startDownload() async {
    if (widget.mediaInfo.formats.isEmpty) return;

    final format = widget.mediaInfo.formats[_selectedIndex];

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      final type = format.formatName.toLowerCase().contains('audio') ? 'Audio' : 'Video';
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
              const SnackBar(content: Text('Download complete!')),
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
        SnackBar(content: Text('Failed: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Info'),
      ),
      body: Column(
        children: [
          if (widget.mediaInfo.thumbnailUrl.isNotEmpty)
            Image.network(
              widget.mediaInfo.thumbnailUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 200,
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, size: 50),
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey[800],
              child: const Center(child: Icon(Icons.video_file, size: 50, color: Colors.white54)),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.mediaInfo.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.mediaInfo.duration != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Duration: ${widget.mediaInfo.duration!.inMinutes}:${(widget.mediaInfo.duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Format:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.mediaInfo.formats.length,
              itemBuilder: (context, index) {
                final format = widget.mediaInfo.formats[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(
                    format.formatName.toLowerCase().contains('audio')
                        ? Icons.audiotrack
                        : Icons.videocam,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(format.formatName),
                  subtitle: Text('Size: ${format.sizeString}'),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                  selected: isSelected,
                  onTap: _isDownloading
                      ? null
                      : () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                );
              },
            ),
          ),
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _progress / 100),
                  const SizedBox(height: 4),
                  Text('${_progress.toInt()}%'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _startDownload,
                icon: _isDownloading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
