# Affirmation Quiz Integration Plan

**Last Updated:** 2025-11-14 (Modified: Daily Affirmations)
**Status:** Planning Phase - Ready for Implementation

---

## Executive Summary

This document outlines the plan to integrate affirmation-style quizzes (self-assessment with 5-point Likert scales) into TogetherRemind's existing daily quest system. **Users will see at least one affirmation quiz every day starting from day 1**, providing daily self-reflection opportunities. The approach leverages 90% of existing infrastructure by treating affirmations as a **format variant** within the existing quiz quest type, rather than creating a completely separate system.

### Key Benefits

✅ **Reuses existing architecture** - Provider pattern, quest generation, completion tracking, LP awards, Firebase sync
✅ **No new QuestType needed** - Affirmations are `QuestType.quiz` with `formatType: 'affirmation'`
✅ **Minimal code duplication** - QuizQuestProvider handles both classic and affirmation quizzes
✅ **Progression system compatible** - Affirmations fit naturally into track-based progression
✅ **Answer storage compatible** - Both use `List<int>` format

### Critical Implementation Notes

⚠️ **Session Loading Fallback Required** - QuizService must implement Firebase fallback for second device session loading
⚠️ **Version Compatibility** - Add defensive checks for mixed-version deployments (one partner updated, other not)
⚠️ **Answer Validation** - Bounds checking (1-5) required in FivePointScaleWidget

---

## Architecture Analysis

### Current Quest System

The existing daily quest system uses a **provider pattern** that's already designed for extensibility:

```dart
// Each quest type implements this interface
abstract class QuestProvider {
  QuestType get questType;
  Future<String?> generateQuest({...});
  Future<bool> validateCompletion({...});
}

// QuizQuestProvider already supports format types
class TrackConfig {
  final String? categoryFilter;
  final int? difficulty;
  final String formatType;  // ← Already exists! ('classic', 'speed_round')
}
```

**Key Insight:** The system already passes `formatType` to `QuizService.startQuizSession()`. We just need to add `'affirmation'` as a new format option.

### Classic Quiz vs Affirmation Quiz

| Aspect | Classic Quiz | Affirmation Quiz |
|--------|-------------|------------------|
| **QuestType** | `QuestType.quiz` | `QuestType.quiz` (same!) |
| **Format** | `formatType: 'classic'` | `formatType: 'affirmation'` |
| **Answer Type** | Multiple choice (4 options) | 5-point scale (1-5) |
| **Answer Storage** | `[0, 2, 1, 3, 4]` (option indices) | `[3, 4, 2, 5, 1]` (scale values) |
| **Scoring** | Match percentage (compare partners) | Individual score (self-assessment) |
| **UI Widget** | Option buttons | Heart-based scale widget |
| **Question Count** | 6 questions | 6 questions |
| **LP Reward** | 30 LP (both complete) | 30 LP (both complete) |

**Critical Observation:** Answer storage format is already compatible! Both use `List<int>`, so no model changes needed.

### What Already Works

The following components work **unchanged** for affirmation quizzes:

1. **Quest Generation** (`QuestTypeManager.generateDailyQuests()`)
   - Creates 3 daily quests
   - Assigns track/position
   - Syncs to Firebase

2. **Completion Validation** (`QuizQuestProvider.validateCompletion()`)
   - Checks if user answered all questions
   - Works for any quiz format

3. **LP Award System** (`DailyQuestService.completeQuestForUser()`)
   - Awards 30 LP when both partners complete
   - No changes needed

4. **Firebase Synchronization** (`QuestSyncService`)
   - Syncs quest data across devices
   - Handles partner completion detection

5. **Storage** (`QuizSession` model)
   - Stores answers as `Map<String, List<int>>`
   - Compatible with both formats

---

## Implementation Plan

### Phase 1: Data Layer (Models & Question Bank)

#### 1.1 Add `questionType` Field to QuizQuestion Model

**File:** `app/lib/models/quiz_question.dart`

```dart
@HiveType(typeId: 13)
class QuizQuestion extends HiveObject {
  // ... existing fields ...

  @HiveField(8, defaultValue: 'multiple_choice')
  String questionType; // 'multiple_choice' | 'scale'
}
```

