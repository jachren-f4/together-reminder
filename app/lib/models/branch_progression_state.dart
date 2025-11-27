import 'package:hive/hive.dart';

part 'branch_progression_state.g.dart';

/// Activity types that support branching content
enum BranchableActivityType {
  classicQuiz,
  affirmation,
  youOrMe,
  linked,
  wordSearch,
}

/// Branch folder names per activity type
const Map<BranchableActivityType, List<String>> branchFolderNames = {
  BranchableActivityType.classicQuiz: ['lighthearted', 'deeper', 'spicy'],
  BranchableActivityType.affirmation: ['emotional', 'practical', 'spiritual'],
  BranchableActivityType.youOrMe: ['playful', 'reflective', 'intimate'],
  BranchableActivityType.linked: ['casual', 'romantic', 'adult'],
  BranchableActivityType.wordSearch: ['everyday', 'passionate', 'naughty'],
};

/// Tracks branch progression for a single activity type per couple.
///
/// Each couple has one BranchProgressionState per activity type.
/// The currentBranch cycles through 0, 1, 2... based on totalCompletions % maxBranches.
///
/// Storage: Hive (local) + Supabase via API (authoritative)
@HiveType(typeId: 26)
class BranchProgressionState extends HiveObject {
  @HiveField(0)
  late String coupleId;

  /// Stored as int for Hive compatibility
  @HiveField(1)
  late int activityTypeIndex;

  /// Current branch index: 0 = A, 1 = B, 2 = C
  @HiveField(2, defaultValue: 0)
  int currentBranch;

  /// Total number of completions for this activity type
  @HiveField(3, defaultValue: 0)
  int totalCompletions;

  /// Maximum number of branches (2 for A/B, 3 for A/B/C)
  @HiveField(4, defaultValue: 2)
  int maxBranches;

  /// Last completion timestamp
  @HiveField(5)
  DateTime? lastCompletedAt;

  /// Creation timestamp
  @HiveField(6)
  late DateTime createdAt;

  BranchProgressionState({
    required this.coupleId,
    required this.activityTypeIndex,
    this.currentBranch = 0,
    this.totalCompletions = 0,
    this.maxBranches = 2,
    this.lastCompletedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create initial state for a new couple/activity
  factory BranchProgressionState.initial(
    String coupleId,
    BranchableActivityType activityType,
  ) {
    return BranchProgressionState(
      coupleId: coupleId,
      activityTypeIndex: activityType.index,
    );
  }

  /// Get the activity type enum
  BranchableActivityType get activityType =>
      BranchableActivityType.values[activityTypeIndex];

  /// Get the current branch letter (A, B, C)
  String get currentBranchLetter =>
      String.fromCharCode('A'.codeUnitAt(0) + currentBranch);

  /// Get the current branch folder name (e.g., 'lighthearted', 'deeper')
  String get currentBranchFolder {
    final folders = branchFolderNames[activityType];
    if (folders == null || currentBranch >= folders.length) {
      return folders?.first ?? 'default';
    }
    return folders[currentBranch];
  }

  /// Mark activity as completed and advance to next branch
  void completeActivity() {
    totalCompletions++;
    lastCompletedAt = DateTime.now();
    currentBranch = totalCompletions % maxBranches;
  }

  /// Storage key for Hive: "{coupleId}_{activityType}"
  String get storageKey => '${coupleId}_${activityType.name}';

  /// Convert to JSON for API sync
  Map<String, dynamic> toJson() => {
        'couple_id': coupleId,
        'activity_type': activityType.name,
        'current_branch': currentBranch,
        'total_completions': totalCompletions,
        'max_branches': maxBranches,
        'last_completed_at': lastCompletedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  /// Create from API response
  factory BranchProgressionState.fromJson(Map<String, dynamic> json) {
    final activityTypeName = json['activity_type'] as String;
    final activityType = BranchableActivityType.values.firstWhere(
      (t) => t.name == activityTypeName,
      orElse: () => BranchableActivityType.classicQuiz,
    );

    return BranchProgressionState(
      coupleId: json['couple_id'] as String,
      activityTypeIndex: activityType.index,
      currentBranch: json['current_branch'] as int? ?? 0,
      totalCompletions: json['total_completions'] as int? ?? 0,
      maxBranches: json['max_branches'] as int? ?? 2,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'BranchProgressionState(couple=$coupleId, activity=${activityType.name}, '
      'branch=$currentBranchFolder [$currentBranch], completions=$totalCompletions)';
}
