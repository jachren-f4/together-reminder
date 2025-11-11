# Phase 2: Couple Quiz Activity - Detailed Implementation Plan

**Goal:** Build the first new gamification activity with highest engagement potential
**Timeline:** Week 3-4
**Journeys Covered:** #1 (Daily Check-in: Home → Quiz → Results → Profile)

---

## 📋 Overview

The Couple Quiz is a cooperative game where both partners answer the same 5 questions privately. Answers are locked until both submit, then compared for accuracy. Higher match percentage = more LP earned.

**Why Quiz First?**
- Highest engagement potential (personal, fun, easy to understand)
- Proves the "new activity" pattern for future features
- Requires minimal external dependencies (no health data, no complex APIs)
- Can be completed quickly (5-10 minutes)

---

## 🎯 Success Criteria

Phase 2 is complete when:

1. ✅ Quiz can be initiated by either partner
2. ✅ Both partners answer 5 random questions independently
3. ✅ Answers are locked until both submit (3-hour timeout)
4. ✅ Results show match percentage, comparison view, and LP earned
5. ✅ LP awards: 5 LP (50% match), 10 LP (75% match), 20 LP (100% match)
6. ✅ "Perfect Sync" badge awarded for 100% match
7. ✅ Push notification sent when partner completes quiz
8. ✅ Quiz accessible from Activities screen or Home screen card
9. ✅ One active quiz session max at a time
10. ✅ Quiz history visible in Profile screen

---

## 🗂️ Task Breakdown

### **Task 1: Data Models**

#### 1.1 Create QuizQuestion Model (`app/lib/models/quiz_question.dart`)

```dart
import 'package:hive/hive.dart';

part 'quiz_question.g.dart';

@HiveType(typeId: 4)
class QuizQuestion extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String question;

  @HiveField(2)
  late List<String> options; // 4 options

  @HiveField(3)
  late int correctAnswerIndex; // For validation (not shown to user)

  @HiveField(4)
  late String category; // 'favorites', 'memories', 'preferences', 'future'

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
  });
}
```

**Why these fields:**
- `id`: Unique identifier for each question
- `question`: The question text
- `options`: 4 possible answers
- `correctAnswerIndex`: There's no "correct" answer for couple quizzes - this is actually the user's previous answer for consistency
- `category`: For filtering and variety

---

#### 1.2 Create QuizSession Model (`app/lib/models/quiz_session.dart`)

```dart
import 'package:hive/hive.dart';

part 'quiz_session.g.dart';

@HiveType(typeId: 5)
class QuizSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late List<String> questionIds; // 5 questions

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  late DateTime expiresAt; // 3 hours from creation

  @HiveField(4)
  late String status; // 'waiting_for_answers', 'completed', 'expired'

  @HiveField(5)
  Map<String, List<int>>? answers; // userId -> [answer indices]

  @HiveField(6)
  int? matchPercentage; // Calculated after both submit

  @HiveField(7)
  int? lpEarned;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  late String initiatedBy; // userId who started the quiz

  QuizSession({
    required this.id,
    required this.questionIds,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.initiatedBy,
    this.answers,
    this.matchPercentage,
    this.lpEarned,
    this.completedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == 'completed';
  bool get hasUserAnswered(String userId) => answers?.containsKey(userId) ?? false;
}
```

**Why these fields:**
- `questionIds`: References to questions in the bank
- `expiresAt`: 3-hour window for both to complete
- `answers`: Map of userId to their answer indices (private until both done)
- `matchPercentage`: Calculated comparison result
- `lpEarned`: Reward amount (5/10/20 LP)

---

#### 1.3 Create Badge Model (`app/lib/models/badge.dart`)

```dart
import 'package:hive/hive.dart';

part 'badge.g.dart';

@HiveType(typeId: 6)
class Badge extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name; // 'Perfect Sync', 'Active Duo', etc.

  @HiveField(2)
  late String emoji;

  @HiveField(3)
  late String description;

  @HiveField(4)
  late DateTime earnedAt;

  @HiveField(5)
  late String category; // 'quiz', 'health', 'poke', 'challenge'

  Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.earnedAt,
    required this.category,
  });
}
```

