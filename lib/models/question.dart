/// 题目模型。
class Question {
  const Question({
    required this.id,
    required this.text,
    required this.correctAnswer,
    required this.wrongOptions,
  }) : assert(wrongOptions.length >= 3, 'wrongOptions 至少需要 3 个干扰项');

  final int id;
  final String text;
  final String correctAnswer;
  final List<String> wrongOptions;
}