**Why:** Differentiates between multiple-choice questions (classic) and Likert scale questions (affirmation).

**Migration Safety:** Uses `defaultValue` to ensure existing questions default to `'multiple_choice'`.

#### 1.2 Add Affirmation Questions to Question Bank

**File:** `app/assets/data/quiz_questions.json`

**Status:** 3 of 6 affirmation quizzes ready to use (from `data/affirmations_transformed.json`)

**Available Affirmations (Ready to Use):**
1. **"Gentle Beginnings"** - Early relationship connection (5 questions, category: `trust`)
2. **"Warm Vibes"** - Positivity and warmth (5 questions, category: `trust`)
3. **"Simple Joys"** - Shared moments and appreciation (5 questions, category: `emotional_support`)

**Source:** `data/affirmations_transformed.json` - Already in correct QuizQuestion format

**Still Needed:**
4. Trust - "Do You Keep Secrets?" (6 questions, category: `trust`)
5. Commitment (6 questions)
6. Intimacy (6 questions)

**Expected Quiz Structure:**

```json
{
  "id": "gentle_beginnings",
  "name": "Gentle Beginnings",
  "category": "trust",
  "difficulty": 1,
  "formatType": "affirmation",
  "questions": [
    {
      "question": "I enjoy learning small new things about my partner every day.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "We find simple ways to have fun together.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    }
    // ... 3 more questions (5 total per quiz)
  ]
}
```

**Total Content:**
- **Available:** 15 questions (3 quizzes × 5 questions each)
- **Still needed:** 18 questions (3 quizzes × 6 questions each)
- **Grand total:** 33 affirmation questions across 6 quizzes

**Question Categories for Affirmations:**
- `trust` - Early connection, relationship basics (Track 0, Position 1)
- `emotional_support` - Shared moments and appreciation (Track 0, Position 3)
- `trust` - Trust and secrecy - "Do You Keep Secrets?" (Track 1, Position 1)
- `emotional_support` - Emotional availability (Track 1, Position 3)
- `commitment` - Dedication and commitment (Track 2, Position 1)
- `intimacy` - Intimacy and connection (Track 2, Position 3)

#### 1.2.1 JSON Transformation Tool (Optional)

**Purpose:** Converts simplified affirmation JSON format to QuizQuestion format

**File:** `tools/transform_affirmations.dart`

**Usage:**
```bash
dart run tools/transform_affirmations.dart
```

**What it does:**
- Reads `data/affirmations.json` (simplified format with `items` array)
- Generates `data/affirmations_transformed.json` (QuizQuestion format)
- Automatically infers categories from tags
- Generates unique IDs from quiz names
- Wraps each affirmation statement in proper QuizQuestion structure
- Sets `questionType: "scale"` and `formatType: "affirmation"`

**Input Format (Simplified):**
```json
{
  "quizzes": [
    {
      "name": "Gentle Beginnings",
      "difficulty_stage": 1,
      "tags": ["light", "playful", "early-connection"],
      "items": [
        "I enjoy learning small new things about my partner every day.",
        "We find simple ways to have fun together."
      ]
    }
  ]
}
```

**Output Format (QuizQuestion):**
```json
{
  "quizzes": [
    {
      "id": "gentle_beginnings",
      "name": "Gentle Beginnings",
      "category": "trust",
      "difficulty": 1,
      "formatType": "affirmation",
      "questions": [
        {
          "question": "I enjoy learning small new things about my partner every day.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    }
  ]
}
```

**When to use:**
- Converting content writer's simplified format to app-ready format
- Batch processing multiple affirmation quizzes
- Maintaining consistency across quiz structures

#### 1.3 Regenerate Hive Adapters

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Phase 2: UI Components

#### 2.1 Create `FivePointScaleWidget`

**File:** `app/lib/widgets/five_point_scale.dart`

```dart
class FivePointScaleWidget extends StatelessWidget {
  final int? selectedValue; // 1-5, null if not selected
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label: "Strongly disagree"
        Text('Strongly disagree', style: ...),

        // 5 heart icons (1-5)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final value = index + 1;
            return GestureDetector(
              onTap: () {
                // Validate bounds (defensive check)
                if (value >= 1 && value <= 5) {
                  onChanged(value);
                }
              },
              child: Icon(
                value <= (selectedValue ?? 0) ? Icons.favorite : Icons.favorite_border,
                size: 48,
                color: value <= (selectedValue ?? 0) ? Colors.red : Colors.grey,
              ),
            );
          }),
        ),

        // Label: "Strongly agree"
        Text('Strongly agree', style: ...),
      ],
    );
  }
}
```