---

#### 1.4 Update StorageService

Add to `app/lib/services/storage_service.dart`:

```dart
static const String _quizQuestionsBox = 'quiz_questions';
static const String _quizSessionsBox = 'quiz_sessions';
static const String _badgesBox = 'badges';

// In init()
Hive.registerAdapter(QuizQuestionAdapter());
Hive.registerAdapter(QuizSessionAdapter());
Hive.registerAdapter(BadgeAdapter());

await Hive.openBox<QuizQuestion>(_quizQuestionsBox);
await Hive.openBox<QuizSession>(_quizSessionsBox);
await Hive.openBox<Badge>(_badgesBox);

// Quiz operations
Box<QuizQuestion> get quizQuestionsBox => Hive.box<QuizQuestion>(_quizQuestionsBox);
Box<QuizSession> get quizSessionsBox => Hive.box<QuizSession>(_quizSessionsBox);
Box<Badge> get badgesBox => Hive.box<Badge>(_badgesBox);

Future<void> saveQuizQuestion(QuizQuestion question) async {
  await quizQuestionsBox.put(question.id, question);
}

List<QuizQuestion> getAllQuizQuestions() {
  return quizQuestionsBox.values.toList();
}

Future<void> saveQuizSession(QuizSession session) async {
  await quizSessionsBox.put(session.id, session);
}

QuizSession? getActiveQuizSession() {
  return quizSessionsBox.values
      .where((s) => s.status == 'waiting_for_answers' && !s.isExpired)
      .firstOrNull;
}

List<QuizSession> getCompletedQuizSessions() {
  return quizSessionsBox.values
      .where((s) => s.status == 'completed')
      .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
}

Future<void> saveBadge(Badge badge) async {
  await badgesBox.put(badge.id, badge);
}

List<Badge> getAllBadges() {
  return badgesBox.values.toList()
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
}

bool hasBadge(String badgeName) {
  return badgesBox.values.any((b) => b.name == badgeName);
}
```

---

#### 1.5 Regenerate Hive Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### **Task 2: Quiz Question Bank**

#### 2.1 Create Question Bank JSON (`assets/data/quiz_questions.json`)

```json
[
  {
    "id": "q1",
    "question": "What's my favorite food?",
    "options": ["Pizza", "Sushi", "Pasta", "Tacos"],
    "category": "favorites"
  },
  {
    "id": "q2",
    "question": "What time do I usually wake up?",
    "options": ["Before 7am", "7-8am", "8-9am", "After 9am"],
    "category": "preferences"
  },
  {
    "id": "q3",
    "question": "What's my dream vacation spot?",
    "options": ["Beach resort", "Mountain cabin", "European city", "Safari adventure"],
    "category": "future"
  },
  {
    "id": "q4",
    "question": "What was our first date activity?",
    "options": ["Dinner", "Movie", "Coffee", "Walk in park"],
    "category": "memories"
  },
  {
    "id": "q5",
    "question": "What's my favorite way to spend a weekend?",
    "options": ["Outdoor activities", "Relaxing at home", "Social gatherings", "Exploring new places"],
    "category": "preferences"
  }
  // ... 45 more questions across 4 categories
]
```

**Categories (50 total questions):**
- **Favorites** (15 questions): Food, color, movie genre, music, season, etc.
- **Memories** (10 questions): First date, first trip, memorable moments
- **Preferences** (15 questions): Morning/night person, hobbies, weekend activities
- **Future** (10 questions): Travel plans, goals, dreams

---

#### 2.2 Create QuizQuestionBank Service (`app/lib/services/quiz_question_bank.dart`)

```dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class QuizQuestionBank {
  static final StorageService _storage = StorageService();
  static const _uuid = Uuid();

  /// Load questions from JSON and save to Hive (idempotent)
  static Future<void> initializeQuestionBank() async {
    // Only load if not already initialized
    if (_storage.getAllQuizQuestions().isNotEmpty) {
      print('✅ Quiz questions already loaded');
      return;
    }

    print('📚 Loading quiz questions from JSON...');

    final jsonString = await rootBundle.loadString('assets/data/quiz_questions.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    for (var item in jsonList) {
      final question = QuizQuestion(
        id: item['id'],
        question: item['question'],
        options: List<String>.from(item['options']),
        correctAnswerIndex: 0, // Not used for couple quizzes
        category: item['category'],
      );

      await _storage.saveQuizQuestion(question);
    }

    print('✅ Loaded ${jsonList.length} quiz questions');
  }

  /// Get 5 random questions (1-2 from each category)
  static List<QuizQuestion> getRandomQuestions() {
    final allQuestions = _storage.getAllQuizQuestions();

    // Group by category
    final favorites = allQuestions.where((q) => q.category == 'favorites').toList();
    final memories = allQuestions.where((q) => q.category == 'memories').toList();
    final preferences = allQuestions.where((q) => q.category == 'preferences').toList();
    final future = allQuestions.where((q) => q.category == 'future').toList();

    final random = Random();
    final selected = <QuizQuestion>[];

    // Pick 2 favorites, 1 memory, 1 preference, 1 future
    selected.addAll(_pickRandom(favorites, 2, random));
    selected.add(_pickRandom(memories, 1, random).first);
    selected.add(_pickRandom(preferences, 1, random).first);
    selected.add(_pickRandom(future, 1, random).first);

    // Shuffle order
    selected.shuffle(random);

    return selected;
  }

  static List<QuizQuestion> _pickRandom(List<QuizQuestion> list, int count, Random random) {
    final shuffled = List<QuizQuestion>.from(list)..shuffle(random);
    return shuffled.take(count).toList();
  }
}
```

---

### **Task 3: Quiz Service Layer**

#### 3.1 Create QuizService (`app/lib/services/quiz_service.dart`)

