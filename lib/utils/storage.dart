import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../models/wrong_record.dart';

/// 本地数据存取工具：错题本历史与最高成绩。
class StorageUtil {
  static const String _wrongRecordsKey = 'wrong_records';
  static const String _bestScoreKey = 'best_score';

  /// 将错题列表序列化为 JSON 字符串并保存到本地。
  static Future<void> saveWrongRecords(List<WrongRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      records.map(_recordToJson).toList(growable: false),
    );
    await prefs.setString(_wrongRecordsKey, encoded);
  }

  /// 从本地读取错题 JSON 并还原为列表；无数据或数据损坏时返回空列表。
  static Future<List<WrongRecord>> loadWrongRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wrongRecordsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => _recordFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 保存最高答对题数。
  static Future<void> saveBestScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, score);
  }

  /// 读取最高答对题数，默认 0。
  static Future<int> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestScoreKey) ?? 0;
  }

  static Map<String, dynamic> _recordToJson(WrongRecord record) {
    return {
      'question': {
        'id': record.question.id,
        'text': record.question.text,
        'correctAnswer': record.question.correctAnswer,
        'wrongOptions': record.question.wrongOptions,
      },
      'userAnswer': record.userAnswer,
      'timestamp': record.timestamp.toIso8601String(),
    };
  }

  static WrongRecord _recordFromJson(Map<String, dynamic> json) {
    final questionJson = json['question'] as Map<String, dynamic>;
    return WrongRecord(
      question: Question(
        id: questionJson['id'] as int,
        text: questionJson['text'] as String,
        correctAnswer: questionJson['correctAnswer'] as String,
        wrongOptions: (questionJson['wrongOptions'] as List<dynamic>)
            .cast<String>(),
      ),
      userAnswer: json['userAnswer'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
