# Word Ladder Duet - Implementation Plan

**Goal:** Build an asynchronous cooperative word game where couples transform one word into another by changing a single letter at a time.

**Timeline:** Week 5-6 (3-5 developer days)

**Complexity:** Medium (simpler than Leaderboard, similar to Quiz)

---

## 📝 Implementation Checklist

### Phase 1: Data Layer & Core Logic
- [ ] 1.1 Create WordPair model with Hive annotations
- [ ] 1.2 Create LadderSession model with yield fields
- [ ] 1.3 Update StorageService for ladder boxes
- [ ] 1.4 Run build_runner to generate adapters
- [ ] 1.5 Create English word list JSON (50+ words)
- [ ] 1.6 Create Finnish word list JSON (20+ words)
- [ ] 1.7 Update pubspec.yaml with word assets
- [ ] 1.8 Create WordValidationService
- [ ] 1.9 Create WordPairBank with curated pairs
- [ ] 1.10 Initialize word lists in main.dart

### Phase 2: Ladder Service & Game Logic
- [ ] 2.1 Create LadderService with createInitialLadders()
- [ ] 2.2 Implement makeMove() with validation
- [ ] 2.3 Implement yieldTurn() method
- [ ] 2.4 Implement auto-generation on completion
- [ ] 2.5 Add alternating turn assignment logic
- [ ] 2.6 Add notification methods

### Phase 3: UI Screens
- [ ] 3.1 Create WordLadderHubScreen (shows 3 ladders)
- [ ] 3.2 Create WordLadderGameScreen (gameplay)
- [ ] 3.3 Create WordLadderCompletionScreen
- [ ] 3.4 Add yield button and dialog
- [ ] 3.5 Add yield context banner for received yields
- [ ] 3.6 Add yield indicators to hub cards

### Phase 4: Cloud Functions & Integration
- [ ] 4.1 Add sendWordLadderNotification function
- [ ] 4.2 Update ActivitiesScreen with Word Ladder card
- [ ] 4.3 Test end-to-end flow with 2 devices
- [ ] 4.4 Test yield functionality
- [ ] 4.5 Test auto-generation on completion

---

## 📋 Overview

Word Ladder Duet allows couples to work together asynchronously to solve word transformation puzzles. Each player takes turns changing one letter at a time, creating valid words at each step.

**Example Ladder:**
```
LOVE → LONE → LINE → LIFE
```

**Key Features:**
- **Always 3 ladders**: System maintains exactly 3 active ladders (auto-generates new ones when completed)
- **Alternating first turns**: First turns distributed fairly between partners (A, B, A pattern)
- **Asynchronous turns**: No need for simultaneous play
- **Yield feature**: Players can yield their turn to partner if stuck (cooperative problem-solving)
- **Bilingual support**: English + Finnish word lists
- **LP rewards**: Points for valid moves and completions
- **Gentle notifications**: Warm, caring messages when partner plays

---

## 🎯 Success Criteria

Implementation is complete when:

1. ✅ System always maintains exactly 3 active ladders
2. ✅ First time opening generates 3 ladders with alternating first turns (A, B, A)
3. ✅ Completing a ladder auto-generates a new one (maintains 3 total)
4. ✅ Players alternate turns changing one letter at a time
5. ✅ Players can yield their turn to partner if stuck
6. ✅ Yielded ladders show special UI indicators (yellow highlight, context banner)
7. ✅ Word validation works for both English and Finnish
8. ✅ Invalid words deduct LP (-2 LP)
9. ✅ Valid moves award LP (+10 LP per step)
10. ✅ Completing a ladder awards bonus LP (+30 LP + 10 LP if under optimal)
11. ✅ Push notifications sent when partner makes a move or yields
12. ✅ Accessible from Activities tab
13. ✅ Completion screen shows celebratory animation + quote

---

## 🗂️ Task Breakdown

### **Task 1: Data Models**

#### 1.1 Create WordPair Model (`app/lib/models/word_pair.dart`)