```dart
import 'package:cloud_functions/cloud_functions.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/badge.dart';
import 'storage_service.dart';
import 'quiz_question_bank.dart';
import 'love_point_service.dart';
import 'package:uuid/uuid.dart';

class QuizService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final StorageService _storage = StorageService();
  static const _uuid = Uuid();

  /// Start a new quiz session (initiated by current user)
  static Future<QuizSession?> startQuizSession() async {
    try {
      // Check for active session
      final activeSession = _storage.getActiveQuizSession();
      if (activeSession != null) {
        print('⚠️ Active quiz session already exists');
        return activeSession;
      }

      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        print('❌ No user or partner found');
        return null;
      }

      // Get 5 random questions
      final questions = QuizQuestionBank.getRandomQuestions();

      // Create session
      final session = QuizSession(
        id: _uuid.v4(),
        questionIds: questions.map((q) => q.id).toList(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
        status: 'waiting_for_answers',
        initiatedBy: user.id,
        answers: {},
      );

      await _storage.saveQuizSession(session);

      // Notify partner via Cloud Function
      await _notifyPartnerQuizStarted(partner.pushToken, user.name ?? 'Your partner');

      print('✅ Quiz session created: ${session.id}');
      return session;
    } catch (e) {
      print('❌ Error starting quiz: $e');
      return null;
    }
  }

  /// Submit answers for current user
  static Future<bool> submitAnswers(String sessionId, List<int> answers) async {
    try {
      final session = _storage.quizSessionsBox.get(sessionId);
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (session == null || user == null || partner == null) {
        print('❌ Session or user not found');
        return false;
      }

      if (session.isExpired) {
        session.status = 'expired';
        await session.save();
        print('❌ Quiz session expired');
        return false;
      }

      // Save user's answers
      session.answers ??= {};
      session.answers![user.id] = answers;
      await session.save();

      print('✅ Answers submitted for user ${user.id}');

      // Check if both have answered
      if (session.answers!.length == 2) {
        await _calculateResults(session);
      } else {
        // Notify partner that you've completed
        await _notifyPartnerAnswersSubmitted(partner.pushToken, user.name ?? 'Your partner');
      }

      return true;
    } catch (e) {
      print('❌ Error submitting answers: $e');
      return false;
    }
  }

  /// Calculate match percentage and award LP
  static Future<void> _calculateResults(QuizSession session) async {
    try {
      final answersList = session.answers!.values.toList();
      final user1Answers = answersList[0];
      final user2Answers = answersList[1];

      // Calculate match percentage
      int matches = 0;
      for (int i = 0; i < user1Answers.length; i++) {
        if (user1Answers[i] == user2Answers[i]) {
          matches++;
        }
      }

      final percentage = (matches / user1Answers.length * 100).round();
      session.matchPercentage = percentage;

      // Award LP based on percentage
      int lpToAward;
      if (percentage == 100) {
        lpToAward = 20;
        await _awardPerfectSyncBadge();
      } else if (percentage >= 75) {
        lpToAward = 10;
      } else if (percentage >= 50) {
        lpToAward = 5;
      } else {
        lpToAward = 0;
      }

      session.lpEarned = lpToAward;
      session.status = 'completed';
      session.completedAt = DateTime.now();
      await session.save();

      // Award LP to user
      if (lpToAward > 0) {
        await LovePointService.awardPoints(
          amount: lpToAward,
          reason: 'quiz_completed',
          relatedId: session.id,
        );
      }

      print('✅ Quiz completed: $percentage% match, $lpToAward LP earned');

      // Notify both users
      final user = _storage.getUser();
      final partner = _storage.getPartner();
      if (user != null && partner != null) {
        await _notifyQuizCompleted(
          partner.pushToken,
          percentage,
          lpToAward,
        );
      }
    } catch (e) {
      print('❌ Error calculating results: $e');
    }
  }

  /// Award "Perfect Sync" badge for 100% match
  static Future<void> _awardPerfectSyncBadge() async {
    if (_storage.hasBadge('Perfect Sync')) {
      return; // Already has badge
    }

    final badge = Badge(
      id: _uuid.v4(),
      name: 'Perfect Sync',
      emoji: '🎯',
      description: 'Got 100% match on a couple quiz!',
      earnedAt: DateTime.now(),
      category: 'quiz',
    );

    await _storage.saveBadge(badge);
    print('🏅 Awarded badge: Perfect Sync');
  }

  /// Get questions for a session
  static List<QuizQuestion> getQuestionsForSession(QuizSession session) {
    return session.questionIds
        .map((id) => _storage.quizQuestionsBox.get(id))
        .whereType<QuizQuestion>()
        .toList();
  }

  // Cloud Function notifications
  static Future<void> _notifyPartnerQuizStarted(String partnerToken, String userName) async {
    try {
      final callable = _functions.httpsCallable('notifyQuizStarted');
      await callable.call({
        'partnerToken': partnerToken,
        'userName': userName,
      });
    } catch (e) {
      print('❌ Error notifying partner: $e');
    }
  }

  static Future<void> _notifyPartnerAnswersSubmitted(String partnerToken, String userName) async {
    try {
      final callable = _functions.httpsCallable('notifyQuizAnswersSubmitted');
      await callable.call({
        'partnerToken': partnerToken,
        'userName': userName,
      });
    } catch (e) {
      print('❌ Error notifying partner: $e');
    }
  }

  static Future<void> _notifyQuizCompleted(String partnerToken, int percentage, int lpEarned) async {
    try {
      final callable = _functions.httpsCallable('notifyQuizCompleted');
      await callable.call({
        'partnerToken': partnerToken,
        'percentage': percentage,
        'lpEarned': lpEarned,
      });
    } catch (e) {
      print('❌ Error notifying quiz completion: $e');
    }
  }
}
```

---

### **Task 4: UI Screens**

#### 4.1 Quiz Intro Screen (`app/lib/screens/quiz_intro_screen.dart`)

