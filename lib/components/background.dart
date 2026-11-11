import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 卡通风格天空背景：渐变天空 + 缓慢向左漂浮的云朵。
class BackgroundComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  BackgroundComponent() {
    priority = -10;
  }

  final Random _random = Random();
  final List<_Cloud> _clouds = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = game.size.clone();
    _createClouds();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    if (_clouds.isEmpty) {
      _createClouds();
    }
  }

  void _createClouds() {
    final width = size.x > 0 ? size.x : game.size.x;
    final height = size.y > 0 ? size.y : game.size.y;
    if (width <= 0 || height <= 0) {
      return;
    }
    _clouds
      ..clear()
      ..addAll(List.generate(9, (_) => _Cloud.random(_random, width, height)));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (size.x != game.size.x || size.y != game.size.y) {
      size = game.size.clone();
      _createClouds();
    }

    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      // 完全移出左侧后，从右侧重新进入，形成循环漂浮。
      if (cloud.x + cloud.width < 0) {
        cloud.x = size.x + _random.nextDouble() * size.x * 0.3;
        cloud.y = _random.nextDouble() * size.y * 0.55;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8ED4FF), Color(0xFFCDEBFF), Color(0xFFFFE1EC)],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (final cloud in _clouds) {
      _drawCloud(canvas, cloud, cloudPaint);
    }
  }

  void _drawCloud(Canvas canvas, _Cloud cloud, Paint paint) {
    final radius = cloud.height / 2;
    canvas.drawOval(
      Rect.fromLTWH(cloud.x, cloud.y, cloud.width, cloud.height),
      paint,
    );
    canvas.drawCircle(
      Offset(cloud.x + cloud.width * 0.32, cloud.y + cloud.height * 0.3),
      radius * 0.8,
      paint,
    );
    canvas.drawCircle(
      Offset(cloud.x + cloud.width * 0.62, cloud.y + cloud.height * 0.2),
      radius,
      paint,
    );
  }
}

/// 单朵云的数据。
class _Cloud {
  _Cloud({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
  });

  factory _Cloud.random(
    Random random,
    double screenWidth,
    double screenHeight,
  ) {
    return _Cloud(
      x: random.nextDouble() * screenWidth,
      y: random.nextDouble() * screenHeight * 0.55,
      width: 70 + random.nextDouble() * 110,
      height: 28 + random.nextDouble() * 30,
      speed: 6 + random.nextDouble() * 14,
    );
  }

  double x;
  double y;
  final double width;
  final double height;
  final double speed;
}