```dart
import 'package:hive/hive.dart';

part 'word_pair.g.dart';

@HiveType(typeId: 6) // Next available after QuizSession
class WordPair extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String startWord;

  @HiveField(2)
  late String endWord;

  @HiveField(3)
  late String language; // 'en' | 'fi'

  @HiveField(4, defaultValue: 'easy')
  late String difficulty; // 'easy' | 'medium' | 'hard'

  @HiveField(5)
  int? optimalSteps; // Target number of steps for bonus

  WordPair({
    required this.id,
    required this.startWord,
    required this.endWord,
    required this.language,
    this.difficulty = 'easy',
    this.optimalSteps,
  });
}
```

---

#### 1.2 Create LadderSession Model (`app/lib/models/ladder_session.dart`)

```dart
import 'package:hive/hive.dart';

part 'ladder_session.g.dart';

@HiveType(typeId: 7)
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
  int yieldCount; // How many times this ladder has been yielded

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
```

---

#### 1.3 Update StorageService (`app/lib/services/storage_service.dart`)

Add methods to manage ladder sessions:

```dart
// In StorageService class

Box<LadderSession> get ladderSessionsBox => Hive.box<LadderSession>('ladder_sessions');

// Get active ladder sessions (max 3)
List<LadderSession> getActiveLadders() {
  return ladderSessionsBox.values
      .where((session) => session.status == 'active')
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

// Save ladder session
Future<void> saveLadderSession(LadderSession session) async {
  await ladderSessionsBox.put(session.id, session);
}

// Update ladder session
Future<void> updateLadderSession(LadderSession session) async {
  await session.save();
}

// Get ladder by ID
LadderSession? getLadderSession(String id) {
  return ladderSessionsBox.get(id);
}

// Count active ladders
int getActiveLadderCount() {
  return ladderSessionsBox.values
      .where((session) => session.status == 'active')
      .length;
}
```

Don't forget to open the box in `init()`:

```dart
static Future<void> init() async {
  await Hive.initFlutter();

  // Register existing adapters
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(PartnerAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(LovePointTransactionAdapter());
  Hive.registerAdapter(QuizQuestionAdapter());
  Hive.registerAdapter(QuizSessionAdapter());

  // Register new adapters
  Hive.registerAdapter(WordPairAdapter());
  Hive.registerAdapter(LadderSessionAdapter());

  // Open existing boxes
  await Hive.openBox<Reminder>('reminders');
  await Hive.openBox<Partner>('partners');
  await Hive.openBox<User>('users');
  await Hive.openBox<LovePointTransaction>('transactions');
  await Hive.openBox<QuizSession>('quiz_sessions');

  // Open new boxes
  await Hive.openBox<LadderSession>('ladder_sessions');
}
```

---

### **Task 2: Word Validation Service**

#### 2.1 Create Word Lists

Create two JSON files with curated word lists:

**`app/assets/words/english_words.json`**
```json
{
  "4": ["love", "life", "hope", "home", "time", "make", "care", "true", "hear", "feel"],
  "5": ["trust", "light", "heart", "peace", "smile", "world", "match", "dream", "share"],
  "6": ["future", "honest", "caring", "loving", "warmth", "bright", "gentle"]
}
```

**`app/assets/words/finnish_words.json`**
```json
{
  "4": ["rata", "sana", "kala", "loma", "valo", "palo", "talo", "pora"],
  "5": ["rauta", "kukka", "taika", "unelma", "ranta"],
  "6": ["taivas", "taito", "rakkautta"]
}
```

Update `pubspec.yaml` to include these assets:

```yaml
flutter:
  assets:
    - assets/animations/
    - assets/words/
```

---