**Design Notes:**
- Matches HTML mockup design (`mockups/affirmation/04-question-1.html`)
- Heart icons fill from left to right as user selects higher values
- Tapping a heart selects that value and all hearts to the left
- **Input validation** ensures only values 1-5 are accepted (defensive programming)

#### 2.2 Update Quiz Question Screen to Detect Format Type

**File:** `app/lib/screens/quiz_screen.dart` (existing file, needs modification)

```dart
// In _QuizScreenState.build()
Widget _buildAnswerOptions() {
  final question = currentQuestion;

  // Detect question type
  if (question.questionType == 'scale') {
    // Render 5-point scale for affirmation questions
    return FivePointScaleWidget(
      selectedValue: _currentAnswer,
      onChanged: (value) => setState(() => _currentAnswer = value),
    );
  } else {
    // Render multiple choice for classic questions (existing code)
    return _buildMultipleChoiceOptions();
  }
}
```

**Why:** Reuses existing quiz screen infrastructure, just swaps out the answer widget based on question type.

#### 2.3 Create Affirmation-Specific Intro Screen

**File:** `app/lib/screens/affirmation_intro_screen.dart`

```dart
class AffirmationIntroScreen extends StatelessWidget {
  final String quizName;
  final String category;
  final String researchContext; // e.g., "2023 study in Personal Relationships..."

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz type badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('QUIZ', style: TextStyle(color: Colors.white)),
              ),

              SizedBox(height: 16),

              // Quiz title
              Text(quizName, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),

              SizedBox(height: 32),

              // Goal section
              _buildSection(
                title: 'Goal',
                content: 'Gain awareness of strength and growth areas in how you connect emotionally as a couple.',
              ),

              // Research section
              _buildSection(
                title: 'Research',
                content: researchContext,
              ),

              // How it works section
              _buildSection(
                title: 'How it works',
                content: _buildHowItWorks(),
              ),

              Spacer(),

              // CTA button
              ElevatedButton(
                onPressed: () => _startQuiz(context),
                child: Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Design Source:** Based on `mockups/affirmation/02-quiz-intro.html`

#### 2.4 Create Affirmation Results Screen

**File:** `app/lib/screens/affirmation_results_screen.dart`

```dart
class AffirmationResultsScreen extends StatelessWidget {
  final QuizSession session;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final userAnswers = session.answers?[userId] ?? [];
    final averageScore = _calculateAverageScore(userAnswers);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Title
            Text('Quiz: ${session.quizName}'),

            // Your results section
            Text('Your results'),
            Text('This represents how satisfied you are with ${session.category} in your relationship at present.'),

            // Circular progress indicator showing individual score
            CircularProgressIndicator(
              value: averageScore / 5.0, // 0.0 to 1.0
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),

            // Score text
            Text('${(averageScore / 5.0 * 100).round()}%'),

            // Partner status
            _buildPartnerStatus(session),

            // Your answers section
            Text('Your answers'),
            ...session.questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final answer = userAnswers[index];

