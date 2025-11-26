import 'package:hive/hive.dart';

part 'linked.g.dart';

/// Enum representing the 5 possible states of the Linked card on the home screen
enum LinkedCardState {
  yourTurnFresh, // Active, your turn, no locked cells yet
  partnerTurnFresh, // Active, partner's turn, no locked cells yet
  yourTurnInProgress, // Active, your turn, has locked cells
  partnerTurnInProgress, // Active, partner's turn, has locked cells
  completed, // Puzzle finished
}

@HiveType(typeId: 23)
class LinkedMatch extends HiveObject {
  @HiveField(0)
  late String matchId;

  @HiveField(1)
  late String puzzleId;

  @HiveField(2, defaultValue: 'active')
  String status; // 'active' or 'completed'

  @HiveField(3, defaultValue: {})
  Map<String, String> boardState; // cellIndex (as string) -> locked letter

  @HiveField(4, defaultValue: [])
  List<String> currentRack; // Letters available to place (max 5)

  @HiveField(5, defaultValue: null)
  String? currentTurnUserId;

  @HiveField(6, defaultValue: 1)
  int turnNumber;

  @HiveField(7, defaultValue: 0)
  int player1Score;

  @HiveField(8, defaultValue: 0)
  int player2Score;

  @HiveField(9, defaultValue: 2)
  int player1Vision; // Hint power-ups remaining

  @HiveField(10, defaultValue: 2)
  int player2Vision; // Hint power-ups remaining

  @HiveField(11, defaultValue: 0)
  int lockedCellCount;

  @HiveField(12, defaultValue: 0)
  int totalAnswerCells;

  @HiveField(13, defaultValue: null)
  DateTime? completedAt;

  @HiveField(14)
  late DateTime createdAt;

  @HiveField(15, defaultValue: null)
  String? coupleId;

  @HiveField(16, defaultValue: null)
  String? player1Id;

  @HiveField(17, defaultValue: null)
  String? player2Id;

  @HiveField(18, defaultValue: null)
  String? winnerId;

  LinkedMatch({
    required this.matchId,
    required this.puzzleId,
    this.status = 'active',
    Map<String, String>? boardState,
    List<String>? currentRack,
    this.currentTurnUserId,
    this.turnNumber = 1,
    this.player1Score = 0,
    this.player2Score = 0,
    this.player1Vision = 2,
    this.player2Vision = 2,
    this.lockedCellCount = 0,
    this.totalAnswerCells = 0,
    this.completedAt,
    required this.createdAt,
    this.coupleId,
    this.player1Id,
    this.player2Id,
    this.winnerId,
  })  : boardState = boardState ?? {},
        currentRack = currentRack ?? [];

  // Helper methods
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';

  double get progressPercentage =>
      totalAnswerCells > 0 ? (lockedCellCount / totalAnswerCells) : 0.0;

  int get progressPercent => (progressPercentage * 100).round();

  bool get isFresh => lockedCellCount == 0;
  bool get isInProgress => lockedCellCount > 0 && !isCompleted;

  /// Get the card state based on match status and current user
  LinkedCardState getCardState(String userId) {
    if (isCompleted) {
      return LinkedCardState.completed;
    }

    final isMyTurn = currentTurnUserId == userId;

    if (isFresh) {
      return isMyTurn
          ? LinkedCardState.yourTurnFresh
          : LinkedCardState.partnerTurnFresh;
    } else {
      return isMyTurn
          ? LinkedCardState.yourTurnInProgress
          : LinkedCardState.partnerTurnInProgress;
    }
  }

  /// Get user's score
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
  int getUserVision(String userId) {
    if (userId == player1Id) return player1Vision;
    if (userId == player2Id) return player2Vision;
    return 0;
  }

  /// Check if user won (only valid when completed)
  bool? didUserWin(String userId) {
    if (!isCompleted || winnerId == null) return null;
    return winnerId == userId;
  }

