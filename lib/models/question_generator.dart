import 'dart:math';

import 'question.dart';

/// 动态四则运算题目生成器，会根据当前答对题数调整难度。
class QuestionGenerator {
  QuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _nextId = 1;

  /// 根据当前答对题数生成不同难度的四则运算题。
  Question generateQuestion(int correctCount) {
    late final String operator;
    late final int left;
    late final int right;
    late final int answer;

    if (correctCount <= 10) {
      // 1-10 题：两个 1-9 的个位数，只做加减。
      operator = _random.nextBool() ? '+' : '-';
      final first = _random.nextInt(9) + 1;
      final second = _random.nextInt(9) + 1;
      left = max(first, second);
      right = min(first, second);
      answer = operator == '+' ? first + second : left - right;
    } else if (correctCount <= 20) {
      // 11-20 题：一个 1-9 的个位数加/减一个 10-99 的两位数。
      operator = _random.nextBool() ? '+' : '-';
      final single = _random.nextInt(9) + 1;
      final twoDigit = _random.nextInt(90) + 10;
      if (operator == '+') {
        left = single;
        right = twoDigit;
        answer = single + twoDigit;
      } else {
        left = max(single, twoDigit);
        right = min(single, twoDigit);
        answer = left - right;
      }
    } else if (correctCount <= 30) {
      // 21-30 题：两个 1-9 的个位数，只做乘除。
      operator = _random.nextBool() ? '×' : '÷';
      if (operator == '×') {
        left = _random.nextInt(9) + 1;
        right = _random.nextInt(9) + 1;
        answer = left * right;
      } else {
        right = _random.nextInt(9) + 1;
        answer = _random.nextInt(9) + 1;
        left = right * answer;
      }
    } else if (correctCount <= 50) {
      // 31-50 题：两个 10-99 的两位数，只做加减。
      operator = _random.nextBool() ? '+' : '-';
      final first = _random.nextInt(90) + 10;
      final second = _random.nextInt(90) + 10;
      if (operator == '+') {
        left = first;
        right = second;
        answer = first + second;
      } else {
        left = max(first, second);
        right = min(first, second);
        answer = left - right;
      }
    } else if (correctCount <= 70) {
      // 51-70 题：一个 1-9 的个位数和一个 10-99 的两位数，只做乘除。
      operator = _random.nextBool() ? '×' : '÷';
      final single = _random.nextInt(9) + 1;
      final twoDigit = _random.nextInt(90) + 10;
      if (operator == '×') {
        left = single;
        right = twoDigit;
        answer = single * twoDigit;
      } else {
        right = twoDigit;
        answer = single;
        left = right * answer;
      }
    } else {
      // 71-100 题：两位数乘除，限制乘法因数在 10-30，避免答案过大。
      operator = _random.nextBool() ? '×' : '÷';
      if (operator == '×') {
        left = _random.nextInt(21) + 10;
        right = _random.nextInt(21) + 10;
        answer = left * right;
      } else {
        right = _random.nextInt(21) + 10;
        answer = _random.nextInt(9) + 1;
        left = right * answer;
      }
    }

    return Question(
      id: _nextId++,
      text: '$left $operator $right = ?',
      correctAnswer: '$answer',
      wrongOptions: _generateWrongOptions(answer),
    );
  }

  /// 按正确答案的位数生成相近的干扰项，避免出现离谱选项。
  List<String> _generateWrongOptions(int answer) {
    final digitCount = '$answer'.length;
    final minOffset = digitCount >= 3 ? 10 : 1;
    final maxOffset = switch (digitCount) {
      1 => 4,
      2 => 10,
      _ => 99,
    };

    final options = <int>{};
    while (options.length < 3) {
      final offset = minOffset + _random.nextInt(maxOffset - minOffset + 1);
      final candidate = _random.nextBool() ? answer + offset : answer - offset;
      if (candidate < 0 || candidate == answer) {
        continue;
      }
      if ('$candidate'.length != digitCount) {
        continue;
      }
      options.add(candidate);
    }

    return options.map((value) => '$value').toList();
  }
}