**Layout:**
- Large emoji/icon (🎯)
- Title: "How Well Do You Know Me?"
- Rules:
  - Answer 5 questions about each other
  - Both must complete within 3 hours
  - Higher match = more Love Points
- LP rewards display: 50% = 5 LP, 75% = 10 LP, 100% = 20 LP
- "Start Quiz" button

**Logic:**
- Check for active session on load
- If exists, redirect to QuestionScreen or WaitingScreen
- On start, call `QuizService.startQuizSession()`

---

#### 4.2 Question Screen (`app/lib/screens/quiz_question_screen.dart`)

**Layout:**
- Progress indicator (Question 1 of 5)
- Timer countdown (3 hours remaining)
- Question text (large, centered)
- 4 answer buttons (grid 2x2)
- "Next" button (only active after selection)
- Can't go back to previous questions

**Logic:**
- Load questions from session
- Track selected answers in state
- On final question, show "Submit Answers" button
- Call `QuizService.submitAnswers()` on submit
- Navigate to WaitingScreen or ResultsScreen

---

#### 4.3 Waiting Screen (`app/lib/screens/quiz_waiting_screen.dart`)

**Layout:**
- Animated waiting indicator
- Message: "Waiting for [Partner Name] to complete..."
- Timer showing time remaining
- "Cancel" button (marks session as cancelled)

**Logic:**
- Poll for session updates every 5 seconds
- Navigate to ResultsScreen when both complete
- Show expired message if timeout

---

#### 4.4 Results Screen (`app/lib/screens/quiz_results_screen.dart`)

**Layout:**
- Large match percentage (85% with circular progress)
- LP earned badge (+10 LP with animation)
- Question-by-question comparison:
  - Question text
  - Your answer (highlighted green if match, red if not)
  - Partner's answer
  - Match/No Match indicator
- "View Profile" button
- "Start New Quiz" button (if no active session)

**Logic:**
- Load completed session
- Load questions and answers
- Display comparison
- Animate LP counter

---

### **Task 5: Activities Screen Integration**

#### 5.1 Create ActivitiesScreen (`app/lib/screens/activities_screen.dart`)

**Layout:**
- Title: "Activities"
- Activity cards:
  - **Couple Quiz**
    - Icon: 🎯
    - Title: "How Well Do You Know Me?"
    - Status: "Ready" / "In Progress" / "Completed"
    - Button: "Start Quiz" / "Continue" / "View Results"
  - (Future activities grayed out with "Coming Soon")

**Logic:**
- Check for active quiz session on load
- Update card state based on session status
- Navigate to appropriate quiz screen on tap

---

#### 5.2 Add Activities to Bottom Navigation (Optional)

Or add a prominent "Activities" card to the Home screen (SendReminderScreen).

---

### **Task 6: Cloud Functions**

#### 6.1 Add Quiz Notification Functions (`functions/index.js`)

```javascript
// Notify partner that quiz was started
exports.notifyQuizStarted = functions.https.onCall(async (request) => {
  const { partnerToken, userName } = request.data;

  const message = {
    token: partnerToken,
    notification: {
      title: `${userName} started a Couple Quiz! 🎯`,
      body: 'Tap to answer 5 questions and see how well you match!',
    },
    data: {
      type: 'quiz_started',
    },
  };

  return await admin.messaging().send(message);
});

// Notify partner that you submitted answers
exports.notifyQuizAnswersSubmitted = functions.https.onCall(async (request) => {
  const { partnerToken, userName } = request.data;

  const message = {
    token: partnerToken,
    notification: {
      title: `${userName} completed the quiz! ⏰`,
      body: 'Submit your answers to see the results!',
    },
    data: {
      type: 'quiz_answers_submitted',
    },
  };

  return await admin.messaging().send(message);
});

// Notify both when quiz is completed
exports.notifyQuizCompleted = functions.https.onCall(async (request) => {
  const { partnerToken, percentage, lpEarned } = request.data;

  const message = {
    token: partnerToken,
    notification: {
      title: `Quiz Complete! ${percentage}% Match 🎉`,
      body: `You earned ${lpEarned} Love Points together!`,
    },
    data: {
      type: 'quiz_completed',
      percentage: percentage.toString(),
      lpEarned: lpEarned.toString(),
    },
  };

  return await admin.messaging().send(message);
});
```

