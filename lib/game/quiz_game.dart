import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import '../components/background.dart';
import '../components/falling_answer.dart';
import '../models/question.dart';
import '../models/question_generator.dart';
import '../models/wrong_record.dart';
import '../utils/storage.dart';

enum GameState { playing, gameOver }

/// 答题坠落游戏主控制器。
class QuizGame extends FallingAnswerGame with HasCollisionDetection {
  static const String mainMenuOverlay = 'mainMenu';
  static const String hudOverlay = 'hud';
  static const String gameOverOverlay = 'gameOver';
  static const String wrongBookOverlay = 'wrongBook';

  static const int winningCorrectCount = 100;

  static const String _bgmFile = 'bgm.wav';
  static const String _clickFile = 'click.wav';
  static const String _failFile = 'fail.wav';

  static const double _baseFallSpeed = 90;
  static const double _cardWidth = 200;
  static const int _laneCount = 4;

  final Random _random = Random();
  final QuestionGenerator _questionGenerator = QuestionGenerator();

  Question? currentQuestion;
  int correctCount = 0;
  int bestScore = 0;
  final List<WrongRecord> wrongRecords = [];

  /// 供 HUD 监听答对题数变化。
  final ValueNotifier<int> correctCountListenable = ValueNotifier<int>(0);

  /// 供 HUD 监听当前题目变化。
  final ValueNotifier<Question?> currentQuestionListenable =
      ValueNotifier<Question?>(null);

  /// 音效开关状态。
  final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(true);

  GameState state = GameState.playing;