#### 2.2 Create WordValidationService (`app/lib/services/word_validation_service.dart`)

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class WordValidationService {
  static Map<String, Set<String>>? _englishWords;
  static Map<String, Set<String>>? _finnishWords;

  /// Initialize word lists (call in main.dart)
  static Future<void> init() async {
    await _loadWordList('en');
    await _loadWordList('fi');
    print('✅ Word lists loaded (EN: ${_englishWords?.values.expand((e) => e).length} words, FI: ${_finnishWords?.values.expand((e) => e).length} words)');
  }

  /// Load word list from JSON
  static Future<void> _loadWordList(String language) async {
    final fileName = language == 'en' ? 'english_words.json' : 'finnish_words.json';
    final jsonString = await rootBundle.loadString('assets/words/$fileName');
    final Map<String, dynamic> data = json.decode(jsonString);

    // Convert to Set for O(1) lookup
    final wordMap = <String, Set<String>>{};
    data.forEach((length, words) {
      wordMap[length] = Set<String>.from(words as List);
    });

    if (language == 'en') {
      _englishWords = wordMap;
    } else {
      _finnishWords = wordMap;
    }
  }

  /// Check if a word is valid in the given language
  static bool isValidWord(String word, String language) {
    final wordLower = word.toLowerCase();
    final wordMap = language == 'en' ? _englishWords : _finnishWords;

    if (wordMap == null) return false;

    final length = wordLower.length.toString();
    return wordMap[length]?.contains(wordLower) ?? false;
  }

  /// Check if two words differ by exactly one letter
  static bool isOneLetterDifferent(String word1, String word2) {
    if (word1.length != word2.length) return false;

    int differences = 0;
    for (int i = 0; i < word1.length; i++) {
      if (word1[i].toLowerCase() != word2[i].toLowerCase()) {
        differences++;
        if (differences > 1) return false;
      }
    }

    return differences == 1;
  }

  /// Validate a move in the ladder
  static Map<String, dynamic> validateMove({
    required String currentWord,
    required String newWord,
    required String language,
    required List<String> wordChain,
  }) {
    // Check if word is valid
    if (!isValidWord(newWord, language)) {
      return {
        'valid': false,
        'reason': 'not_a_word',
        'message': language == 'en'
            ? '"$newWord" is not a valid word'
            : '"$newWord" ei ole kelvollinen sana',
      };
    }

    // Check if exactly one letter different
    if (!isOneLetterDifferent(currentWord, newWord)) {
      return {
        'valid': false,
        'reason': 'wrong_difference',
        'message': language == 'en'
            ? 'You must change exactly one letter'
            : 'Sinun täytyy muuttaa tasan yksi kirjain',
      };
    }

    // Check if word already used
    if (wordChain.map((w) => w.toLowerCase()).contains(newWord.toLowerCase())) {
      return {
        'valid': false,
        'reason': 'already_used',
        'message': language == 'en'
            ? 'You already used "$newWord"'
            : 'Olet jo käyttänyt sanaa "$newWord"',
      };
    }

    return {
      'valid': true,
      'message': language == 'en' ? 'Valid move!' : 'Kelvollinen siirto!',
    };
  }

  /// Get all words for a given length and language
  static List<String> getWordsByLength(int length, String language) {
    final wordMap = language == 'en' ? _englishWords : _finnishWords;
    return wordMap?[length.toString()]?.toList() ?? [];
  }
}
```

---

### **Task 3: Word Pair Bank & Ladder Service**

#### 3.1 Create Word Pair Bank (`app/lib/services/word_pair_bank.dart`)

```dart
class WordPairBank {
  /// Curated English word pairs (start → end)
  static const List<Map<String, dynamic>> englishPairs = [
    {'start': 'LOVE', 'end': 'LIFE', 'optimal': 3},
    {'start': 'HOPE', 'end': 'HOME', 'optimal': 2},
    {'start': 'CARE', 'end': 'CURE', 'optimal': 2},
    {'start': 'TIME', 'end': 'TIDE', 'optimal': 2},
    {'start': 'MAKE', 'end': 'TAKE', 'optimal': 1},
    {'start': 'COLD', 'end': 'WARM', 'optimal': 4},
    {'start': 'DARK', 'end': 'DAWN', 'optimal': 2},
    {'start': 'FEAR', 'end': 'FEEL', 'optimal': 2},
    {'start': 'LOST', 'end': 'LAST', 'optimal': 1},
    {'start': 'TEAR', 'end': 'HEAR', 'optimal': 1},
  ];

  /// Curated Finnish word pairs
  static const List<Map<String, dynamic>> finnishPairs = [
    {'start': 'SANA', 'end': 'TALO', 'optimal': 3},
    {'start': 'KALA', 'end': 'LOMA', 'optimal': 3},
    {'start': 'VALO', 'end': 'PALO', 'optimal': 1},
    {'start': 'RATA', 'end': 'TALO', 'optimal': 2},
  ];

  /// Get a random word pair for the given language
  static Map<String, dynamic> getRandomPair(String language) {
    final pairs = language == 'en' ? englishPairs : finnishPairs;
    pairs.shuffle();
    return pairs.first;
  }

