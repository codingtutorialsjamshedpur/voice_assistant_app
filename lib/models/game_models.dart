/// ═══════════════════════════════════════════════════════════════
/// Game Models — Data models for voice-controlled games
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

/// Enum for voice-controlled games
enum GameType {
  placeholder,
  ticTacToe,
  voiceAssistant,
  globalRadio,
  globalTV,
  ballSortPuzzle,
}

/// Game category for grouping in the hub
enum GameCategory {
  strategy,
  mystical,
  learning,
  brain,
  discovery,
}

/// Game phase tracking
enum GamePhase {
  menu,
  setup,
  playing,
  results,
}

/// Information about a game for display in the hub
class GameInfo {
  final GameType type;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final GameCategory category;
  final String categoryLabel;
  final bool hasTTimer;

  const GameInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.category,
    required this.categoryLabel,
    this.hasTTimer = false,
  });
}

/// Result of a completed game
class GameResult {
  final int score;
  final int total;
  final Duration timeTaken;
  final String feedbackText;
  final GameType? gameType;

  const GameResult({
    required this.score,
    required this.total,
    required this.timeTaken,
    required this.feedbackText,
    this.gameType,
  });

  double get percentage => total > 0 ? (score / total) * 100 : 0;
}

/// Tic-Tac-Toe board state
class TicTacToeBoard {
  // 3x3 grid: 0 = empty, 1 = X (player), 2 = O (AI)
  List<int> cells;
  int currentPlayer; // 1 = X, 2 = O
  int difficulty; // 0 = easy, 1 = medium, 2 = hard
  bool gameOver;
  int? winner; // null = ongoing/draw, 1 = X wins, 2 = O wins

  TicTacToeBoard({
    List<int>? cells,
    this.currentPlayer = 1,
    this.difficulty = 1,
    this.gameOver = false,
    this.winner,
  }) : cells = cells ?? List.filled(9, 0);

  TicTacToeBoard copyWith({
    List<int>? cells,
    int? currentPlayer,
    int? difficulty,
    bool? gameOver,
    int? winner,
  }) {
    return TicTacToeBoard(
      cells: cells ?? List.from(this.cells),
      currentPlayer: currentPlayer ?? this.currentPlayer,
      difficulty: difficulty ?? this.difficulty,
      gameOver: gameOver ?? this.gameOver,
      winner: winner,
    );
  }

  void reset() {
    cells = List.filled(9, 0);
    currentPlayer = 1;
    gameOver = false;
    winner = null;
  }

  /// Check for a winner. Returns 1, 2, or null.
  int? checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
      [0, 4, 8], [2, 4, 6], // diagonals
    ];
    for (final line in lines) {
      if (cells[line[0]] != 0 &&
          cells[line[0]] == cells[line[1]] &&
          cells[line[1]] == cells[line[2]]) {
        return cells[line[0]];
      }
    }
    return null;
  }

  /// Get the winning line indices, or null if no winner.
  List<int>? getWinningLine() {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      if (cells[line[0]] != 0 &&
          cells[line[0]] == cells[line[1]] &&
          cells[line[1]] == cells[line[2]]) {
        return line;
      }
    }
    return null;
  }

  bool get isBoardFull => !cells.contains(0);
  bool get isDraw => isBoardFull && checkWinner() == null;

  List<int> get availableMoves {
    final moves = <int>[];
    for (int i = 0; i < 9; i++) {
      if (cells[i] == 0) moves.add(i);
    }
    return moves;
  }
}

/// Chat message for game conversations
class GameChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  GameChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Registry of games with their display info
class GameRegistry {
  static const List<GameInfo> allGames = [
    GameInfo(
      type: GameType.ticTacToe,
      name: 'Tic-Tac-Toe 3D',
      description: 'Challenge AI in 3D style - voice-controlled',
      icon: Icons.grid_3x3,
      gradientColors: [Color(0xFF4DD9D5), Color(0xFF7C3AED)],
      category: GameCategory.strategy,
      categoryLabel: '  Strategy',
    ),
    GameInfo(
      type: GameType.voiceAssistant,
      name: 'Voice Assistant',
      description: 'Your spiritual AI voice companion',
      icon: Icons.record_voice_over_rounded,
      gradientColors: [Color(0xFFFF69B4), Color(0xFF8B5CF6)],
      category: GameCategory.brain,
      categoryLabel: '  Brain',
    ),
    GameInfo(
      type: GameType.globalRadio,
      name: 'Global Radio',
      description: 'Explore world radio stations live',
      icon: Icons.radio_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      category: GameCategory.discovery,
      categoryLabel: '  Discovery',
    ),
    GameInfo(
      type: GameType.globalTV,
      name: 'World TV Window',
      description: 'Watch global news and music channels',
      icon: Icons.tv_rounded,
      gradientColors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
      category: GameCategory.discovery,
      categoryLabel: '  Discovery',
    ),
    GameInfo(
      type: GameType.ballSortPuzzle,
      name: 'Ball Sort Puzzle',
      description: 'Sort colourful balls into matching tubes — touch, voice, or text',
      icon: Icons.bubble_chart_rounded,
      gradientColors: [Color(0xFF6C63FF), Color(0xFF3B1FA3)],
      category: GameCategory.brain,
      categoryLabel: '🧠 Brain',
      hasTTimer: false,
    ),
  ];

  static GameInfo? getInfo(GameType type) {
    try {
      return allGames.firstWhere((g) => g.type == type);
    } catch (_) {
      return null;
    }
  }
}
