import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class HistoryService {
  static const String _key = 'download_history';

  static Future<List<DownloadItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => DownloadItem.fromMap(e)).toList();
  }

  static Future<void> saveItem(DownloadItem item) async {
    final history = await getHistory();
    final index = history.indexWhere((e) => e.id == item.id);
    
    if (index >= 0) {
      history[index] = item;
    } else {
      history.insert(0, item);
    }

    await _saveHistory(history);
  }

  static Future<void> deleteItem(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e.id == id);
    await _saveHistory(history);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _saveHistory(List<DownloadItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history.map((e) => e.toMap()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
