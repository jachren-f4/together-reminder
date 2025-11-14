# Side Quest Integration - Technical Specification

**Status:** Planning
**Last Updated:** 2025-11-14
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [User Requirements](#user-requirements)
3. [Current State Analysis](#current-state-analysis)
4. [Architecture Design](#architecture-design)
5. [Implementation Phases](#implementation-phases)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Provider Implementations](#provider-implementations)
8. [LP Award Strategy](#lp-award-strategy)
9. [UI/UX Specifications](#uiux-specifications)
10. [Completion Hooks](#completion-hooks)
11. [Testing Protocol](#testing-protocol)
12. [Extensibility Guide](#extensibility-guide)
13. [Edge Cases & Considerations](#edge-cases--considerations)

---

## Overview

This document specifies the integration of Word Ladder and Memory Flip games into the Daily Quest system as **side quests**. Side quests are optional activities that complement the 3 daily quests, providing additional engagement opportunities for couples.

### Key Features

- **Available Pool Pattern**: Both side quests always offered initially
- **Progressive Hiding**: Once started, quest disappears until completed
- **Persistent**: Side quests don't expire daily, persist until completed
- **Dual Display**: Shown on home screen AND Activities screen with badges
- **Fixed Reward**: 30 LP per side quest completion (quest-only, no game LP)
- **Extensible**: Easy to add 3rd, 4th, 5th side quest types

---

## User Requirements

### Specified by User

1. **Display Location**: Both home screen (side quest section) AND Activities screen (with quest badges)

2. **Memory Flip Completion**: Quest completes when weekly puzzle is fully solved (not daily progress)

3. **Availability Strategy**:
   - Always offer both Word Ladder and Memory Flip initially
   - If one is started, hide it until completed
   - Once completed, offer both again
   - Easy to add 3rd content type (new game, quiz variant, etc.)

4. **LP Rewards**: Always award 30 LP per completed side quest (quest-only, game LP rewards removed)

---

## Current State Analysis

### What's Ready ✅

**Data Models:**
- `DailyQuest.isSideQuest` field exists (defaultValue: false)
- `DailyQuest.sortOrder` field exists (for ordering)
- `QuestType.wordLadder` and `QuestType.memoryFlip` enums defined
- `DailyQuestCompletion.sideQuestsCompleted` tracking field exists

**Storage Layer:**
- `DailyQuestService.getSideQuests()` method implemented
- `DailyQuestService.getMainDailyQuests()` separates main/side
- Completion tracking distinguishes main vs side quest counts

**Sync Layer:**
- `QuestSyncService` syncs `isSideQuest` field to Firebase
- Firebase RTDB schema supports side quest data

**Provider Pattern:**
- `QuestProvider` abstract interface defined
- `QuestTypeManager.registerProvider()` method exists
- Extensible design ready for new quest types

### What's Missing ❌

**Providers:**
- `WordLadderQuestProvider` - NOT implemented
- `MemoryFlipQuestProvider` - NOT implemented
- Only `QuizQuestProvider` currently registered

**Generation Logic:**
- No side quest generation method
- `QuestTypeManager.generateDailyQuests()` only creates quiz quests
- No persistence logic for uncompleted side quests

**UI Components:**
- `DailyQuestsWidget` only displays main quests
- No side quest section on home screen
- No quest badges on Activities screen game cards
- Navigation TODOs exist but not implemented

**Completion Tracking:**
- Game completion screens don't trigger quest completion
- No connection between game completion and quest system

---

## Architecture Design

### Side Quest Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    App Initialization                         │
│  - Check for existing side quests in Hive                     │
│  - If none exist OR all completed → Generate new side quests  │
│  - Load from Firebase if partner already generated            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
          ┌─────────────────────────────────┐
          │  Side Quests Available (2)      │
          │  - Word Ladder (pending)        │
          │  - Memory Flip (pending)        │
          └────────┬────────────────────────┘
                   │
                   ├─── User taps Word Ladder ───┐
                   │                              │
                   ▼                              ▼
    ┌──────────────────────────┐    ┌────────────────────────┐
    │  Word Ladder Started     │    │  Memory Flip Pending   │
    │  status: 'in_progress'   │    │  status: 'pending'     │
    │  Hidden from home screen │    │  Still visible         │
    └──────────┬───────────────┘    └────────────────────────┘
               │
               ├─── User completes ladder ──┐
               │                             │
               ▼                             ▼
    ┌──────────────────────────┐    ┌────────────────────────┐
    │  Word Ladder Completed   │    │  Partner Completes Too │
    │  status: 'completed'     │    │  Both users done ✅     │
    │  userCompletions[alice]  │    │                        │
    └──────────┬───────────────┘    └────────┬───────────────┘
               │                              │
               └──────────┬───────────────────┘
                          │
                          ▼
          ┌─────────────────────────────────┐
          │  Award 30 LP to Both Users      │
          │  Save to Firebase /lp_awards/   │
          │  Delete completed side quests   │
          └────────┬────────────────────────┘
                   │
                   ▼
          ┌─────────────────────────────────┐
          │  Regenerate Side Quests (2)     │
          │  - Word Ladder (new, pending)   │
          │  - Memory Flip (pending)        │
          └─────────────────────────────────┘
```

### Provider Pattern Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  QuestTypeManager                         │
│                                                           │
│  Registered Providers:                                    │
│  ┌─────────────────┐  ┌──────────────────┐             │
│  │ QuizQuestProv.  │  │ WordLadderQuest  │             │
│  │                 │  │ Provider         │             │
│  │ - Generate quiz │  │ - Create session │             │
│  │ - Track progr.  │  │ - Validate done  │             │
│  └─────────────────┘  └──────────────────┘             │
│                                                           │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ MemoryFlipQuest  │  │ [Future Provider]│            │
│  │ Provider         │  │                  │            │
│  │ - Get puzzle ID  │  │ - Easy to add    │            │
│  │ - Validate done  │  │ - Implements     │            │
│  └──────────────────┘  │   QuestProvider  │            │
│                        └──────────────────┘            │
│                                                           │
│  Methods:                                                 │
│  - generateDailyQuests() → 3 main quests                 │
│  - generateSideQuests() → 2 side quests (NEW)            │
│  - persistUntilCompleted() → Keep in-progress (NEW)      │
└──────────────────────────────────────────────────────────┘
```

### Quest Status Flow

```
Side Quest States:

┌─────────┐
│ pending │  → Visible on home screen, can start
└────┬────┘
     │ User starts game
     ▼
┌─────────────┐
│ in_progress │  → Hidden from home screen, visible in Activities
└────┬────────┘
     │ User completes game
     ▼
┌────────────┐
│  completed │  → Both users done, award LP, delete quest
└────────────┘
```

**Key Difference from Daily Quests:**
- Daily quests expire at 23:59:59
- Side quests persist across days until completed
- Side quests hidden when in_progress (avoid clutter)

---

## Implementation Phases

### Phase 1: Quest Providers

**Goal:** Implement WordLadderQuestProvider and MemoryFlipQuestProvider

**File:** `app/lib/services/quest_type_manager.dart`

**1.1: WordLadderQuestProvider**

```dart
class WordLadderQuestProvider implements QuestProvider {
  final LadderService _ladderService;
  final StorageService _storage;

  WordLadderQuestProvider({
    required LadderService ladderService,
    required StorageService storage,
  })  : _ladderService = ladderService,
        _storage = storage;

  @override
  QuestType get questType => QuestType.wordLadder;

  @override
  Future<String?> generateQuest({
    required String dateKey,
    required int sortOrder,
    String? currentUserId,
    String? partnerUserId,
  }) async {
    try {
      // Create new ladder session via LadderService
      final session = await _ladderService.createNewLadderSession();

      if (session == null) {
        print('❌ Failed to create Word Ladder session');
        return null;
      }

      // Return session ID as contentId
      return session.id;
    } catch (e) {
      print('❌ Error generating Word Ladder quest: $e');
      return null;
    }
  }

  @override
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  }) async {
    try {
      // Load ladder session
      final session = _ladderService.getLadderSession(contentId);

      if (session == null) {
        print('⚠️  Word Ladder session not found: $contentId');
        return false;
      }

      // Check if session is completed
      return session.isCompleted;
    } catch (e) {
      print('❌ Error validating Word Ladder completion: $e');
      return false;
    }
  }
}
```

**1.2: MemoryFlipQuestProvider**

```dart
class MemoryFlipQuestProvider implements QuestProvider {
  final MemoryFlipService _memoryService;
  final StorageService _storage;

  MemoryFlipQuestProvider({
    required MemoryFlipService memoryService,
    required StorageService storage,
  })  : _memoryService = memoryService,
        _storage = storage;

  @override
  QuestType get questType => QuestType.memoryFlip;

  @override
  Future<String?> generateQuest({
    required String dateKey,
    required int sortOrder,
    String? currentUserId,
    String? partnerUserId,
  }) async {
    try {
      // Get or create current weekly puzzle
      // Memory Flip has weekly puzzles, so we reference existing puzzle
      final puzzle = await _memoryService.getCurrentPuzzle();

      if (puzzle == null) {
        print('❌ Failed to get Memory Flip puzzle');
        return null;
      }

      // Return puzzle ID as contentId
      return puzzle.id;
    } catch (e) {
      print('❌ Error generating Memory Flip quest: $e');
      return null;
    }
  }

  @override
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  }) async {
    try {
      // Load puzzle
      final puzzle = _storage.memoryPuzzlesBox.get(contentId);

      if (puzzle == null) {
        print('⚠️  Memory Flip puzzle not found: $contentId');
        return false;
      }

      // Check if puzzle is fully completed
      return puzzle.isCompleted;
    } catch (e) {
      print('❌ Error validating Memory Flip completion: $e');
      return false;
    }
  }
}
```

**1.3: Register Providers**

Update `QuestTypeManager` initialization:

```dart
// Current (line ~209)
registerProvider(QuizQuestProvider(storage: storage));

// Add these:
registerProvider(WordLadderQuestProvider(
  ladderService: LadderService(storage: storage),
  storage: storage,
));

registerProvider(MemoryFlipQuestProvider(
  memoryService: MemoryFlipService(storage: storage),
  storage: storage,
));
```

---

### Phase 2: Side Quest Generation Logic

**Goal:** Add method to generate persistent side quests

**File:** `app/lib/services/quest_type_manager.dart`

**2.1: Add generateSideQuests() Method**

```dart
/// Generate side quests (Word Ladder + Memory Flip)
/// Side quests persist until completed, don't regenerate daily
Future<List<DailyQuest>> generateSideQuests({
  required String currentUserId,
  required String partnerUserId,
}) async {
  print('🎮 Generating side quests...');

  final sideQuests = <DailyQuest>[];
  final dateKey = _getTodayDateKey();

  // Check if we already have uncompleted side quests
  final existingSideQuests = _storage.dailyQuestsBox.values
      .where((q) => q.isSideQuest && q.status != 'completed')
      .toList();

  if (existingSideQuests.isNotEmpty) {
    print('✓ Found ${existingSideQuests.length} existing side quests, not regenerating');
    return existingSideQuests;
  }

  // Generate Word Ladder side quest
  final wordLadderProvider = _providers[QuestType.wordLadder];
  if (wordLadderProvider != null) {
    final contentId = await wordLadderProvider.generateQuest(
      dateKey: dateKey,
      sortOrder: 3, // Side quests start at sortOrder 3
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
    );

    if (contentId != null) {
      final quest = DailyQuest.create(
        dateKey: dateKey,
        questType: QuestType.wordLadder,
        contentId: contentId,
        sortOrder: 3,
        isSideQuest: true,
        expiresAt: DateTime.now().add(Duration(days: 365)), // Don't expire
      );

      await _storage.saveDailyQuest(quest);
      sideQuests.add(quest);
      print('✓ Generated Word Ladder side quest: ${quest.id}');
    }
  }

  // Generate Memory Flip side quest
  final memoryFlipProvider = _providers[QuestType.memoryFlip];
  if (memoryFlipProvider != null) {
    final contentId = await memoryFlipProvider.generateQuest(
      dateKey: dateKey,
      sortOrder: 4,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
    );

    if (contentId != null) {
      final quest = DailyQuest.create(
        dateKey: dateKey,
        questType: QuestType.memoryFlip,
        contentId: contentId,
        sortOrder: 4,
        isSideQuest: true,
        expiresAt: DateTime.now().add(Duration(days: 365)), // Don't expire
      );

      await _storage.saveDailyQuest(quest);
      sideQuests.add(quest);
      print('✓ Generated Memory Flip side quest: ${quest.id}');
    }
  }

  print('✅ Generated ${sideQuests.length} side quests');
  return sideQuests;
}
```

**2.2: Update Initialization**

Add side quest generation to sync flow:

```dart
// In QuestSyncService.syncTodayQuests()
// After generating/loading main quests:

// Generate side quests if needed
final sideQuests = await _questTypeManager.generateSideQuests(
  currentUserId: currentUserId,
  partnerUserId: partnerUserId,
);

// Sync side quests to Firebase (same path as main quests)
if (sideQuests.isNotEmpty) {
  await saveQuestsToFirebase(sideQuests, currentUserId);
}
```

---

### Phase 3: LP Award System

**Goal:** Award 30 LP when side quest completed by both users

**File:** `app/lib/services/daily_quest_service.dart`

**3.1: Update completeQuestForUser()**

```dart
// Around line 101-120 (existing completion logic)

Future<void> completeQuestForUser({
  required String questId,
  required String userId,
}) async {
  final quest = _storage.getDailyQuest(questId);
  if (quest == null) return;

  // Mark user completion
  quest.userCompletions ??= {};
  quest.userCompletions![userId] = true;

  // Check if both users completed
  if (quest.areBothUsersCompleted()) {
    quest.status = 'completed';
    quest.completedAt = DateTime.now();

    // Award LP for side quests (30 LP)
    if (quest.isSideQuest) {
      print('🎉 Side quest completed by both users: ${quest.id}');

      final user = _storage.currentUser;
      final partner = _storage.currentPartner;

      if (user != null && partner != null) {
        final lovePointService = LovePointService();
        await lovePointService.awardPointsToBothUsers(
          amount: 30, // Fixed side quest reward
          reason: 'side_quest_completed:${quest.questType}',
          user1Id: user.id,
          user2Id: partner.pushToken,
          description: 'Completed ${quest.questType.name} side quest',
        );

        quest.lpAwarded = 30;
        print('✅ Awarded 30 LP to both users for side quest');
      }
    } else {
      // Existing main quest LP logic (non-quiz quests)
      // ... (keep existing code)
    }
  } else {
    quest.status = 'in_progress';
  }

  await _storage.updateDailyQuest(quest);
}
```

**3.2: Cleanup Completed Side Quests**

Add method to remove completed side quests (trigger regeneration):

```dart
/// Remove completed side quests to allow new ones to generate
Future<void> cleanupCompletedSideQuests() async {
  final completedSideQuests = _storage.dailyQuestsBox.values
      .where((q) => q.isSideQuest && q.status == 'completed')
      .toList();

  for (final quest in completedSideQuests) {
    await quest.delete();
    print('🧹 Removed completed side quest: ${quest.id}');
  }
}
```

Call this in `completeQuestForUser()` after awarding LP:

```dart
// After LP award for side quest
await cleanupCompletedSideQuests();

// Trigger regeneration
final questTypeManager = QuestTypeManager(storage: _storage);
await questTypeManager.generateSideQuests(
  currentUserId: user.id,
  partnerUserId: partner.pushToken,
);
```

---

### Phase 4: UI Display - Home Screen

**Goal:** Add side quests section to home screen below daily quests

**File:** `app/lib/widgets/daily_quests_widget.dart`

**4.1: Load Side Quests**

Update state to include side quests:

```dart
class _DailyQuestsWidgetState extends State<DailyQuestsWidget> {
  List<DailyQuest> _mainQuests = [];
  List<DailyQuest> _sideQuests = []; // NEW
  bool _isLoading = true;

  // ... existing code

  Future<void> _loadQuests() async {
    setState(() => _isLoading = true);

    // Load main quests
    _mainQuests = _questService.getMainDailyQuests();

    // Load side quests (only show pending ones)
    final allSideQuests = _questService.getSideQuests();
    _sideQuests = allSideQuests
        .where((q) => q.status == 'pending') // Hide in-progress
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    setState(() => _isLoading = false);
  }
}
```

**4.2: Display Side Quests Section**

Add side quest section below main quests:

```dart
@override
Widget build(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Existing main quests section
      _buildMainQuestsSection(),

      // NEW: Side quests section
      if (_sideQuests.isNotEmpty) ...[
        SizedBox(height: 16),
        _buildSideQuestsSection(),
      ],
    ],
  );
}

Widget _buildSideQuestsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Side Quests (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ),
      SizedBox(height: 8),

      // Display side quest cards horizontally
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: _sideQuests.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(right: 12),
              child: _buildSideQuestCard(_sideQuests[index]),
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildSideQuestCard(DailyQuest quest) {
  return GestureDetector(
    onTap: () => _handleQuestTap(quest),
    child: Container(
      width: 160,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getQuestIcon(quest.questType),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getQuestTitle(quest.questType),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.amber),
              SizedBox(width: 4),
              Text(
                '+30 LP',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _getQuestTitle(QuestType type) {
  switch (type) {
    case QuestType.wordLadder:
      return 'Word Ladder';
    case QuestType.memoryFlip:
      return 'Memory Flip';
    default:
      return 'Side Quest';
  }
}

Widget _getQuestIcon(QuestType type) {
  IconData icon;
  Color color;

  switch (type) {
    case QuestType.wordLadder:
      icon = Icons.text_fields;
      color = Colors.blue;
      break;
    case QuestType.memoryFlip:
      icon = Icons.extension;
      color = Colors.purple;
      break;
    default:
      icon = Icons.star;
      color = Colors.amber;
  }

  return Icon(icon, size: 20, color: color);
}
```

**4.3: Update Navigation**

Implement navigation for Word Ladder and Memory Flip:

```dart
Future<void> _handleQuestTap(DailyQuest quest) async {
  // Mark quest as in_progress when started
  if (quest.status == 'pending') {
    quest.status = 'in_progress';
    await _storage.updateDailyQuest(quest);

    // Sync to Firebase
    await _questSyncService.markQuestStarted(quest.id, _userId!);

    // Hide from UI
    setState(() {
      _sideQuests.remove(quest);
    });
  }

  // Navigate to game screen
  switch (quest.questType) {
    case QuestType.wordLadder:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordLadderGameScreen(
            sessionId: quest.contentId,
            isFromQuest: true, // NEW flag
          ),
        ),
      );
      break;

    case QuestType.memoryFlip:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemoryFlipGameScreen(
            isFromQuest: true, // NEW flag
          ),
        ),
      );
      break;

    default:
      _showError('Quest type not supported yet');
  }
}
```

---

### Phase 5: UI Display - Activities Screen

**Goal:** Add quest badges to game cards when active as side quests

**File:** `app/lib/screens/activities_screen.dart`

**5.1: Check for Active Side Quests**

Add method to check if game has active quest:

```dart
class _ActivitiesScreenState extends State<ActivitiesScreen> {
  Map<QuestType, DailyQuest?> _activeSideQuests = {};

  @override
  void initState() {
    super.initState();
    _loadActiveSideQuests();
  }

  Future<void> _loadActiveSideQuests() async {
    final storage = StorageService();
    final questService = DailyQuestService(storage: storage);

    final sideQuests = questService.getSideQuests();
    final inProgressQuests = sideQuests.where((q) =>
      q.status == 'in_progress'
    ).toList();

    setState(() {
      for (final quest in inProgressQuests) {
        _activeSideQuests[quest.questType] = quest;
      }
    });
  }
}
```

**5.2: Add Quest Badge to Game Cards**

Update Word Ladder and Memory Flip cards:

```dart
// Word Ladder card (around line 532-669)
Widget _buildWordLadderCard(BuildContext context) {
  final hasActiveQuest = _activeSideQuests.containsKey(QuestType.wordLadder);

  return Stack(
    children: [
      // Existing card UI
      _buildGameCard(
        context: context,
        title: 'Word Ladder',
        // ... existing properties
      ),

      // NEW: Quest badge
      if (hasActiveQuest)
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'QUEST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

// Memory Flip card (around line 672-805)
Widget _buildMemoryFlipCard(BuildContext context) {
  final hasActiveQuest = _activeSideQuests.containsKey(QuestType.memoryFlip);

  return Stack(
    children: [
      // Existing card UI
      _buildGameCard(
        context: context,
        title: 'Memory Flip',
        // ... existing properties
      ),

      // NEW: Quest badge
      if (hasActiveQuest)
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'QUEST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
```

---

### Phase 6: Completion Hooks

**Goal:** Connect game completion to quest completion tracking

**6.1: Word Ladder Completion**

**File:** `app/lib/screens/word_ladder_completion_screen.dart`

Add quest completion check:

```dart
@override
void initState() {
  super.initState();
  _checkQuestCompletion();
}

Future<void> _checkQuestCompletion() async {
  final storage = StorageService();
  final questService = DailyQuestService(storage: storage);

  // Find Word Ladder quest with this session ID
  final allQuests = storage.dailyQuestsBox.values.toList();
  final quest = allQuests.firstWhereOrNull(
    (q) => q.questType == QuestType.wordLadder.index &&
           q.contentId == widget.sessionId &&
           q.isSideQuest == true
  );

  if (quest != null && !quest.isCompleted) {
    print('✓ Word Ladder quest found, completing for user');

    final user = storage.currentUser;
    if (user != null) {
      await questService.completeQuestForUser(
        questId: quest.id,
        userId: user.id,
      );

      // Sync to Firebase
      final questSyncService = QuestSyncService(
        storage: storage,
        questService: questService,
      );
      await questSyncService.markQuestCompleted(quest.id, user.id);

      print('✅ Word Ladder side quest completed');
    }
  }
}
```

**6.2: Memory Flip Completion**

**File:** `app/lib/services/memory_flip_service.dart`

Add quest completion check in puzzle completion logic:

```dart
// In attemptMatch() method, after puzzle.isCompleted check (around line 254-258)

if (puzzle.isCompleted && !wasCompleted) {
  // REMOVE existing LP award code (lines 254-258)
  // LP awards now handled ONLY by quest system

  // NEW: Check for Memory Flip quest
  await _checkQuestCompletion(puzzle.id);
}

Future<void> _checkQuestCompletion(String puzzleId) async {
  final questService = DailyQuestService(storage: _storage);

  // Find Memory Flip quest with this puzzle ID
  final allQuests = _storage.dailyQuestsBox.values.toList();
  final quest = allQuests.firstWhereOrNull(
    (q) => q.questType == QuestType.memoryFlip.index &&
           q.contentId == puzzleId &&
           q.isSideQuest == true
  );

  if (quest != null && !quest.isCompleted) {
    print('✓ Memory Flip quest found, completing for user');

    final user = _storage.currentUser;
    if (user != null) {
      await questService.completeQuestForUser(
        questId: quest.id,
        userId: user.id,
      );

      // Sync to Firebase
      final questSyncService = QuestSyncService(
        storage: _storage,
        questService: questService,
      );
      await questSyncService.markQuestCompleted(quest.id, user.id);

      print('✅ Memory Flip side quest completed');
    }
  }
}
```

---

### Phase 7: Testing & Validation

**Goal:** Verify side quest flow end-to-end

**7.1: Clean Testing Protocol**

```bash
# 1. Clear all data
bash /tmp/clear_firebase.sh

# 2. Kill Flutter processes
pkill -9 -f "flutter"

# 3. Launch apps
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &  # Alice
sleep 10 && flutter run -d chrome &  # Bob
```

**7.2: Verification Checklist**

**Initial State:**
- [ ] 3 daily quests generated (Quiz × 3)
- [ ] 2 side quests generated (Word Ladder + Memory Flip)
- [ ] Side quests visible on home screen under "Side Quests (Optional)"
- [ ] Side quests visible in Activities screen (no badges yet)

**Starting Side Quest:**
- [ ] Tap Word Ladder side quest from home screen
- [ ] Quest status changes to 'in_progress'
- [ ] Word Ladder disappears from home screen
- [ ] Memory Flip still visible on home screen
- [ ] Word Ladder shows "QUEST" badge in Activities screen
- [ ] Navigate to Word Ladder game screen successfully

**Completing Side Quest (Single User):**
- [ ] Complete Word Ladder game
- [ ] Quest completion triggered in completion screen
- [ ] `completeQuestForUser()` called for current user
- [ ] Quest status = 'in_progress' (waiting for partner)
- [ ] Quest synced to Firebase
- [ ] Partner sees completion in Firebase RTDB

**Completing Side Quest (Both Users):**
- [ ] Partner completes same Word Ladder session
- [ ] Quest status changes to 'completed'
- [ ] 30 LP awarded to both users
- [ ] LP award saved to Firebase `/lp_awards/`
- [ ] Completed quest deleted from local storage
- [ ] New Word Ladder side quest generated
- [ ] Both side quests visible on home screen again

**Memory Flip Side Quest:**
- [ ] Start Memory Flip side quest
- [ ] Memory Flip disappears from home screen
- [ ] "QUEST" badge appears in Activities screen
- [ ] Make progress on weekly puzzle
- [ ] Complete weekly puzzle
- [ ] Quest completion triggered
- [ ] Both users complete → 30 LP awarded
- [ ] New Memory Flip quest generated

**Partner Synchronization:**
- [ ] Alice starts Word Ladder → Bob sees it in-progress
- [ ] Alice completes → Bob's UI updates
- [ ] Bob completes → Both receive 30 LP
- [ ] Both devices regenerate side quests simultaneously

**Firebase Verification:**
```
/daily_quests/{coupleId}/{dateKey}/
  quests: [
    { id: "quest_..._quiz", questType: 1, isSideQuest: false, sortOrder: 0 },
    { id: "quest_..._quiz", questType: 1, isSideQuest: false, sortOrder: 1 },
    { id: "quest_..._quiz", questType: 1, isSideQuest: false, sortOrder: 2 },
    { id: "quest_..._wordLadder", questType: 3, isSideQuest: true, sortOrder: 3 },
    { id: "quest_..._memoryFlip", questType: 4, isSideQuest: true, sortOrder: 4 }
  ]
  completions: {
    quest_..._wordLadder: {
      alice-dev-user-...: true,
      bob-dev-user-...: true
    }
  }

/lp_awards/{coupleId}/{awardId}/
  user1:
    userId: "alice-dev-user-..."
    amount: 30
    reason: "side_quest_completed:wordLadder"
    timestamp: ...
  user2:
    userId: "bob-dev-user-..."
    amount: 30
    reason: "side_quest_completed:wordLadder"
    timestamp: ...
```

---

## Data Flow Diagrams

### Side Quest Generation Flow

```
User Launches App
│
├─▶ Initialize Services (main.dart)
│   ├─ Firebase Init
│   ├─ Hive Init
│   └─ Quest Sync
│
├─▶ QuestSyncService.syncTodayQuests()
│   │
│   ├─▶ Generate/Load Main Quests (3)
│   │
│   └─▶ Generate/Load Side Quests (2)
│       │
│       ├─▶ Check Existing Side Quests
│       │   ├─ [Has Uncompleted] → Return existing
│       │   └─ [None/All Completed] → Generate new
│       │
│       └─▶ Generate New Side Quests
│           │
│           ├─▶ WordLadderQuestProvider.generateQuest()
│           │   ├─ Create new ladder session
│           │   ├─ Save session to Hive
│           │   └─ Return session ID
│           │
│           ├─▶ Create DailyQuest
│           │   ├─ isSideQuest: true
│           │   ├─ sortOrder: 3
│           │   ├─ expiresAt: far future (365 days)
│           │   └─ status: 'pending'
│           │
│           ├─▶ MemoryFlipQuestProvider.generateQuest()
│           │   ├─ Get current weekly puzzle
│           │   └─ Return puzzle ID
│           │
│           ├─▶ Create DailyQuest
│           │   ├─ isSideQuest: true
│           │   ├─ sortOrder: 4
│           │   └─ status: 'pending'
│           │
│           └─▶ Save Side Quests
│               ├─ Save to Hive (local)
│               └─ Save to Firebase RTDB
│
└─▶ Display in UI
    ├─ Home Screen: Side quests section
    └─ Activities Screen: Quest badges
```

### Side Quest Completion Flow

```
User Completes Game (Word Ladder / Memory Flip)
│
├─▶ Game Completion Screen
│   └─ Check for related side quest
│       ├─ Search: questType + contentId + isSideQuest
│       └─ Found quest → Continue
│
├─▶ DailyQuestService.completeQuestForUser()
│   │
│   ├─▶ Mark User Completion
│   │   └─ quest.userCompletions[userId] = true
│   │
│   ├─▶ Check Both Users Completed
│   │   │
│   │   ├─ [NO] → status = 'in_progress'
│   │   │   ├─ Save to Hive
│   │   │   ├─ Sync to Firebase
│   │   │   └─ Wait for partner
│   │   │
│   │   └─ [YES] → status = 'completed'
│   │       │
│   │       ├─▶ Award LP (Side Quest)
│   │       │   ├─ LovePointService.awardPointsToBothUsers()
│   │       │   ├─ amount: 30 LP
│   │       │   ├─ reason: "side_quest_completed:wordLadder"
│   │       │   └─ Save to Firebase /lp_awards/
│   │       │
│   │       ├─▶ Cleanup Completed Quest
│   │       │   └─ quest.delete() from Hive
│   │       │
│   │       └─▶ Regenerate Side Quests
│   │           ├─ Check existing uncompleted
│   │           └─ Generate new if all completed
│   │
│   └─▶ Sync to Firebase
│       └─ /daily_quests/{coupleId}/{dateKey}/completions/
│
└─▶ Partner's Device
    ├─ Firebase listener fires
    ├─ Update local quest
    ├─ Trigger LP award (if both complete)
    └─ UI updates automatically
```

### Display Logic Flow

```
Home Screen - DailyQuestsWidget
│
├─▶ Load Main Quests
│   ├─ questService.getMainDailyQuests()
│   └─ Display in "Daily Quests" section
│
└─▶ Load Side Quests
    │
    ├─▶ questService.getSideQuests()
    │
    ├─▶ Filter by Status
    │   ├─ [pending] → Show in side quest section
    │   ├─ [in_progress] → HIDE (show in Activities only)
    │   └─ [completed] → HIDE (will be deleted)
    │
    └─▶ Display Side Quest Cards
        ├─ Horizontal scrollable list
        ├─ Show quest icon + title
        ├─ Show "+30 LP" reward
        └─ Tap → Start quest, navigate to game

Activities Screen - Game Cards
│
├─▶ Load Active Side Quests
│   ├─ Filter: isSideQuest == true && status == 'in_progress'
│   └─ Map: questType → quest
│
└─▶ Display Game Cards
    │
    ├─▶ Word Ladder Card
    │   ├─ [Has Active Quest] → Show "QUEST" badge
    │   └─ [No Quest] → Normal card
    │
    └─▶ Memory Flip Card
        ├─ [Has Active Quest] → Show "QUEST" badge
        └─ [No Quest] → Normal card
```

---

## LP Award Strategy

### Simplified Quest-Only Reward System

**Memory Flip Example:**

```
User completes Memory Flip puzzle (both users)
│
├─▶ Game Completion (Memory Flip Service)
│   └─ NO LP awarded by game service
│
├─▶ Quest Completion (Daily Quest Service)
│   └─ Award 30 LP for side quest completion
│
└─▶ Total LP per User: 30 LP
```

**Rationale:**
- Simplifies reward system (single source of LP awards)
- Consistent 30 LP reward across all side quests
- Removes complex game-specific LP calculations
- All LP awards flow through quest system for better tracking

**Migration Note:**
- **Remove** existing LP awards from MemoryFlipService (10 LP per match, 50-130 LP completion)
- **Remove** existing LP awards from WordLadderService (if any)
- **Keep only** quest-based 30 LP awards via DailyQuestService

### LP Award Deduplication

**Scenario:** Both users complete side quest simultaneously

**Protection:**
- `LovePointService.awardPointsToBothUsers()` uses unique award ID
- Award ID format: `sidequest_{questId}_{timestamp}`
- Firebase transaction ensures single award per quest
- Local tracking in `app_metadata` box prevents double-application

**Example:**
```
/lp_awards/{coupleId}/sidequest_quest_123_1699999999/
  user1: { userId: "alice", amount: 30, ... }
  user2: { userId: "bob", amount: 30, ... }
```

If both devices try to award simultaneously, Firebase transaction ensures only one write succeeds.

---

## UI/UX Specifications

### Home Screen Layout

```
┌───────────────────────────────────────────┐
│  Good morning, Alice!                     │
│                                           │
│  Daily Quests (2/3)                       │
│  ┌─────────────┐ ┌─────────────┐         │
│  │ Quiz 1  ✓   │ │ Quiz 2  ✓   │         │
│  └─────────────┘ └─────────────┘         │
│  ┌─────────────┐                          │
│  │ Quiz 3  ○   │                          │
│  └─────────────┘                          │
│                                           │
│  Side Quests (Optional)                   │
│  ┌──────────┐ ┌──────────┐               │
│  │ 🎮 Word  │ │ 🧩 Memory│               │
│  │  Ladder  │ │   Flip   │               │
│  │ +30 LP   │ │ +30 LP   │               │
│  └──────────┘ └──────────┘               │
│                                           │
│  [+ Remind Partner]                       │
└───────────────────────────────────────────┘
```

**Key Elements:**
- Side quests section appears below daily quests
- Horizontal scrollable if many side quests (future-proof)
- Clear separation with "Side Quests (Optional)" header
- Smaller cards than daily quests (less prominent)
- LP reward displayed prominently (+30 LP)

### Activities Screen Layout

```
┌───────────────────────────────────────────┐
│  ← Activities                             │
│                                           │
│  ┌────────────────────────┐               │
│  │  Word Ladder        ⭐  │               │
│  │                   QUEST │               │
│  │  Build word chains      │               │
│  │  by changing one        │               │
│  │  letter at a time       │               │
│  │                         │               │
│  │  [🔷 Alice] [🔶 Bob]    │               │
│  │  Turn: 12  Turn: 15     │               │
│  └────────────────────────┘               │
│                                           │
│  ┌────────────────────────┐               │
│  │  Memory Flip        ⭐  │               │
│  │                   QUEST │               │
│  │  Match emoji pairs      │               │
│  │  together in this       │               │
│  │  weekly puzzle          │               │
│  │                         │               │
│  │  Progress: 4/8 pairs    │               │
│  └────────────────────────┘               │
└───────────────────────────────────────────┘
```

**Key Elements:**
- "QUEST" badge positioned top-right
- Badge color matches quest type (amber = Word Ladder, purple = Memory Flip)
- Badge only appears when quest status = 'in_progress'
- Rest of card maintains existing design
- Badge pulses or has subtle animation (optional)

### Quest State Visual Indicators

**Pending (Available):**
- Card has normal opacity
- "+30 LP" shown clearly
- Tap to start quest

**In Progress (Home Screen):**
- Card hidden from home screen
- Only visible in Activities screen with badge

**In Progress (Activities Screen):**
- "QUEST" badge displayed
- Card has subtle highlight/glow
- Progress indicators maintained

**Completed:**
- Card removed from both locations
- Regenerated as new pending quest
- Brief toast: "New side quests available!"

---

## Extensibility Guide

### Adding a 3rd Side Quest Type

**Example: Add "You or Me" game as side quest**

**Step 1: Define Quest Type**

```dart
// lib/models/daily_quest.dart
enum QuestType {
  question,
  quiz,
  game,
  wordLadder,
  memoryFlip,
  youOrMe,  // NEW
}
```

**Step 2: Create Provider**

```dart
// lib/services/quest_type_manager.dart
class YouOrMeQuestProvider implements QuestProvider {
  final YouOrMeService _youOrMeService;
  final StorageService _storage;

  YouOrMeQuestProvider({
    required YouOrMeService youOrMeService,
    required StorageService storage,
  })  : _youOrMeService = youOrMeService,
        _storage = storage;

  @override
  QuestType get questType => QuestType.youOrMe;

  @override
  Future<String?> generateQuest({...}) async {
    // Create You or Me session
    final session = await _youOrMeService.createSession();
    return session?.id;
  }

  @override
  Future<bool> validateCompletion({...}) async {
    final session = _youOrMeService.getSession(contentId);
    return session?.isCompleted ?? false;
  }
}
```

**Step 3: Register Provider**

```dart
// lib/services/quest_type_manager.dart - initialization
registerProvider(YouOrMeQuestProvider(
  youOrMeService: YouOrMeService(storage: storage),
  storage: storage,
));
```

**Step 4: Update Generation**

```dart
// lib/services/quest_type_manager.dart - generateSideQuests()

// After Memory Flip generation, add:
final youOrMeProvider = _providers[QuestType.youOrMe];
if (youOrMeProvider != null) {
  final contentId = await youOrMeProvider.generateQuest(
    dateKey: dateKey,
    sortOrder: 5, // Next sortOrder
    currentUserId: currentUserId,
    partnerUserId: partnerUserId,
  );

  if (contentId != null) {
    final quest = DailyQuest.create(
      dateKey: dateKey,
      questType: QuestType.youOrMe,
      contentId: contentId,
      sortOrder: 5,
      isSideQuest: true,
      expiresAt: DateTime.now().add(Duration(days: 365)),
    );

    await _storage.saveDailyQuest(quest);
    sideQuests.add(quest);
  }
}
```

**Step 5: Add UI**

```dart
// lib/widgets/daily_quests_widget.dart
String _getQuestTitle(QuestType type) {
  switch (type) {
    case QuestType.wordLadder:
      return 'Word Ladder';
    case QuestType.memoryFlip:
      return 'Memory Flip';
    case QuestType.youOrMe:  // NEW
      return 'You or Me';
    default:
      return 'Side Quest';
  }
}

Widget _getQuestIcon(QuestType type) {
  switch (type) {
    // ... existing cases
    case QuestType.youOrMe:  // NEW
      icon = Icons.people;
      color = Colors.green;
      break;
  }
}

// Navigation
case QuestType.youOrMe:  // NEW
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => YouOrMeScreen(
        sessionId: quest.contentId,
        isFromQuest: true,
      ),
    ),
  );
  break;
```

**Step 6: Add Completion Hook**

```dart
// lib/screens/you_or_me_results_screen.dart
@override
void initState() {
  super.initState();
  _checkQuestCompletion();
}

Future<void> _checkQuestCompletion() async {
  final storage = StorageService();
  final questService = DailyQuestService(storage: storage);

  final allQuests = storage.dailyQuestsBox.values.toList();
  final quest = allQuests.firstWhereOrNull(
    (q) => q.questType == QuestType.youOrMe.index &&
           q.contentId == widget.sessionId &&
           q.isSideQuest == true
  );

  if (quest != null && !quest.isCompleted) {
    final user = storage.currentUser;
    if (user != null) {
      await questService.completeQuestForUser(
        questId: quest.id,
        userId: user.id,
      );

      final questSyncService = QuestSyncService(
        storage: storage,
        questService: questService,
      );
      await questSyncService.markQuestCompleted(quest.id, user.id);
    }
  }
}
```

**That's it!** ~50 lines of code to add a new side quest type.

---

## Edge Cases & Considerations

### 1. Orphaned Sessions

**Problem:** Side quest references session/puzzle that no longer exists

**Scenario:**
- User starts Word Ladder side quest (creates session)
- User deletes app data (session lost)
- Side quest still references old session ID

**Solution:**
```dart
// In quest tap handler
Future<void> _handleQuestTap(DailyQuest quest) async {
  // Validate session exists
  if (quest.questType == QuestType.wordLadder) {
    final session = _ladderService.getLadderSession(quest.contentId);
    if (session == null) {
      // Session missing - delete quest and regenerate
      await quest.delete();
      await _regenerateSideQuests();
      _showError('Quest data missing, generating new quest');
      return;
    }
  }

  // Continue with navigation...
}
```

### 2. Partner Sync Timing

**Problem:** User completes quest, but partner hasn't started yet

**Scenario:**
- Alice starts Word Ladder (status: in_progress)
- Alice completes Word Ladder
- Alice's completion syncs to Firebase
- Bob hasn't started Word Ladder yet
- Bob's device sees Alice completed, marks quest as in_progress locally
- Bob eventually completes, triggers LP award

**Current Behavior:** Works correctly
- DailyQuestService tracks per-user completion
- LP awarded only when both users complete
- Firebase sync ensures both devices stay synchronized

### 3. Persistence Across Days

**Problem:** Side quests don't expire, but daily quests do

**Scenario:**
- Monday: User starts Word Ladder side quest
- Tuesday: Daily quests refresh, Word Ladder quest still in-progress
- User completes Word Ladder on Tuesday
- Quest completion on Tuesday awards LP

**Current Behavior:** Works as designed
- Side quests have far-future expiration (365 days)
- Daily quest cleanup ignores side quests (`!q.isSideQuest` filter)
- Firebase RTDB keeps side quest data separate from daily quest date keys

**Consideration:** Should side quests use date-independent Firebase path?

**Current Path:**
```
/daily_quests/{coupleId}/{dateKey}/quests/
```

**Alternative Path:**
```
/side_quests/{coupleId}/{questId}/
```

**Recommendation:** Keep current path for simplicity, but add cleanup for very old side quests:

```dart
Future<void> cleanupOldSideQuests() async {
  final allSideQuests = _storage.dailyQuestsBox.values
      .where((q) => q.isSideQuest)
      .toList();

  final now = DateTime.now();
  for (final quest in allSideQuests) {
    final age = now.difference(quest.createdAt).inDays;
    if (age > 30 && quest.status != 'completed') {
      // Side quest abandoned for 30 days - clean up
      await quest.delete();
      print('🧹 Cleaned up abandoned side quest: ${quest.id}');
    }
  }
}
```

### 4. Memory Flip Weekly Puzzle Timing

**Problem:** Memory Flip has weekly puzzles (Monday-Sunday)

**Scenario 1: Quest Generated Mid-Week**
- Wednesday: User starts Memory Flip side quest
- References current weekly puzzle (expires Sunday)
- Thursday: User completes puzzle
- Quest completes, awards LP

**Scenario 2: Quest Spans Week Boundary**
- Saturday: User starts Memory Flip side quest
- References Puzzle A (expires Sunday)
- Monday: New weekly puzzle (Puzzle B) generated
- User tries to complete quest - references old Puzzle A

**Potential Issue:** Old puzzle may be deleted

**Solution:**
```dart
// In MemoryFlipService - don't delete puzzles referenced by quests
Future<void> cleanupOldPuzzles() async {
  final questService = DailyQuestService(storage: _storage);
  final activeSideQuests = questService.getSideQuests()
      .where((q) => q.questType == QuestType.memoryFlip.index &&
                    q.status != 'completed')
      .toList();

  final protectedPuzzleIds = activeSideQuests
      .map((q) => q.contentId)
      .toSet();

  // Only delete puzzles not referenced by quests
  final oldPuzzles = _storage.memoryPuzzlesBox.values
      .where((p) => !protectedPuzzleIds.contains(p.id))
      .toList();

  // Delete old puzzles...
}
```

### 5. Multiple In-Progress Side Quests

**Problem:** Current design hides in-progress quests from home screen

**Scenario:**
- User starts Word Ladder (hidden)
- User starts Memory Flip (hidden)
- Home screen shows no side quests
- User forgets they have in-progress quests

**Solution:** Add "In Progress" section to home screen:

```dart
Widget build(BuildContext context) {
  final pendingSideQuests = _sideQuests.where((q) => q.status == 'pending');
  final inProgressSideQuests = _sideQuests.where((q) => q.status == 'in_progress');

  return Column(
    children: [
      _buildMainQuestsSection(),

      if (inProgressSideQuests.isNotEmpty)
        _buildInProgressSection(inProgressSideQuests),

      if (pendingSideQuests.isNotEmpty)
        _buildAvailableSection(pendingSideQuests),
    ],
  );
}
```

### 6. Firebase Sync Race Condition

**Problem:** Both devices generate side quests simultaneously

**Scenario:**
- Alice and Bob launch app at same time
- Both check Firebase - no side quests exist
- Both generate side quests with different IDs
- Quest ID mismatch between devices

**Solution:** Use "first creates, second loads" pattern (same as daily quests)

```dart
// In QuestSyncService
Future<void> syncSideQuests() async {
  // Check Firebase for existing side quests
  final firebaseSideQuests = await _loadSideQuestsFromFirebase();

  if (firebaseSideQuests.isNotEmpty) {
    // Load existing side quests (preserve IDs)
    await _loadAndSaveSideQuests(firebaseSideQuests);
  } else {
    // Generate new side quests
    final sideQuests = await _questTypeManager.generateSideQuests(...);
    await _saveSideQuestsToFirebase(sideQuests);
  }
}
```

### 7. LP Award Double Claiming

**Problem:** Both users trigger LP award simultaneously

**Current Protection:**
- `LovePointService.awardPointsToBothUsers()` uses unique award ID
- Firebase RTDB transaction ensures atomic write
- Local deduplication via `app_metadata` box

**Additional Safety:**
```dart
// In DailyQuestService.completeQuestForUser()
if (quest.lpAwarded != null && quest.lpAwarded! > 0) {
  print('⚠️  LP already awarded for quest ${quest.id}, skipping');
  return;
}

// Award LP...
quest.lpAwarded = 30;
await _storage.updateDailyQuest(quest);
```

### 8. Navigation from Two Locations

**Problem:** User can access game from home screen OR Activities screen

**Scenario:**
- User has in-progress Word Ladder quest
- Quest hidden from home screen
- User taps Word Ladder card in Activities screen
- Should navigate to same session

**Solution:** Pass session ID to game screen:

```dart
// From side quest card (home screen)
Navigator.push(context, MaterialPageRoute(
  builder: (_) => WordLadderGameScreen(
    sessionId: quest.contentId,  // Quest's session
    isFromQuest: true,
  ),
));

// From Activities screen
Navigator.push(context, MaterialPageRoute(
  builder: (_) => WordLadderGameScreen(
    sessionId: _currentSession?.id,  // Current session
    isFromQuest: false,
  ),
));
```

If session IDs match → same game. If different → separate games (quest vs standalone).

---

## Summary

### Implementation Checklist

- [ ] **Phase 1:** Create WordLadderQuestProvider and MemoryFlipQuestProvider
- [ ] **Phase 2:** Add generateSideQuests() method to QuestTypeManager
- [ ] **Phase 3:** Update LP award system for side quests (30 LP)
- [ ] **Phase 4:** Add side quest section to home screen
- [ ] **Phase 5:** Add quest badges to Activities screen
- [ ] **Phase 6:** Add completion hooks to game screens
- [ ] **Phase 7:** Test end-to-end flow with clean restart

### Key Design Decisions

✅ **Available Pool Pattern:** Both quests offered initially, hide when started
✅ **Persistent:** Side quests don't expire daily, persist until completed
✅ **Dual Display:** Home screen (pending) + Activities screen (in-progress)
✅ **Fixed Reward:** 30 LP per side quest (quest-only, no game LP)
✅ **Extensible:** Provider pattern makes adding new quests trivial

### Files Modified

1. `app/lib/services/quest_type_manager.dart` - Providers + generation
2. `app/lib/services/daily_quest_service.dart` - LP awards + cleanup
3. `app/lib/widgets/daily_quests_widget.dart` - Home screen display
4. `app/lib/screens/activities_screen.dart` - Quest badges
5. `app/lib/screens/word_ladder_completion_screen.dart` - Completion hook
6. `app/lib/services/memory_flip_service.dart` - Completion hook

### Estimated Effort

**Implementation:** 4-6 hours
**Testing:** 2 hours
**Total:** 6-8 hours

---

**Next Steps:** Review this spec, get approval, then begin Phase 1 implementation.

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-14
**Status:** Ready for Implementation
