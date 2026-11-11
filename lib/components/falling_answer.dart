import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 父游戏需要实现的回调接口。
abstract class FallingAnswerGame extends FlameGame {
  /// 答案落到底部时调用（正确答案落底即失败，由游戏判断）。
  void onAnswerMissed(FallingAnswer answer);

  /// 答案被点击时调用。
  void onAnswerTapped(FallingAnswer answer);
}

/// 从屏幕上方落下的答案选项。
class FallingAnswer extends PositionComponent
    with TapCallbacks, HasGameReference<FallingAnswerGame> {
  FallingAnswer({
    required this.text,
    required this.isCorrect,
    required this.fallSpeed,
    super.position,
  }) : super(size: Vector2(200, 56));

  static const double _horizontalPadding = 24;
  static const double _verticalPadding = 14;
  static const double _cornerRadius = 16;
  static const Color _backgroundColor = Color(0xFF2F3B52);
  static const TextStyle _textStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFFFFFF),
  );

  final String text;
  final bool isCorrect;
  final double fallSpeed;

  final Paint _backgroundPaint = Paint()..color = _backgroundColor;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  @override
  Future<void> onLoad() async {
    _textPainter
      ..text = TextSpan(text: text, style: _textStyle)
      ..layout();
    size = Vector2(
      _textPainter.width + _horizontalPadding * 2,
      _textPainter.height + _verticalPadding * 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += fallSpeed * dt;
    if (position.y > game.size.y) {
      game.onAnswerMissed(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(_cornerRadius),
    );
    canvas.drawRRect(background, _backgroundPaint);
    _textPainter.paint(
      canvas,
      Offset(
        (size.x - _textPainter.width) / 2,
        (size.y - _textPainter.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.onAnswerTapped(this);
  }

  @override
  void onRemove() {
    _textPainter.dispose();
    super.onRemove();
  }
}