  bool _started = false;
  bool _bgmStarted = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 默认 viewfinder 锚点在中心，会把世界坐标 (0,0) 映射到屏幕中央；
    // 改为左上角，方块坐标才能和屏幕坐标一致。
    camera.viewfinder.anchor = Anchor.topLeft;
    // 背景优先级为 -10，始终位于所有答案方块之下。
    world.add(BackgroundComponent());
    await FlameAudio.bgm.initialize();
    _playBgmIfEnabled();
    // 从本地恢复历史错题与最高成绩。
    final storedRecords = await StorageUtil.loadWrongRecords();
    wrongRecords
      ..clear()
      ..addAll(storedRecords);
    bestScore = await StorageUtil.loadBestScore();
    overlays.add(mainMenuOverlay);
    _loadQuestion();
    spawnAnswers();
  }

  /// 切换背景音乐与音效开关。
  Future<void> toggleSound() async {
    soundEnabled.value = !soundEnabled.value;
    if (soundEnabled.value) {
      await _playBgmIfEnabled();
    } else {
      await FlameAudio.bgm.pause();
    }
  }

  Future<void> _playBgmIfEnabled() async {
    if (!soundEnabled.value) {
      return;
    }
    if (_bgmStarted) {
      await FlameAudio.bgm.resume();
      return;
    }
    _bgmStarted = true;
    await FlameAudio.bgm.play(_bgmFile, volume: 0.3);
  }

  void _playSfx(String file) {
    if (!soundEnabled.value) {
      return;
    }
    FlameAudio.play(file);
  }

  /// 开始（或重新开始）一局游戏。
  void startGame() {
    resumeEngine();
    _started = true;
    state = GameState.playing;
    correctCount = 0;
    correctCountListenable.value = 0;
    _clearAnswers();
    overlays.remove(mainMenuOverlay);
    overlays.remove(gameOverOverlay);
    overlays.remove(wrongBookOverlay);
    overlays.add(hudOverlay);
    _playBgmIfEnabled();
    _loadQuestion();
    spawnAnswers();
  }

  /// 退出到主界面：暂停游戏循环、清空坠落方块并切换 overlay。
  void exitToMenu() {
    _started = false;
    state = GameState.playing;
    _clearAnswers();
    pauseEngine();
    overlays.remove(hudOverlay);
    overlays.remove(gameOverOverlay);
    overlays.remove(wrongBookOverlay);
    overlays.add(mainMenuOverlay);
  }

  /// 把屏幕均分为 4 条垂直赛道，每次生成 4 个方块（1 个正确答案 + 3 个干扰项），
  /// 每个方块随机分配到一条赛道并在赛道中央下落，初始高度随机错开。
  void spawnAnswers() {
    final question = currentQuestion;
    if (question == null) {
      return;
    }

    final wrongOptions = [...question.wrongOptions]..shuffle(_random);
    final distractors = wrongOptions.take(_laneCount - 1).toList();
    assert(
      distractors.length == _laneCount - 1,
      '题库需要为每道题提供至少 ${_laneCount - 1} 个干扰项',
    );

    final answers = <FallingAnswer>[
      FallingAnswer(
        text: question.correctAnswer,
        isCorrect: true,
        fallSpeed: _nextFallSpeed(),
      ),
      for (final option in distractors)
        FallingAnswer(
          text: option,
          isCorrect: false,
          fallSpeed: _nextFallSpeed(),
        ),
    ]..shuffle(_random);

    final width = size.x > 0 ? size.x : 400.0;
    final laneWidth = width / _laneCount;
    final lanes = List<int>.generate(_laneCount, (index) => index)
      ..shuffle(_random);

    for (var i = 0; i < answers.length; i++) {
      final answer = answers[i];
      final answerWidth = _estimateAnswerWidth(answer.text);
      final laneIndex = lanes[i];
      // 赛道中线减去方块宽度的一半，让方块落在赛道正中间。
      final laneX = laneIndex * laneWidth + laneWidth / 2 - answerWidth / 2;
      final x = min(max(laneX, 0.0), max(0.0, width - answerWidth));
      final y = -40.0 - _random.nextDouble() * 200.0;
      answer.position = Vector2(x, y);
    }

    world.addAll(answers);
  }

  /// 估算方块宽度，保证随机出的 x 能让整个方块落在屏幕内。
  double _estimateAnswerWidth(String text) {
    return (text.length * 12.0 + 48.0).clamp(60.0, _cardWidth);
  }

  /// 固定基础速度 + 少量随机偏移，保证方块轨迹不同。
  double _nextFallSpeed() {
    return _baseFallSpeed + _random.nextDouble() * 30;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_started || state != GameState.playing) {
      return;
    }

    FallingAnswer? missedCorrectAnswer;
    for (final answer in world.children.whereType<FallingAnswer>()) {
      if (answer.isCorrect && answer.position.y > size.y) {
        missedCorrectAnswer = answer;
        break;
      }
    }
    if (missedCorrectAnswer != null) {
      _handleCorrectAnswerMissed();
    }
  }

  @override
  void onAnswerMissed(FallingAnswer answer) {
    if (answer.isCorrect) {
      _handleCorrectAnswerMissed();
    } else {
      answer.removeFromParent();
    }
  }

  @override
  void onAnswerTapped(FallingAnswer answer) {
    handleTap(answer);
  }

  /// 处理点击答案。
  void handleTap(FallingAnswer answer) {
    if (!_started || state != GameState.playing) {
      return;
    }

    if (answer.isCorrect) {
      _playSfx(_clickFile);
      _clearAnswers();
      correctCount++;
      correctCountListenable.value = correctCount;
      nextQuestion();
    } else {
      _recordWrongAnswer(answer.text);
      _endGame();
    }
  }

  /// 进入下一题；答对 100 题时通关。
  void nextQuestion() {
    if (correctCount >= winningCorrectCount) {
      _endGame();
      return;
    }

    _loadQuestion();
    spawnAnswers();
  }

  /// 按当前答对题数生成对应难度的题目并通知 HUD。
  void _loadQuestion() {
    currentQuestion = _questionGenerator.generateQuestion(correctCount);
    currentQuestionListenable.value = currentQuestion;
  }

  void _handleCorrectAnswerMissed() {
    if (state != GameState.playing || !_started) {
      return;
    }
    _recordWrongAnswer('');
    _endGame();
  }

  void _recordWrongAnswer(String userAnswer) {
    final question = currentQuestion;
    if (question == null) {
      return;
    }
    wrongRecords.add(
      WrongRecord(
        question: question,
        userAnswer: userAnswer,
        timestamp: DateTime.now(),
      ),
    );
    unawaited(StorageUtil.saveWrongRecords(wrongRecords));
  }

  void _endGame() {
    state = GameState.gameOver;
    _started = false;
    _clearAnswers();
    if (correctCount > bestScore) {
      bestScore = correctCount;
      unawaited(StorageUtil.saveBestScore(bestScore));
    }
    if (correctCount < winningCorrectCount) {
      _playSfx(_failFile);
    }
    overlays.remove(hudOverlay);
    overlays.add(gameOverOverlay);
  }

  void _clearAnswers() {
    final answers = world.children.whereType<FallingAnswer>().toList();
    for (final answer in answers) {
      answer.removeFromParent();
    }
  }

  /// overlays 的构建器，交给 GameWidget 使用。
  static Map<String, OverlayWidgetBuilder<QuizGame>> get overlayBuilderMap {
    return {
      mainMenuOverlay: (context, game) =>
          _overlaySurface(_MainMenuOverlay(game: game)),
      hudOverlay: (context, game) => _overlaySurface(_HudOverlay(game: game)),
      gameOverOverlay: (context, game) =>
          _overlaySurface(_GameOverOverlay(game: game)),
      wrongBookOverlay: (context, game) =>
          _overlaySurface(_WrongBookOverlay(game: game)),
    };
  }

  /// 为 overlay 提供 Material 祖先，避免文字继承调试用的默认样式（黄色下划线）。
  static Widget _overlaySurface(Widget child) {
    return Material(type: MaterialType.transparency, child: child);
  }
}