  /// Create a copy with updated fields
  LinkedMatch copyWith({
    String? matchId,
    String? puzzleId,
    String? status,
    Map<String, String>? boardState,
    List<String>? currentRack,
    String? currentTurnUserId,
    int? turnNumber,
    int? player1Score,
    int? player2Score,
    int? player1Vision,
    int? player2Vision,
    int? lockedCellCount,
    int? totalAnswerCells,
    DateTime? completedAt,
    DateTime? createdAt,
    String? coupleId,
    String? player1Id,
    String? player2Id,
    String? winnerId,
  }) {
    return LinkedMatch(
      matchId: matchId ?? this.matchId,
      puzzleId: puzzleId ?? this.puzzleId,
      status: status ?? this.status,
      boardState: boardState ?? Map.from(this.boardState),
      currentRack: currentRack ?? List.from(this.currentRack),
      currentTurnUserId: currentTurnUserId ?? this.currentTurnUserId,
      turnNumber: turnNumber ?? this.turnNumber,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      player1Vision: player1Vision ?? this.player1Vision,
      player2Vision: player2Vision ?? this.player2Vision,
      lockedCellCount: lockedCellCount ?? this.lockedCellCount,
      totalAnswerCells: totalAnswerCells ?? this.totalAnswerCells,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      coupleId: coupleId ?? this.coupleId,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}

/// Puzzle data structure (not stored in Hive, loaded from API)
class LinkedPuzzle {
  final String puzzleId;
  final String title;
  final String author;
  final int rows;
  final int cols;
  final Map<String, LinkedClue> clues; // Clue number -> clue data
  final List<int> gridnums; // Clue numbers at each cell (0 = no clue)
  final List<String> cellTypes; // 'void', 'clue', or 'answer' for each cell
  // Note: grid (solution) is never sent to client

  LinkedPuzzle({
    required this.puzzleId,
    required this.title,
    required this.author,
    required this.rows,
    required this.cols,
    required this.clues,
    required this.gridnums,
    required this.cellTypes,
  });

  int get totalCells => rows * cols;

  /// Check if cell at index is a void cell
  bool isVoidCell(int index) =>
      index < cellTypes.length && cellTypes[index] == 'void';

  /// Check if cell at index is a clue cell
  bool isClueCell(int index) =>
      index < cellTypes.length && cellTypes[index] == 'clue';

  /// Check if cell at index is an answer cell
  bool isAnswerCell(int index) =>
      index < cellTypes.length && cellTypes[index] == 'answer';

  /// Count total answer cells
  int countAnswerCells() => cellTypes.where((t) => t == 'answer').length;

  factory LinkedPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    final cluesJson = json['clues'] as Map<String, dynamic>;

    final clues = cluesJson.map((key, value) {
      final clueNum = int.tryParse(key) ?? 0;
      return MapEntry(
        key,
        LinkedClue.fromJson(value as Map<String, dynamic>, clueNumber: clueNum),
      );
    });

    return LinkedPuzzle(
      puzzleId: json['puzzleId'] ?? 'unknown',
      title: json['title'] ?? 'Linked Puzzle',
      author: json['author'] ?? 'Unknown',
      rows: size['rows'] as int,
      cols: size['cols'] as int,
      clues: clues,
      gridnums: List<int>.from(json['gridnums'] ?? []),
      cellTypes: List<String>.from(json['cellTypes'] ?? []),
    );
  }
}

/// Clue data structure
class LinkedClue {
  final int number; // Clue number
  final String type; // 'text'
  final String content; // Clue text
  final String arrow; // 'across' or 'down'
  final int targetIndex; // Grid index where answer starts
  final int length; // Number of letters in answer

  LinkedClue({
    required this.number,
    required this.type,
    required this.content,
    required this.arrow,
    required this.targetIndex,
    required this.length,
  });

  bool get isAcross => arrow == 'across';
  bool get isDown => arrow == 'down';

  factory LinkedClue.fromJson(Map<String, dynamic> json, {int? clueNumber}) {
    return LinkedClue(
      number: clueNumber ?? json['number'] as int? ?? 0,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      arrow: json['arrow'] as String? ?? 'across',
      targetIndex: json['target_index'] as int? ?? 0,
      length: json['length'] as int? ?? 0,
    );
  }
}

/// Result from submitting a turn
class LinkedTurnResult {
  final List<LinkedPlacementResult> results;
  final int pointsEarned;
  final List<LinkedCompletedWord> completedWords;
  final int newScore;
  final bool gameComplete;
  final List<String>? nextRack;
  final String? winnerId;

  LinkedTurnResult({
    required this.results,
    required this.pointsEarned,
    required this.completedWords,
    required this.newScore,
    required this.gameComplete,
    this.nextRack,
    this.winnerId,
  });

  /// Number of correct placements
  int get correctCount => results.where((r) => r.correct).length;

  /// Total number of placements
  int get totalPlaced => results.length;

  /// Whether all placements were correct
  bool get allCorrect => results.isNotEmpty && correctCount == totalPlaced;

  factory LinkedTurnResult.fromJson(Map<String, dynamic> json) {
    return LinkedTurnResult(
      results: (json['results'] as List<dynamic>?)
              ?.map((r) =>
                  LinkedPlacementResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      completedWords: (json['completedWords'] as List<dynamic>?)
              ?.map((w) =>
                  LinkedCompletedWord.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      newScore: json['newScore'] as int? ?? 0,
      gameComplete: json['gameComplete'] as bool? ?? false,
      nextRack: (json['nextRack'] as List<dynamic>?)?.cast<String>(),
      winnerId: json['winnerId'] as String?,
    );
  }
}

/// Result for a single letter placement
class LinkedPlacementResult {
  final int cellIndex;
  final bool correct;

  LinkedPlacementResult({
    required this.cellIndex,
    required this.correct,
  });

  factory LinkedPlacementResult.fromJson(Map<String, dynamic> json) {
    return LinkedPlacementResult(
      cellIndex: json['cellIndex'] as int,
      correct: json['correct'] as bool,
    );
  }
}

/// A completed word from turn submission
class LinkedCompletedWord {
  final String word;
  final List<int> cells;
  final int bonus;

  LinkedCompletedWord({
    required this.word,
    required this.cells,
    required this.bonus,
  });

  factory LinkedCompletedWord.fromJson(Map<String, dynamic> json) {
    return LinkedCompletedWord(
      word: json['word'] as String,
      cells: List<int>.from(json['cells'] ?? []),
      bonus: json['bonus'] as int? ?? 0,
    );
  }
}

/// Result from using a hint
class LinkedHintResult {
  final List<int> validCells; // Cells where rack letters can be correctly placed
  final int hintsRemaining;

  LinkedHintResult({
    required this.validCells,
    required this.hintsRemaining,
  });

  factory LinkedHintResult.fromJson(Map<String, dynamic> json) {
    return LinkedHintResult(
      validCells: List<int>.from(json['validCells'] ?? []),
      hintsRemaining: json['hintsRemaining'] as int? ?? 0,
    );
  }
}

/// Draft placement (before submission)
class LinkedDraftPlacement {
  final int cellIndex;
  final String letter;
  final int rackIndex; // Which slot the letter came from

  LinkedDraftPlacement({
    required this.cellIndex,
    required this.letter,
    required this.rackIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'cellIndex': cellIndex,
      'letter': letter,
    };
  }
}
