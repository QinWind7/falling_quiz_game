import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/quiz_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final QuizGame _game = QuizGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Falling Quiz',
      debugShowCheckedModeBanner: false,
      home: GameWidget<QuizGame>(
        game: _game,
        overlayBuilderMap: QuizGame.overlayBuilderMap,
        initialActiveOverlays: const [QuizGame.mainMenuOverlay],
      ),
    );
  }
}