  /// Get multiple random pairs (for daily ladder pool)
  static List<Map<String, dynamic>> getDailyPairs(String language, int count) {
    final pairs = language == 'en' ? englishPairs : finnishPairs;
    final shuffled = List<Map<String, dynamic>>.from(pairs)..shuffle();
    return shuffled.take(count).toList();
  }
}
```

---

#### 3.2 Create LadderService (`app/lib/services/ladder_service.dart`)

```dart
import 'package:uuid/uuid.dart';
import '../models/ladder_session.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/word_pair_bank.dart';
import '../services/word_validation_service.dart';
import '../services/love_point_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LadderService {
  static final StorageService _storage = StorageService();
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Maximum number of active ladders per couple
  static const int maxActiveLadders = 3;

  /// Create a new ladder session
  static Future<LadderSession?> createLadder({String language = 'en'}) async {
    // Check if we've hit the max active ladders
    if (_storage.getActiveLadderCount() >= maxActiveLadders) {
      print('❌ Maximum active ladders reached ($maxActiveLadders)');
      return null;
    }

    final user = _storage.getUser();
    if (user == null) {
      print('❌ No user found');
      return null;
    }

    // Get a random word pair
    final pairData = WordPairBank.getRandomPair(language);

    final session = LadderSession(
      id: const Uuid().v4(),
      wordPairId: const Uuid().v4(),
      startWord: pairData['start'],
      endWord: pairData['end'],
      wordChain: [pairData['start']], // Start with the first word
      status: 'active',
      createdAt: DateTime.now(),
      currentTurn: user.id,
      language: language,
      optimalSteps: pairData['optimal'],
    );

    await _storage.saveLadderSession(session);

    // Notify partner
    await _notifyPartnerNewLadder(session);

    print('✅ Created ladder: ${session.startWord} → ${session.endWord}');
    return session;
  }

  /// Make a move in the ladder
  static Future<Map<String, dynamic>> makeMove({
    required String sessionId,
    required String newWord,
  }) async {
    final session = _storage.getLadderSession(sessionId);
    if (session == null) {
      return {'success': false, 'error': 'Session not found'};
    }

    final user = _storage.getUser();
    if (user == null) {
      return {'success': false, 'error': 'User not found'};
    }

    // Validate the move
    final validation = WordValidationService.validateMove(
      currentWord: session.currentWord,
      newWord: newWord,
      language: session.language,
      wordChain: session.wordChain,
    );

    if (!validation['valid']) {
      // Invalid move - deduct LP
      await LovePointService.awardPoints(
        amount: -2,
        reason: 'invalid_word_ladder_move',
        relatedId: sessionId,
      );

      return {
        'success': false,
        'error': validation['message'],
        'lpDeducted': 2,
      };
    }

    // Valid move - add to chain
    session.wordChain.add(newWord.toUpperCase());

    // Award LP for valid move
    await LovePointService.awardPoints(
      amount: 10,
      reason: 'word_ladder_move',
      relatedId: sessionId,
    );
    session.lpEarned += 10;

    // Check if ladder is completed
    if (newWord.toUpperCase() == session.endWord) {
      session.status = 'completed';
      session.completedAt = DateTime.now();

      // Award completion bonus
      int bonusLP = 30;

      // Check if under optimal steps
      if (session.optimalSteps != null && session.stepCount <= session.optimalSteps!) {
        bonusLP += 10;
      }

      await LovePointService.awardPoints(
        amount: bonusLP,
        reason: 'word_ladder_completed',
        relatedId: sessionId,
      );
      session.lpEarned += bonusLP;

      await session.save();

      print('🎉 Ladder completed! ${session.stepCount} steps, +${session.lpEarned} LP total');

      return {
        'success': true,
        'completed': true,
        'totalSteps': session.stepCount,
        'lpEarned': session.lpEarned,
        'underOptimal': session.optimalSteps != null && session.stepCount <= session.optimalSteps!,
      };
    }

    // Switch turn to partner
    final partner = _storage.getPartner();
    if (partner != null) {
      // In a real implementation, we'd get partner's userId
      // For now, toggle between user.id and a placeholder
      session.currentTurn = session.currentTurn == user.id ? 'partner' : user.id;

      // Notify partner of the move
      await _notifyPartnerMove(session, newWord);
    }

    await session.save();

    return {
      'success': true,
      'completed': false,
      'lpEarned': 10,
    };
  }

  /// Notify partner of a new ladder
  static Future<void> _notifyPartnerNewLadder(LadderSession session) async {
    try {
      final partner = _storage.getPartner();
      if (partner == null) return;

      final callable = _functions.httpsCallable('sendWordLadderNotification');
      await callable.call({
        'token': partner.pushToken,
        'title': 'New Word Ladder! 🪜',
        'body': 'Your partner started a new ladder: ${session.startWord} → ${session.endWord}',
        'data': {
          'type': 'ladder_new',
          'sessionId': session.id,
        },
      });
    } catch (e) {
      print('❌ Error notifying partner: $e');
    }
  }

  /// Notify partner of a move
  static Future<void> _notifyPartnerMove(LadderSession session, String newWord) async {
    try {
      final partner = _storage.getPartner();
      if (partner == null) return;

      final callable = _functions.httpsCallable('sendWordLadderNotification');
      await callable.call({
        'token': partner.pushToken,
        'title': 'Your partner made a move! 💕',
        'body': '${session.currentWord} → $newWord. Can you reach ${session.endWord}?',
        'data': {
          'type': 'ladder_move',
          'sessionId': session.id,
        },
      });
    } catch (e) {
      print('❌ Error notifying partner: $e');
    }
  }

  /// Get completion quote
  static String getCompletionQuote() {
    const quotes = [
      'You reached the destination together! ❤️',
      'Words connected, hearts aligned 💕',
      'Every step together makes you stronger 🌟',
      'Love finds a way, one letter at a time 💫',
      'Together, you can transform anything ✨',
    ];
    quotes.shuffle();
    return quotes.first;
  }
}
```

---

### **Task 4: UI Screens**

#### 4.1 Word Ladder Hub Screen (`app/lib/screens/word_ladder_hub_screen.dart`)

Shows all active ladders (up to 3) with progress rings.

```dart
import 'package:flutter/material.dart';
import '../models/ladder_session.dart';
import '../services/storage_service.dart';
import '../services/ladder_service.dart';
import '../theme/app_theme.dart';
import './word_ladder_game_screen.dart';

