import 'question.dart';

/// 错题记录模型。
class WrongRecord {
  const WrongRecord({
    required this.question,
    required this.userAnswer,
    required this.timestamp,
  });

  final Question question;
  final String userAnswer;
  final DateTime timestamp;
}