class _MainMenuOverlay extends StatelessWidget {
  const _MainMenuOverlay({required this.game});

  final QuizGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB3E5FC), Color(0xFFE1D5FF), Color(0xFFFFDCE9)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '答案坠落',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF23405C),
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Colors.white70,
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '点击正确答案，别让正确答案掉出屏幕',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A637D),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🏆 历史最高答对：${game.bestScore} 题',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB07800),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: game.startGame,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3D7EBF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('开始游戏'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        game.overlays.add(QuizGame.wrongBookOverlay),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3D5A80),
                      side: const BorderSide(
                        color: Color(0xFF3D5A80),
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text('查看错题本（${game.wrongRecords.length}）'),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SoundToggle(game: game),
            ),
          ),
        ),
      ],
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.game});

  final QuizGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _BackToMenuButton(game: game),
                const SizedBox(width: 8),
                _SoundToggle(game: game),
                const Spacer(),
                IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: game.correctCountListenable,
                    builder: (context, count, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1E2A3D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '正确 $count / ${QuizGame.winningCorrectCount}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            IgnorePointer(
              child: ValueListenableBuilder<Question?>(
                valueListenable: game.currentQuestionListenable,
                builder: (context, question, _) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 48,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          question?.text ?? '',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToMenuButton extends StatelessWidget {
  const _BackToMenuButton({required this.game});

  final QuizGame game;

  Future<void> _confirmAndExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('返回主界面'),
          content: const Text('确定要退出并返回主界面吗？当前进度将丢失'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      game.exitToMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _confirmAndExit(context),
      tooltip: '返回主界面',
      color: Colors.white,
      style: IconButton.styleFrom(backgroundColor: const Color(0xCC1E2A3D)),
      icon: const Icon(Icons.arrow_back),
    );
  }
}

class _SoundToggle extends StatelessWidget {
  const _SoundToggle({required this.game});

  final QuizGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.soundEnabled,
      builder: (context, enabled, _) {
        return IconButton(
          onPressed: game.toggleSound,
          tooltip: enabled ? '关闭音效' : '开启音效',
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: const Color(0xCC1E2A3D)),
          icon: Icon(enabled ? Icons.volume_up : Icons.volume_off),
        );
      },
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game});

  final QuizGame game;

  @override
  Widget build(BuildContext context) {
    final won = game.correctCount >= QuizGame.winningCorrectCount;
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    won ? '通关！' : '游戏结束',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('本局答对题数：${game.correctCount}'),
                  const SizedBox(height: 4),
                  Text('历史最高：${game.bestScore} 题'),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: game.startGame,
                        child: const Text('重新开始'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            game.overlays.add(QuizGame.wrongBookOverlay),
                        child: const Text('查看错题本'),
                      ),
                      TextButton(
                        onPressed: game.exitToMenu,
                        child: const Text('返回主菜单'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WrongBookOverlay extends StatelessWidget {
  const _WrongBookOverlay({required this.game});

  final QuizGame game;

  @override
  Widget build(BuildContext context) {
    final records = game.wrongRecords.reversed.toList();
    return ColoredBox(
      color: const Color(0xFF0E1626),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        game.overlays.remove(QuizGame.wrongBookOverlay),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '错题本（${records.length}）',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          '还没有错题记录',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _WrongRecordTile(record: records[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongRecordTile extends StatelessWidget {
  const _WrongRecordTile({required this.record});

  final WrongRecord record;

  @override
  Widget build(BuildContext context) {
    final userAnswer = record.userAnswer.isEmpty ? '未作答' : record.userAnswer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2740),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.question.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案：${record.question.correctAnswer}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7BE495),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '你的答案：$userAnswer',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '时间：${_formatTime(record.timestamp)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