class WordLadderHubScreen extends StatefulWidget {
  const WordLadderHubScreen({super.key});

  @override
  State<WordLadderHubScreen> createState() => _WordLadderHubScreenState();
}

class _WordLadderHubScreenState extends State<WordLadderHubScreen> {
  List<LadderSession> _activeLadders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveLadders();
  }

  void _loadActiveLadders() {
    setState(() {
      _activeLadders = StorageService().getActiveLadders();
      _loading = false;
    });
  }

  Future<void> _createNewLadder() async {
    final session = await LadderService.createLadder(language: 'en');
    if (session != null) {
      _loadActiveLadders();

      // Navigate to the new ladder
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordLadderGameScreen(sessionId: session.id),
        ),
      ).then((_) => _loadActiveLadders());
    } else {
      // Show error - max ladders reached
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 active ladders. Complete one to start a new one!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _activeLadders.isEmpty
                      ? _buildEmptyState()
                      : _buildLadderList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeLadders.length < LadderService.maxActiveLadders
          ? FloatingActionButton.extended(
              onPressed: _createNewLadder,
              backgroundColor: AppTheme.primaryBlack,
              label: const Text('New Ladder', style: TextStyle(color: Colors.white)),
              icon: const Text('🪜', style: TextStyle(fontSize: 20)),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🪜 Word Ladder',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transform words together, one letter at a time',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪜', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'No active ladders',
            style: AppTheme.headlineFont.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new ladder to play with your partner!',
            style: AppTheme.bodyFont.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLadderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activeLadders.length,
      itemBuilder: (context, index) {
        return _buildLadderCard(_activeLadders[index]);
      },
    );
  }

  Widget _buildLadderCard(LadderSession session) {
    final progress = session.wordChain.length / (session.optimalSteps ?? 5);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WordLadderGameScreen(sessionId: session.id),
          ),
        ).then((_) => _loadActiveLadders());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Progress ring
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.borderLight,
                    color: AppTheme.primaryBlack,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.startWord} → ${session.endWord}',
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.stepCount} steps • ${session.lpEarned} LP earned',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current: ${session.currentWord}',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 4.2 Word Ladder Game Screen (`app/lib/screens/word_ladder_game_screen.dart`)

