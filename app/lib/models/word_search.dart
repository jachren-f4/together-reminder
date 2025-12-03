import 'package:hive/hive.dart';

part 'word_search.g.dart';

/// Enum representing the possible states of the Word Search card on the home screen
enum WordSearchCardState {
  yourTurnFresh, // Your turn, 0 words found this turn
  yourTurnInProgress, // Your turn, 1-2 words found this turn
  partnerTurn, // Partner's turn, waiting
  completed, // All 12 words found
}

// ============================================
// FOUND WORD (embedded in match)
// ============================================

@HiveType(typeId: 24)
class WordSearchFoundWord extends HiveObject {
  @HiveField(0)
  late String word;

  @HiveField(1)
  late String foundByUserId;

  @HiveField(2)
  late int turnNumber;

  @HiveField(3, defaultValue: [])
  List<Map<String, int>> positions; // [{row: 0, col: 5}, ...]

  @HiveField(4, defaultValue: 0)
  int colorIndex;

  WordSearchFoundWord({
    required this.word,
    required this.foundByUserId,
    required this.turnNumber,
    List<Map<String, int>>? positions,
    this.colorIndex = 0,
  }) : positions = positions ?? [];

  factory WordSearchFoundWord.fromJson(Map<String, dynamic> json) {
    return WordSearchFoundWord(
      word: json['word'] as String,
      foundByUserId: json['foundBy'] as String,
      turnNumber: json['turnNumber'] as int? ?? 1,
      positions: (json['positions'] as List<dynamic>?)
              ?.map((p) => Map<String, int>.from({
                    'row': (p['row'] as num).toInt(),
                    'col': (p['col'] as num).toInt(),
                  }))
              .toList() ??
          [],
      colorIndex: json['colorIndex'] as int? ?? 0,
    );
  }
}

// ============================================
// MATCH (persisted in Hive)
// ============================================

@HiveType(typeId: 25)
class WordSearchMatch extends HiveObject {
  @HiveField(0)
  late String matchId;

  @HiveField(1)
  late String puzzleId;

  @HiveField(2, defaultValue: 'active')
  String status;

  @HiveField(3, defaultValue: [])
  List<WordSearchFoundWord> foundWords;

  @HiveField(4)
  String? currentTurnUserId;

  @HiveField(5, defaultValue: 1)
  int turnNumber;

  @HiveField(6, defaultValue: 0)
  int wordsFoundThisTurn;

  @HiveField(7, defaultValue: 0)
  int player1WordsFound;

  @HiveField(8, defaultValue: 0)
  int player2WordsFound;

  @HiveField(16, defaultValue: 0)
  int player1Score;

  @HiveField(17, defaultValue: 0)
  int player2Score;

  @HiveField(9, defaultValue: 3)
  int player1Hints;

  @HiveField(10, defaultValue: 3)
  int player2Hints;

  @HiveField(11)
  late String player1Id;

  @HiveField(12)
  late String player2Id;

  @HiveField(13)
  String? winnerId;

  @HiveField(14)
  late DateTime createdAt;

  @HiveField(15)
  DateTime? completedAt;

  WordSearchMatch({
    required this.matchId,
    required this.puzzleId,
    this.status = 'active',
    List<WordSearchFoundWord>? foundWords,
    this.currentTurnUserId,
    this.turnNumber = 1,
    this.wordsFoundThisTurn = 0,
    this.player1WordsFound = 0,
    this.player2WordsFound = 0,
    this.player1Score = 0,
    this.player2Score = 0,
    this.player1Hints = 3,
    this.player2Hints = 3,
    required this.player1Id,
    required this.player2Id,
    this.winnerId,
    required this.createdAt,
    this.completedAt,
  }) : foundWords = foundWords ?? [];

  // Helper getters
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  int get totalWordsFound => foundWords.length;
  int get wordsRemainingThisTurn => 3 - wordsFoundThisTurn;
  /// Progress as fraction (0.0 to 1.0) - matches Linked naming convention
  double get progressPercentage => totalWordsFound / 12.0;
  /// Progress as percentage (0 to 100) - matches Linked naming convention
  int get progressPercent => (progressPercentage * 100).round();

  /// Check if this is the start of a turn (no words found yet this turn)
  bool get isTurnFresh => wordsFoundThisTurn == 0;

  /// Check if turn is in progress (1-2 words found)
  bool get isTurnInProgress => wordsFoundThisTurn > 0 && wordsFoundThisTurn < 3;

  /// Get the card state based on match status and current user
  WordSearchCardState getCardState(String userId) {
    if (isCompleted) {
      return WordSearchCardState.completed;
    }

    final isMyTurn = currentTurnUserId == userId;

    if (isMyTurn) {
      return isTurnFresh
          ? WordSearchCardState.yourTurnFresh
          : WordSearchCardState.yourTurnInProgress;
    } else {
      return WordSearchCardState.partnerTurn;
    }
  }

