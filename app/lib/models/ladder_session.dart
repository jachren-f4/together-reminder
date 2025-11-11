import 'package:hive/hive.dart';

part 'ladder_session.g.dart';

@HiveType(typeId: 9) // Badge is 6, WordPair is 8
class LadderSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String wordPairId;

  @HiveField(2)
  late String startWord;

  @HiveField(3)
  late String endWord;

  @HiveField(4)
  late List<String> wordChain; // Current progress: [LOVE, LONE, LINE]

  @HiveField(5)
  late String status; // 'active' | 'completed' | 'abandoned'

  @HiveField(6)
  late DateTime createdAt;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  late String currentTurn; // userId of player whose turn it is

  @HiveField(9)
  late String language; // 'en' | 'fi'

  @HiveField(10, defaultValue: 0)
  late int lpEarned; // Total LP earned from this ladder

  @HiveField(11)
  int? optimalSteps;

  @HiveField(12)
  String? yieldedBy; // userId of person who last yielded

  @HiveField(13)
  DateTime? yieldedAt; // When the yield happened

  @HiveField(14, defaultValue: 0)
  late int yieldCount; // How many times this ladder has been yielded

  @HiveField(15)
  String? lastAction; // 'move' | 'yielded' | 'created'

  LadderSession({
    required this.id,
    required this.wordPairId,
    required this.startWord,
    required this.endWord,
    required this.wordChain,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.currentTurn,
    required this.language,
    this.lpEarned = 0,
    this.optimalSteps,
    this.yieldedBy,
    this.yieldedAt,
    this.yieldCount = 0,
    this.lastAction,
  });

  int get stepCount => wordChain.length - 1;
  bool get isCompleted => status == 'completed';
  String get currentWord => wordChain.last;
  bool get isYielded => yieldedBy != null;
}