The main gameplay screen where players make moves.

```dart
import 'package:flutter/material.dart';
import '../models/ladder_session.dart';
import '../services/storage_service.dart';
import '../services/ladder_service.dart';
import '../theme/app_theme.dart';
import './word_ladder_completion_screen.dart';

class WordLadderGameScreen extends StatefulWidget {
  final String sessionId;

  const WordLadderGameScreen({super.key, required this.sessionId});

  @override
  State<WordLadderGameScreen> createState() => _WordLadderGameScreenState();
}

class _WordLadderGameScreenState extends State<WordLadderGameScreen> {
  final TextEditingController _wordController = TextEditingController();
  LadderSession? _session;
  String? _errorMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _loadSession() {
    setState(() {
      _session = StorageService().getLadderSession(widget.sessionId);
    });
  }

  Future<void> _submitWord() async {
    if (_wordController.text.isEmpty) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await LadderService.makeMove(
      sessionId: widget.sessionId,
      newWord: _wordController.text.trim(),
    );

    if (result['success']) {
      _wordController.clear();
      _loadSession();

      if (result['completed'] == true) {
        // Navigate to completion screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WordLadderCompletionScreen(
              sessionId: widget.sessionId,
              totalSteps: result['totalSteps'],
              lpEarned: result['lpEarned'],
              underOptimal: result['underOptimal'] ?? false,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result['error'];
      });
    }

    setState(() {
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return Scaffold(
        body: Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryWhite,
        elevation: 0,
        title: Text(
          '${_session!.startWord} → ${_session!.endWord}',
          style: AppTheme.headlineFont.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildWordChain(),
                    const SizedBox(height: 32),
                    _buildInputSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _session!.wordChain.length / (_session!.optimalSteps ?? 5);

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.primaryWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_session!.stepCount} steps',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '+${_session!.lpEarned} LP',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.borderLight,
            color: AppTheme.primaryBlack,
          ),
        ],
      ),
    );
  }

  Widget _buildWordChain() {
    return Column(
      children: _session!.wordChain.asMap().entries.map((entry) {
        final index = entry.key;
        final word = entry.value;
        final isLast = index == _session!.wordChain.length - 1;
        final isTarget = word == _session!.endWord;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isTarget
                    ? Colors.green.shade50
                    : isLast
                        ? AppTheme.primaryBlack
                        : AppTheme.primaryWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTarget
                      ? Colors.green
                      : isLast
                          ? AppTheme.primaryBlack
                          : AppTheme.borderLight,
                  width: 2,
                ),
              ),
              child: Text(
                word,
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isLast && !isTarget ? Colors.white : AppTheme.primaryBlack,
                  letterSpacing: 4,
                ),
              ),
            ),
            if (!isLast || !isTarget)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.arrow_downward, color: AppTheme.textSecondary),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        TextField(
          controller: _wordController,
          textCapitalization: TextCapitalization.characters,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Enter next word',
            hintStyle: AppTheme.bodyFont.copyWith(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
            filled: true,
            fillColor: AppTheme.primaryWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlack, width: 2),
            ),
          ),
          onSubmitted: (_) => _submitWord(),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _errorMessage!,
              style: AppTheme.bodyFont.copyWith(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitWord,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlack,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Change exactly one letter from ${_session!.currentWord}',
          style: AppTheme.bodyFont.copyWith(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }
}
```

---

#### 4.3 Completion Screen (`app/lib/screens/word_ladder_completion_screen.dart`)

Celebratory screen when ladder is completed.

```dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/ladder_service.dart';
import '../theme/app_theme.dart';

class WordLadderCompletionScreen extends StatelessWidget {
  final String sessionId;
  final int totalSteps;
  final int lpEarned;
  final bool underOptimal;

  const WordLadderCompletionScreen({
    super.key,
    required this.sessionId,
    required this.totalSteps,
    required this.lpEarned,
    required this.underOptimal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Confetti animation
                Lottie.asset(
                  'assets/animations/poke_mutual.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 32),
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ladder Complete!',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  LadderService.getCompletionQuote(),
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Steps', totalSteps.toString()),
                          _buildStat('Love Points', '+$lpEarned'),
                        ],
                      ),
                      if (underOptimal) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                'Under optimal steps!',
                                style: AppTheme.bodyFont.copyWith(
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlack,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back to Ladders',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
```

---

### **Task 5: Cloud Function for Notifications**

Add to `functions/index.js`:

```javascript
exports.sendWordLadderNotification = functions.https.onCall(async (request) => {
  const { token, title, body, data } = request.data;

  if (!token || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  const message = {
    notification: { title, body },
    data: data || {},
    token: token,
  };

  try {
    await admin.messaging().send(message);
    console.log(`✅ Word Ladder notification sent: ${title}`);
    return { success: true };
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});
```

---

### **Task 6: Integration with Activities Screen**

Update `app/lib/screens/activities_screen.dart` to add Word Ladder card:

```dart
// Add to the activities grid
_ActivityCard(
  emoji: '🪜',
  title: 'Word Ladder',
  description: 'Transform words together',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WordLadderHubScreen(),
      ),
    );
  },
),
```

---

### **Task 7: Initialization**

Update `app/lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Hive Storage
  await StorageService.init();

  // Notification Service
  await NotificationService.initialize();

  // Load quiz question bank
  await QuizQuestionBank.initializeQuestionBank();

  // Load word lists for Word Ladder
  await WordValidationService.init();

  // Mock data
  await MockDataService.injectMockDataIfNeeded();

  runApp(const TogetherRemindApp());
}
```

---

### **Task 8: Generate Hive Adapters**

After creating the models, run:

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📦 Deliverables

**New Files:**
- `app/lib/models/word_pair.dart`
- `app/lib/models/ladder_session.dart`
- `app/lib/services/word_validation_service.dart`
- `app/lib/services/word_pair_bank.dart`
- `app/lib/services/ladder_service.dart`
- `app/lib/screens/word_ladder_hub_screen.dart`
- `app/lib/screens/word_ladder_game_screen.dart`
- `app/lib/screens/word_ladder_completion_screen.dart`
- `app/assets/words/english_words.json`
- `app/assets/words/finnish_words.json`

**Modified Files:**
- `app/lib/services/storage_service.dart` (add ladder box management)
- `app/lib/screens/activities_screen.dart` (add Word Ladder card)
- `app/lib/main.dart` (initialize word lists)
- `functions/index.js` (add sendWordLadderNotification)
- `pubspec.yaml` (add word assets)

**Cloud Functions:**
- `sendWordLadderNotification` - Send notifications for moves and new ladders

---

## 🧪 Testing Checklist

- [ ] Create a new ladder from Activities screen
- [ ] Make valid moves and verify LP awards (+10 per move)
- [ ] Try invalid moves and verify LP deduction (-2)
- [ ] Complete a ladder and verify bonus LP (+30)
- [ ] Complete under optimal steps and verify bonus (+10)
- [ ] Verify up to 3 active ladders can exist
- [ ] Test that 4th ladder creation is blocked
- [ ] Verify partner receives notifications
- [ ] Test Finnish word validation
- [ ] Verify word chain displays correctly
- [ ] Test completion screen with confetti animation

---

## 🎯 Success Metrics

After Word Ladder implementation:

| Metric | Target |
|--------|--------|
| Ladders completed per couple per week | ≥ 2 |
| Average steps per ladder | ≤ 5 |
| Invalid move rate | < 5% |
| User engagement with parallel ladders | ≥ 60% |

---

## 🚀 Future Enhancements (Post-MVP)

- **Custom word mode**: Let one partner set start/end words
- **Themed packs**: "Romantic Words", "Adventure Words", etc.
- **Hint system**: Show one possible valid word (costs LP)
- **Daily challenge**: Special ladder with 3x LP multiplier
- **Leaderboard integration**: Show fastest completions globally
- **More languages**: Swedish, German, Spanish support
- **Auto-generate pairs**: Use Levenshtein distance algorithm

---

**Ready to build cooperative word magic! 🪜💕**