  /// Get user's word count
  int getUserWordCount(String userId) {
    if (userId == player1Id) return player1WordsFound;
    if (userId == player2Id) return player2WordsFound;
    return 0;
  }

  /// Get partner's word count
  int getPartnerWordCount(String userId) {
    if (userId == player1Id) return player2WordsFound;
    if (userId == player2Id) return player1WordsFound;
    return 0;
  }

  /// Get user's score (10 points per letter)
  int getUserScore(String userId) {
    if (userId == player1Id) return player1Score;
    if (userId == player2Id) return player2Score;
    return 0;
  }

  /// Get partner's score
  int getPartnerScore(String userId) {
    if (userId == player1Id) return player2Score;
    if (userId == player2Id) return player1Score;
    return 0;
  }

  /// Get user's remaining hints
  int getUserHints(String userId) {
    if (userId == player1Id) return player1Hints;
    if (userId == player2Id) return player2Hints;
    return 0;
  }

  /// Check if user won (only valid when completed)
  bool? didUserWin(String userId) {
    if (!isCompleted || winnerId == null) return null;
    return winnerId == userId;
  }

  /// Check if a word has been found
  bool isWordFound(String word) {
    return foundWords.any((fw) => fw.word == word.toUpperCase());
  }

  /// Get the found word data for a specific word
  WordSearchFoundWord? getFoundWord(String word) {
    try {
      return foundWords.firstWhere((fw) => fw.word == word.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  factory WordSearchMatch.fromJson(Map<String, dynamic> json) {
    return WordSearchMatch(
      matchId: json['matchId'] as String,
      puzzleId: json['puzzleId'] as String,
      status: json['status'] as String? ?? 'active',
      foundWords: (json['foundWords'] as List<dynamic>?)
              ?.map((fw) =>
                  WordSearchFoundWord.fromJson(fw as Map<String, dynamic>))
              .toList() ??
          [],
      currentTurnUserId: json['currentTurnUserId'] as String?,
      turnNumber: json['turnNumber'] as int? ?? 1,
      wordsFoundThisTurn: json['wordsFoundThisTurn'] as int? ?? 0,
      player1WordsFound: json['player1WordsFound'] as int? ?? 0,
      player2WordsFound: json['player2WordsFound'] as int? ?? 0,
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      player1Hints: json['player1Hints'] as int? ?? 3,
      player2Hints: json['player2Hints'] as int? ?? 3,
      player1Id: json['player1Id'] as String,
      player2Id: json['player2Id'] as String,
      winnerId: json['winnerId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  /// Create a copy with updated fields
  WordSearchMatch copyWith({
    String? matchId,
    String? puzzleId,
    String? status,
    List<WordSearchFoundWord>? foundWords,
    String? currentTurnUserId,
    int? turnNumber,
    int? wordsFoundThisTurn,
    int? player1WordsFound,
    int? player2WordsFound,
    int? player1Score,
    int? player2Score,
    int? player1Hints,
    int? player2Hints,
    String? player1Id,
    String? player2Id,
    String? winnerId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return WordSearchMatch(
      matchId: matchId ?? this.matchId,
      puzzleId: puzzleId ?? this.puzzleId,
      status: status ?? this.status,
      foundWords: foundWords ?? List.from(this.foundWords),
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      turnNumber: turnNumber ?? this.turnNumber,
      wordsFoundThisTurn: wordsFoundThisTurn ?? this.wordsFoundThisTurn,
      player1WordsFound: player1WordsFound ?? this.player1WordsFound,
      player2WordsFound: player2WordsFound ?? this.player2WordsFound,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      player1Hints: player1Hints ?? this.player1Hints,
      player2Hints: player2Hints ?? this.player2Hints,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ============================================
// PUZZLE (runtime only, not persisted)
// ============================================

class WordSearchPuzzle {
  final String puzzleId;
  final String title;
  final String? theme;
  final int rows;
  final int cols;
  final String grid; // Flat string, 100 chars for 10x10
  final List<String> words; // Just the words, no positions (client must find)

  WordSearchPuzzle({
    required this.puzzleId,
    required this.title,
    this.theme,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.words,
  });

  factory WordSearchPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;

    return WordSearchPuzzle(
      puzzleId: json['puzzleId'] as String,
      title: json['title'] as String,
      theme: json['theme'] as String?,
      rows: size['rows'] as int,
      cols: size['cols'] as int,
      grid: json['grid'] as String,
      words: (json['words'] as List<dynamic>).cast<String>(),
    );
  }

  /// Get letter at row/col
  String letterAt(int row, int col) {
    final index = (row * cols) + col;
    if (index < 0 || index >= grid.length) return '';
    return grid[index];
  }

  /// Get letter at flat index
  String letterAtIndex(int index) {
    if (index < 0 || index >= grid.length) return '';
    return grid[index];
  }

  /// Convert index to row/col
  ({int row, int col}) indexToPosition(int index) {
    return (row: index ~/ cols, col: index % cols);
  }

  /// Convert row/col to index
  int positionToIndex(int row, int col) => (row * cols) + col;

  /// Total number of cells
  int get totalCells => rows * cols;
}

// ============================================
// GAME STATE (combined API response)
// ============================================

class WordSearchGameState {
  final WordSearchMatch match;
  final WordSearchPuzzle? puzzle;
  final bool isMyTurn;
  final bool canPlay;
  final int wordsRemainingThisTurn;
  final int myWordsFound;
  final int partnerWordsFound;
  final int myScore;
  final int partnerScore;
  final int myHints;
  final int partnerHints;
  final int progressPercent;

  WordSearchGameState({
    required this.match,
    this.puzzle,
    required this.isMyTurn,
    required this.canPlay,
    required this.wordsRemainingThisTurn,
    required this.myWordsFound,
    required this.partnerWordsFound,
    required this.myScore,
    required this.partnerScore,
    required this.myHints,
    required this.partnerHints,
    required this.progressPercent,
  });

  factory WordSearchGameState.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    final matchJson = json['match'] as Map<String, dynamic>;
    final puzzleJson = json['puzzle'] as Map<String, dynamic>?;
    final gameStateJson = json['gameState'] as Map<String, dynamic>;

    return WordSearchGameState(
      match: WordSearchMatch.fromJson(matchJson),
      puzzle:
          puzzleJson != null ? WordSearchPuzzle.fromJson(puzzleJson) : null,
      isMyTurn: gameStateJson['isMyTurn'] as bool? ?? false,
      canPlay: gameStateJson['canPlay'] as bool? ?? false,
      wordsRemainingThisTurn:
          gameStateJson['wordsRemainingThisTurn'] as int? ?? 3,
      myWordsFound: gameStateJson['myWordsFound'] as int? ?? 0,
      partnerWordsFound: gameStateJson['partnerWordsFound'] as int? ?? 0,
      myScore: gameStateJson['myScore'] as int? ?? 0,
      partnerScore: gameStateJson['partnerScore'] as int? ?? 0,
      myHints: gameStateJson['myHints'] as int? ?? 3,
      partnerHints: gameStateJson['partnerHints'] as int? ?? 3,
      progressPercent: gameStateJson['progressPercent'] as int? ?? 0,
    );
  }
}

// ============================================
// API RESULT TYPES
// ============================================

/// Result from submitting a word
class WordSearchSubmitResult {
  final bool valid;
  final String? reason;
  final int pointsEarned;
  final int wordsFoundThisTurn;
  final bool turnComplete;
  final bool gameComplete;
  final String? nextTurnUserId;
  final int colorIndex;
  final String? winnerId;

  WordSearchSubmitResult({
    required this.valid,
    this.reason,
    this.pointsEarned = 0,
    this.wordsFoundThisTurn = 0,
    this.turnComplete = false,
    this.gameComplete = false,
    this.nextTurnUserId,
    this.colorIndex = 0,
    this.winnerId,
  });

  factory WordSearchSubmitResult.fromJson(Map<String, dynamic> json) {
    return WordSearchSubmitResult(
      valid: json['valid'] as bool? ?? false,
      reason: json['reason'] as String?,
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      wordsFoundThisTurn: json['wordsFoundThisTurn'] as int? ?? 0,
      turnComplete: json['turnComplete'] as bool? ?? false,
      gameComplete: json['gameComplete'] as bool? ?? false,
      nextTurnUserId: json['nextTurnUserId'] as String?,
      colorIndex: json['colorIndex'] as int? ?? 0,
      winnerId: json['winnerId'] as String?,
    );
  }
}

/// Result from using a hint
class WordSearchHintResult {
  final String word;
  final Map<String, int> firstLetterPosition;
  final int hintsRemaining;

  WordSearchHintResult({
    required this.word,
    required this.firstLetterPosition,
    required this.hintsRemaining,
  });

  int get row => firstLetterPosition['row'] ?? 0;
  int get col => firstLetterPosition['col'] ?? 0;

  factory WordSearchHintResult.fromJson(Map<String, dynamic> json) {
    final hint = json['hint'] as Map<String, dynamic>;
    final position = hint['firstLetterPosition'] as Map<String, dynamic>;

    return WordSearchHintResult(
      word: hint['word'] as String,
      firstLetterPosition: {
        'row': (position['row'] as num).toInt(),
        'col': (position['col'] as num).toInt(),
      },
      hintsRemaining: json['hintsRemaining'] as int? ?? 0,
    );
  }
}

/// Grid position helper
class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  Map<String, int> toJson() => {'row': row, 'col': col};

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'GridPosition($row, $col)';
}