---

### **Task 7: Testing & Polish**

#### 7.1 Update main.dart Initialization

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

  // Mock data
  await MockDataService.injectMockDataIfNeeded();

  runApp(const TogetherRemindApp());
}
```

---

#### 7.2 Update MockDataService

Add mock quiz session to `_injectMockData()`:

```dart
// Create a completed quiz session
final completedQuiz = QuizSession(
  id: _uuid.v4(),
  questionIds: ['q1', 'q2', 'q3', 'q4', 'q5'],
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  expiresAt: DateTime.now().subtract(const Duration(days: 2)).add(const Duration(hours: 3)),
  status: 'completed',
  initiatedBy: user.id,
  answers: {
    user.id: [0, 1, 2, 0, 1],
    'partner_id': [0, 1, 3, 0, 1],
  },
  matchPercentage: 80,
  lpEarned: 10,
  completedAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
);

await _storage.saveQuizSession(completedQuiz);
```

---

#### 7.3 Manual Testing Checklist

- [ ] Start quiz from Activities screen
- [ ] Answer 5 questions
- [ ] Verify "waiting for partner" state
- [ ] Simulate partner completing (on another device or mock)
- [ ] Verify results screen shows correct match %
- [ ] Verify LP awarded and transaction created
- [ ] Verify "Perfect Sync" badge for 100% match
- [ ] Verify push notifications sent
- [ ] Test quiz expiration (3-hour timeout)
- [ ] Test cancellation flow
- [ ] Verify only one active quiz at a time
- [ ] Check quiz history in Profile screen

---

## 📦 Deliverables

**New Files:**
- `app/lib/models/quiz_question.dart`
- `app/lib/models/quiz_session.dart`
- `app/lib/models/badge.dart`
- `app/lib/services/quiz_question_bank.dart`
- `app/lib/services/quiz_service.dart`
- `app/lib/screens/quiz_intro_screen.dart`
- `app/lib/screens/quiz_question_screen.dart`
- `app/lib/screens/quiz_waiting_screen.dart`
- `app/lib/screens/quiz_results_screen.dart`
- `app/lib/screens/activities_screen.dart`
- `assets/data/quiz_questions.json`

**Modified Files:**
- `app/lib/services/storage_service.dart` (add quiz boxes)
- `app/lib/screens/home_screen.dart` (optional: add Activities nav item)
- `app/lib/services/mock_data_service.dart` (add quiz mock data)
- `functions/index.js` (add 3 notification functions)
- `app/pubspec.yaml` (add assets path if not already present)

**Generated Files:**
- `app/lib/models/quiz_question.g.dart`
- `app/lib/models/quiz_session.g.dart`
- `app/lib/models/badge.g.dart`

---

## 🎯 LP Earning Summary

After Phase 2, users can earn LP from:

| Activity | LP Earned |
|----------|-----------|
| Send reminder | +8 LP |
| Complete reminder | +10 LP |
| Mutual poke | +5 LP |
| Poke back | +3 LP |
| Quiz 50% match | +5 LP |
| Quiz 75% match | +10 LP |
| Quiz 100% match | +20 LP |

**Total potential:** ~60 LP per day with active engagement

---

## 🚀 Next Steps After Phase 2

Once Phase 2 is complete:

1. Deploy Cloud Functions with new quiz notifications
2. Test on real devices with 2 paired accounts
3. Gather user feedback on quiz difficulty and question quality
4. Plan Phase 3: Leaderboard implementation
5. Consider adding more quiz question categories
6. Design additional activities (Timed Trivia, Crossword, etc.)

---

**Ready to build! 🎉**