              return ListTile(
                title: Text('${index + 1}. ${question.text}'),
                trailing: Text('${answer}/5'),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _calculateAverageScore(List<int> answers) {
    if (answers.isEmpty) return 0;
    return answers.reduce((a, b) => a + b) / answers.length;
  }
}
```

**Design Source:** Based on `mockups/affirmation/12-results-awaiting.html`

**Key Difference from Classic Quiz:**
- Shows **individual score** (average of 1-5 scale values), not match percentage
- No comparison with partner's answers
- Focus on self-reflection, not alignment

---

### Phase 3: Service Logic

#### 3.1 Extend `QuizQuestProvider._getTrackConfig()` to Support Affirmations

**File:** `app/lib/services/quest_type_manager.dart`

```dart
TrackConfig _getTrackConfig(int track, int position) {
  // Track 0: Relationship Foundation (tier 1, lighter topics)
  // Pattern: Classic, Affirmation, Classic, Affirmation
  if (track == 0) {
    switch (position) {
      case 0:
        return TrackConfig(categoryFilter: 'favorites', difficulty: 1);
      case 1:
        // Affirmation: Relationship satisfaction basics
        return TrackConfig(
          categoryFilter: 'relationship_satisfaction',
          formatType: 'affirmation',
        );
      case 2:
        return TrackConfig(categoryFilter: 'personality', difficulty: 1);
      case 3:
        // Affirmation: Values and expectations
        return TrackConfig(
          categoryFilter: 'shared_values',
          formatType: 'affirmation',
        );
    }
  }

  // Track 1: Communication & Conflict (tier 2-3, deeper categories)
  // Pattern: Classic, Affirmation, Classic, Affirmation
  if (track == 1) {
    switch (position) {
      case 0:
        return TrackConfig(categoryFilter: 'communication', difficulty: 2);
      case 1:
        // Affirmation: Trust and secrecy
        return TrackConfig(
          categoryFilter: 'trust',
          formatType: 'affirmation',
        );
      case 2:
        return TrackConfig(categoryFilter: 'conflict', difficulty: 2);
      case 3:
        // Affirmation: Emotional support
        return TrackConfig(
          categoryFilter: 'emotional_support',
          formatType: 'affirmation',
        );
    }
  }

  // Track 2: Future & Growth (tier 3-4, advanced categories)
  // Pattern: Classic, Affirmation, Classic, Affirmation
  if (track == 2) {
    switch (position) {
      case 0:
        return TrackConfig(categoryFilter: 'future', difficulty: 3);
      case 1:
        // Affirmation: Commitment and dedication
        return TrackConfig(
          categoryFilter: 'commitment',
          formatType: 'affirmation',
        );
      case 2:
        return TrackConfig(categoryFilter: 'growth', difficulty: 3);
      case 3:
        // Affirmation: Intimacy and connection
        return TrackConfig(
          categoryFilter: 'intimacy',
          formatType: 'affirmation',
        );
    }
  }

  // Fallback
  return TrackConfig(categoryFilter: 'favorites', difficulty: 1);
}
```

**What This Does:**
- **Positions 1 and 3** in each track are affirmations (50% of quizzes)
- **Positions 0 and 2** in each track are classic quizzes (50% of quizzes)
- Affirmation topics progress from lighter (relationship satisfaction) to deeper (intimacy)

**Progression Example (First 4 Days):**
- **Day 1**:
  - Quest 1: Classic (favorites)
  - Quest 2: **Affirmation (relationship satisfaction)** ✓
  - Quest 3: Classic (personality)
- **Day 2**:
  - Quest 1: **Affirmation (shared values)** ✓
  - Quest 2: Classic (communication)
  - Quest 3: **Affirmation (trust)** ✓
- **Day 3**:
  - Quest 1: Classic (conflict)
  - Quest 2: **Affirmation (emotional support)** ✓
  - Quest 3: Classic (future)
- **Day 4**:
  - Quest 1: **Affirmation (commitment)** ✓
  - Quest 2: Classic (growth)
  - Quest 3: **Affirmation (intimacy)** ✓

Every day has 1-2 affirmations, starting from day 1.

#### 3.2 Extend `QuizService` to Handle Affirmation Scoring

**File:** `app/lib/services/quiz_service.dart`

```dart
Future<void> submitAnswers({
  required String sessionId,
  required List<int> answers,
}) async {
  final session = _storage.getQuizSession(sessionId);
  if (session == null) throw Exception('Session not found');

  final user = _storage.getUser();
  if (user == null) throw Exception('User not found');

  // Save answers
  session.answers ??= {};
  session.answers![user.id] = answers;

  // Calculate score based on format type
  if (session.formatType == 'affirmation') {
    // Affirmation scoring: Calculate individual score (average of 1-5 scale)
    final averageScore = answers.reduce((a, b) => a + b) / answers.length;
    session.scores ??= {};
    session.scores![user.id] = (averageScore / 5.0 * 100).round(); // Convert to percentage

    // No match percentage calculation for affirmations
  } else {
    // Classic scoring: Calculate match percentage (existing logic)
    _calculateMatchPercentage(session, user.id);
  }

  // Check if both users completed
  final partner = _storage.getPartner();
  if (partner != null && session.answers!.containsKey(partner.pushToken)) {
    session.status = 'completed';
    session.completedAt = DateTime.now();

    // Award LP (via QuizService, not DailyQuestService)
    await LovePointService.awardPointsToBothUsers(
      userId1: user.id,
      userId2: partner.pushToken,
      amount: 30,
      reason: 'quiz_completion',
      relatedId: sessionId,
    );
  } else {
    session.status = 'in_progress';
  }

  await _storage.updateQuizSession(session);
}
```

**Key Changes:**
- Detects `formatType == 'affirmation'`
- Skips match percentage calculation
- Stores individual score as average of scale values (1-5 → 0-100%)
- LP award logic remains unchanged (30 LP when both complete)

#### 3.3 Update Quiz Screen Routing to Detect Format Type

**File:** `app/lib/widgets/quest_card.dart` (or wherever quest tap handlers live)

```dart
void _onQuestTap(BuildContext context, DailyQuest quest) {
  if (quest.type == QuestType.quiz) {
    final session = _storage.getQuizSession(quest.contentId);

    if (session?.formatType == 'affirmation') {
      // Navigate to affirmation intro screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AffirmationIntroScreen(
            quizName: session!.quizName,
            category: session.category,
            researchContext: _getResearchContext(session.category),
          ),
        ),
      );
    } else {
      // Navigate to classic quiz intro screen (existing code)
      Navigator.push(context, MaterialPageRoute(builder: (_) => QuizIntroScreen(...)));
    }
  }
}
```

---

### Phase 4: Integration & Testing

#### 4.1 Test Affirmation Quest Generation

**Verification Steps:**

1. **Clear all data** (Firebase + local storage):
   ```bash
   firebase database:remove /daily_quests
   firebase database:remove /quiz_sessions
   firebase database:remove /quiz_progression
   ~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2
   ```

2. **Launch Alice** (Android emulator):
   ```bash
   cd app
   flutter run -d emulator-5554 &
   ```
   - Wait for "Daily quests generated: 3 quests" in console
   - Verify at least 1 affirmation appears in the 3 quests
   - Verify Track 0, Position 1 creates an affirmation quiz (relationship_satisfaction)

3. **Launch Bob** (Chrome):
   ```bash
   sleep 10
   flutter run -d chrome &
   ```
   - Verify Bob loads the same quests from Firebase

4. **Check Quest Data:**
   - Open debug menu (double-tap greeting text)
   - Verify `formatType: 'affirmation'` appears in Firebase data

#### 4.2 Test Affirmation Quiz Flow (End-to-End)

**Test Scenario:**

1. **Alice taps affirmation quest**
   - Should show `AffirmationIntroScreen` with research context
   - Tap "Get Started"

2. **Alice answers questions**
   - Should see 5-point heart scale (not multiple choice)
   - Answer all 6 questions
   - Submit answers

3. **Verify Alice's results**
   - Should show individual score (e.g., "87%")
   - Should show "Awaiting {partner}'s answers" if Bob hasn't completed
   - Should NOT show match percentage

4. **Bob completes quiz**
   - Same flow as Alice
   - After Bob submits, both should receive 30 LP notification

5. **Verify quest completion**
   - Quest card should show green checkmark
   - Quest status should be "completed"
   - Both users should have +30 LP in balance

#### 4.3 Test Firebase Synchronization

**Test Scenario:**

1. **Alice completes affirmation quiz**
   - Check Firebase console: `/quiz_sessions/{sessionId}`
   - Should see `answers.{aliceId}: [3, 4, 2, 5, 1, 4]`
   - Should see `scores.{aliceId}: 76` (or similar)

2. **Bob loads quiz on different device**
   - Should load same session from Firebase
   - Should NOT see Alice's answers (private until both complete)

3. **Bob completes quiz**
   - Check Firebase console
   - Should see `answers.{bobId}: [4, 5, 3, 4, 5, 4]`
   - Should see `scores.{bobId}: 87`
   - Should see `status: 'completed'`

4. **Alice refreshes results**
   - Should now see both individual scores
   - Should see partner's answers (after both complete)

#### 4.4 Verify LP Award System

**Test Scenario:**

1. **Check LP before quiz:**
   - Alice: 100 LP
   - Bob: 100 LP

2. **Complete affirmation quiz (both users)**

3. **Check LP after quiz:**
   - Alice: 130 LP (+30)
   - Bob: 130 LP (+30)

4. **Verify LP transaction records:**
   - Check Hive storage for `LovePointTransaction` entries
   - Should have 2 transactions (one for each user)
   - Reason: `'quiz_completion'`
   - Related ID: session ID

---

## Open Questions & Decisions

### Decision 1: Affirmation Placement in Progression

**Question:** Where should affirmation quizzes appear in the track progression?

**Recommendation:** **Integrate affirmations from day 1** with a 50% distribution pattern to ensure at least one affirmation appears in each day's 3 quests.

**Rationale:**
- Users benefit from daily self-reflection starting immediately
- Affirmations provide variety alongside classic quizzes
- 50% distribution guarantees 1-2 affirmations per day
- Natural progression from lighter to deeper affirmation topics

**Distribution Pattern:**
Within each track, positions 1 and 3 are affirmations, positions 0 and 2 are classic:
- Track 0 (4 quizzes): 2 affirmations, 2 classic (50%)
- Track 1 (4 quizzes): 2 affirmations, 2 classic (50%)
- Track 2 (4 quizzes): 2 affirmations, 2 classic (50%)
- **Total:** 6 affirmations out of 12 quizzes (50%)

**Daily Experience:**
- Day 1: Classic, Affirmation, Classic (1-2 affirmations ✓)
- Day 2: Affirmation, Classic, Affirmation (1-2 affirmations ✓)
- Day 3: Classic, Affirmation, Classic (1-2 affirmations ✓)
- Pattern continues throughout all tracks

### Decision 2: LP Reward Amount

**Question:** Should affirmation quizzes award the same 30 LP as classic quizzes?

**Recommendation:** **Yes, keep 30 LP.**

**Rationale:**
- Maintains consistency across quest types
- Affirmations require same time/effort as classic quizzes (6 questions)
- Simplifies LP tracking and user expectations

### Decision 3: Progression Integration

**Question:** Should affirmations have a separate progression track, or be mixed with classic quizzes?

**Recommendation:** **Mix with classic quizzes in the same progression system.**

**Rationale:**
- Leverages existing track/position system (no duplication)
- Users experience variety (not all classic quizzes)
- Simpler mental model (one progression, not two)

### Decision 4: Partner Score Visibility

**Question:** Should partners see each other's affirmation scores?

**Recommendation:** **Yes, but only after both complete.**

**Rationale:**
- Maintains parity with classic quizzes (results revealed after both finish)
- Encourages discussion ("I scored higher on trust than you, let's talk about that")
- Respects privacy (no peeking before partner completes)

**Implementation:**
- Results screen shows "Awaiting {partner}'s answers" until both complete
- After both complete, show side-by-side individual scores
- Include partner's answers (not hidden like classic quiz predictions)

---

## Files to Modify

### Models
- `app/lib/models/quiz_question.dart` - Add `questionType` field
- `app/lib/models/quiz_session.dart` - No changes needed (already supports `formatType`)

### Services
- `app/lib/services/quest_type_manager.dart` - Update `_getTrackConfig()` to return affirmation configs
- `app/lib/services/quiz_service.dart` - Add affirmation scoring logic in `submitAnswers()` + **CRITICAL:** Add Firebase session loading fallback in `getSession()`

### Screens
- `app/lib/screens/quiz_screen.dart` - Update `_buildAnswerOptions()` to detect question type
- **NEW:** `app/lib/screens/affirmation_intro_screen.dart` - Affirmation-specific intro
- **NEW:** `app/lib/screens/affirmation_results_screen.dart` - Individual scoring display

### Widgets
- **NEW:** `app/lib/widgets/five_point_scale.dart` - Heart-based rating widget
- `app/lib/widgets/quest_card.dart` - Update `_onQuestTap()` to route to affirmation intro

### Data
- `app/assets/data/quiz_questions.json` - Add affirmation quiz entries

### Build
- Run `flutter pub run build_runner build --delete-conflicting-outputs` after model changes

---

## Implementation Timeline

### Sprint 1: Data Layer (2 days)
- [ ] Add `questionType` field to QuizQuestion model
- [ ] Add 6 affirmation quizzes to quiz_questions.json:
  - [ ] Relationship satisfaction (Track 0, Position 1)
  - [ ] Shared values (Track 0, Position 3)
  - [ ] Trust - "Do You Keep Secrets?" (Track 1, Position 1)
  - [ ] Emotional support (Track 1, Position 3)
  - [ ] Commitment (Track 2, Position 1)
  - [ ] Intimacy (Track 2, Position 3)
- [ ] Regenerate Hive adapters
- [ ] Verify data loads correctly

### Sprint 2: UI Components (2 days)
- [ ] Create `FivePointScaleWidget`
- [ ] Create `AffirmationIntroScreen`
- [ ] Create `AffirmationResultsScreen`
- [ ] Update `QuizScreen` to detect question type

### Sprint 3: Service Logic (1 day)
- [ ] Extend `_getTrackConfig()` with affirmation mappings
- [ ] Extend `QuizService.submitAnswers()` with affirmation scoring
- [ ] Update quest tap routing logic

### Sprint 4: Integration & Testing (1 day)
- [ ] Test affirmation quest generation (Positions 1 and 3 in each track)
- [ ] Test end-to-end quiz flow (intro → questions → results)
- [ ] Test Firebase sync across devices
- [ ] Verify LP awards (30 LP)
- [ ] Test with clean storage (no stale data)
- [ ] Verify at least 1 affirmation appears every day

**Total Estimated Effort:** 6 days

---

## Success Criteria

### Functional Requirements

✅ At least one affirmation quiz appears every day starting from day 1
✅ Affirmation quizzes appear at positions 1 and 3 in each track (50% distribution)
✅ Affirmation questions display 5-point heart scale (not multiple choice)
✅ Individual scores calculated correctly (average of 1-5 scale → 0-100%)
✅ Results screen shows individual score, not match percentage
✅ Both partners receive 30 LP when both complete
✅ Firebase sync works (second device loads quiz from first device)
✅ Quest completion tracking works (checkmark appears, quest status updates)

### Non-Functional Requirements

✅ No code duplication (reuses existing quest infrastructure)
✅ No breaking changes (existing classic quizzes continue to work)
✅ Backward compatible (existing data migrates safely with `defaultValue`)
✅ Performance (no additional latency vs classic quizzes)

---

## Risk Mitigation

### Risk 1: Data Migration Issues

**Risk:** Adding `questionType` field could break existing quiz data.

**Mitigation:** Use `@HiveField(8, defaultValue: 'multiple_choice')` to ensure existing questions default safely.

**Verification:** Test with existing quiz data before deploying.

### Risk 2: Format Type Not Passed Correctly

**Risk:** `formatType` might not propagate from `TrackConfig` → `QuizService` → `QuizSession`.

**Mitigation:** Add debug logging in `QuizService.startQuizSession()` to verify `formatType` is set correctly.

**Verification:** Check Firebase `/quiz_sessions/{sessionId}` for `formatType: 'affirmation'`.

### Risk 3: Scoring Logic Conflicts

**Risk:** Affirmation scoring might interfere with classic quiz match percentage calculation.

**Mitigation:** Use explicit `if (formatType == 'affirmation')` checks to isolate scoring logic.

**Verification:** Test both classic and affirmation quizzes to ensure neither breaks the other.

### Risk 4: UI Routing Confusion

**Risk:** Users might see wrong intro screen (classic intro for affirmation quiz, or vice versa).

**Mitigation:** Check `session.formatType` in quest tap handler before routing.

**Verification:** Test tapping both classic and affirmation quest cards.

### Risk 5: Mixed Version Deployment (Version Compatibility)

**Risk:** One partner updates app with affirmation support, other partner hasn't updated yet. Partner without update may crash when encountering `questionType: 'scale'` questions.

**Mitigation:** Add defensive checks in `quiz_screen.dart`:

```dart
Widget _buildAnswerOptions() {
  final question = currentQuestion;

  // Defensive: fallback to multiple choice if questionType is unrecognized
  if (question.questionType == 'scale') {
    return FivePointScaleWidget(...);
  } else {
    // This handles both 'multiple_choice' and null/unknown types
    return _buildMultipleChoiceOptions();
  }
}
```

**Verification:**
1. Deploy to one device only
2. Generate affirmation quest on updated device
3. Attempt to open same quest on non-updated device
4. Verify graceful fallback (no crash)

### Risk 6: Session Loading Fallback Missing

**Risk:** Second device taps affirmation quest, but session not found in local Hive storage → "Quiz Session Not Found" error (documented in QUEST_SYSTEM.md:1076-1096).

**Mitigation:** Implement Firebase fallback in `QuizService.getSession()`:

```dart
Future<QuizSession?> getSession(String sessionId) async {
  // Try local first
  var session = _storage.getQuizSession(sessionId);

  if (session == null) {
    // Firebase fallback for affirmations
    session = await _fetchSessionFromFirebase(sessionId);
    if (session != null) {
      await _storage.saveQuizSession(session);
    }
  }

  return session;
}
```

**Verification:**
1. Clear Device B's local storage (not Firebase)
2. Device A generates affirmation quest
3. Device B taps quest → should load from Firebase
4. Verify no "Session not found" error

---

## Future Enhancements

### Phase 2: Expand Affirmation Content

- Add more affirmation quizzes for each category (multiple variations)
- Add affirmations for additional categories (financial values, family planning, social life, etc.)
- Allow users to retake affirmations to track score changes over time

### Phase 3: Affirmation Insights

- Track affirmation scores over time
- Show trends ("Your trust score increased from 67% → 82%")
- Suggest follow-up quizzes based on low scores

### Phase 4: Custom Affirmations

- Allow users to create custom affirmation questions
- Share affirmations with partner
- Community-contributed affirmation question bank

---

## References

### Design Mockups
- `mockups/affirmation/01-home.html` - Home screen with affirmation quest card
- `mockups/affirmation/02-quiz-intro.html` - Intro screen with research context
- `mockups/affirmation/04-question-1.html` - 5-point heart scale design
- `mockups/affirmation/12-results-awaiting.html` - Individual scoring display

### Documentation
- `docs/QUEST_SYSTEM.md` - Daily quest system architecture
- `docs/affirmation.md` - Screen breakdown from video documentation
- `CLAUDE.md` - Technical development guide

### Tools
- `tools/transform_affirmations.dart` - JSON transformation script for converting simplified affirmation format to QuizQuestion format

### Data Files
- `data/affirmations.json` - Simplified source format (content-first)
- `data/affirmations_transformed.json` - App-ready format (QuizQuestion structure) - **READY TO USE**

### Code References
- `app/lib/models/daily_quest.dart:5-11` - QuestType enum
- `app/lib/services/quest_type_manager.dart:38-47` - TrackConfig class
- `app/lib/services/quest_type_manager.dart:116-156` - Quest generation logic
- `app/lib/services/daily_quest_service.dart:72-152` - Quest completion logic

---

## Summary of Changes (2025-11-14 Update)

### What Changed

**Original Plan:**
- 2 affirmations out of 12 quizzes (16.7%)
- First affirmation appears on Day 7 (Track 1, Position 2)
- Some days have no affirmations

**Updated Plan:**
- **6 affirmations out of 12 quizzes (50%)**
- **First affirmation appears on Day 1** (Track 0, Position 1)
- **Every day has 1-2 affirmations guaranteed**

### Impact

**Content Creation:**
- Need to create 6 affirmation quizzes instead of 2
- Total: 36 new questions (6 quizzes × 6 questions each)

**Implementation:**
- Sprint 1 extended from 1 day to 2 days (more content to create)
- Total estimated effort: 6 days (was 5 days)

**User Experience:**
- Daily self-reflection from day 1
- Better variety (mix of classic and affirmation each day)
- More balanced progression through relationship topics

### Categories Added

New affirmation categories for Track 0:
1. `relationship_satisfaction` - Overall relationship happiness
2. `shared_values` - Values alignment and expectations

These provide lighter, more accessible affirmations for new users before progressing to deeper topics like trust and intimacy.

---

**End of Document**
