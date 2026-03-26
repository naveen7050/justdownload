import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import '../models/download_item.dart';
import '../services/history_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    await HistoryService.deleteItem(id);
    _loadHistory();
  }

  Future<void> _openFile(DownloadItem item) async {
    final filePath = '${item.savedDir}/${item.fileName}';
    final result = await OpenFilex.open(filePath);
    
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Remove all items from history? Files will not be deleted from storage.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR')),
                  ],
                ),
              );

              if (confirm == true) {
                await HistoryService.clearHistory();
                _loadHistory();
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No downloads yet.'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final isVideo = item.type == 'Video';
                    final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(item.date);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isVideo ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          child: Icon(isVideo ? Icons.movie : Icons.audiotrack, color: isVideo ? Colors.blue : Colors.orange),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateStr, style: const TextStyle(fontSize: 12)),
                            Text('Format: ${item.format}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteItem(item.id),
                        ),
                        onTap: () => _openFile(item),
                      ),
                    );
                  },
                ),
    );
  }
}
