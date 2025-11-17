# Quest Screen Unification Plan - Enhanced

**Version:** 2.0
**Status:** Phase 3 Complete ✅ (Classic Quiz migrated and tested)
**Deferred Items:** See DEFERRED_ITEMS.md
**Last Updated:** 2025-11-17

---

## Goals

- Unify waiting and results screens across all quest types
- Reduce code duplication (~900 lines)
- Create extensible framework for new quest types
- Fix Affirmation routing bug
- Maintain separate intro/question screens (too different to unify)

---

## Architecture Overview

### Current State

| Quest Type | Intro | Question | Waiting | Results |
|------------|-------|----------|---------|---------|
| Classic | `quiz_intro_screen.dart` | `quiz_question_screen.dart` (shared) | `quiz_waiting_screen.dart` | `quiz_results_screen.dart` |
| Affirmation | `affirmation_intro_screen.dart` | `quiz_question_screen.dart` (shared) | ❌ Bug | `affirmation_results_screen.dart` |
| You or Me | `you_or_me_intro_screen.dart` | `you_or_me_game_screen.dart` | `you_or_me_waiting_screen.dart` | `you_or_me_results_screen.dart` |

### Target State

| Component | Implementation |
|-----------|----------------|
| Intro | Quest-specific (no change) |
| Question/Game | Quest-specific (no change) |
| **Waiting** | **UnifiedWaitingScreen** (config-driven) |
| **Results** | **UnifiedResultsScreen** (pluggable content) |

### New Components

```
lib/
├── models/quest_type_config.dart       [Registry of quest configs]
├── services/quest_navigation_service.dart [Centralized routing]
├── screens/
│   ├── unified_waiting_screen.dart     [Configurable waiting]
│   └── unified_results_screen.dart     [Frame + content builder]
└── widgets/results_content/
    ├── classic_quiz_results_content.dart
    ├── affirmation_results_content.dart
    └── you_or_me_results_content.dart
```

---

## Phase 0: Pre-Implementation

**Critical design decisions and validations before coding.**

### Task 0.1: Design Type-Safe Session Handling

**Problem:** Plan uses `dynamic session` everywhere.

**Solution: Abstract Base Class**

```dart
// lib/models/base_session.dart
abstract class BaseSession {
  String get id;
  DateTime get createdAt;
  bool get isCompleted;
  bool get isExpired;

  Map<String, dynamic> toFirebase();
}

// Extend in existing models
class QuizSession extends BaseSession implements HiveObject { ... }
class YouOrMeSession extends BaseSession implements HiveObject { ... }
```

**Generic Components:**
```dart
class UnifiedWaitingScreen<T extends BaseSession> extends StatefulWidget {
  final T session;
  final WaitingConfig config;
  ...
}
```

### Task 0.2: Verify LP Award Deduplication

**Critical:** Ensure concurrent completion doesn't award double LP.

```bash
# Read and verify
cat lib/services/love_point_service.dart | grep -A 20 "deduplication\|idempotent"
```

**Validation:**
- [ ] LP awards use Firebase transaction or unique key
- [ ] Multiple calls with same params = single award
- [ ] Test: Alice and Bob submit at same time → Only 30 LP awarded (not 60)

### Task 0.3: Design Session-Quest Relationship

**Problem:** Results screen needs quest to mark complete, but only has session.

**Solution A:** Add `questId` field to sessions
```dart
class QuizSession extends BaseSession {
  @HiveField(15, defaultValue: '')
  String questId;  // Reference to DailyQuest.id
}
```

**Solution B:** Session ID encodes date → lookup quest by date
```dart
// Current pattern: session.id = "quiz_classic_abc123_20251117"
final dateKey = session.id.split('_').last;
final quests = questService.getQuestsForDate(dateKey);
final quest = quests.firstWhere((q) => q.contentId == session.id);
```

**Decision:** Use Solution B (no model changes needed).

### Task 0.4: Add Config Registration to main.dart

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // NEW: Register quest type configs
  QuestTypeConfigRegistry.registerDefaults();

  await StorageService.init();
  await NotificationService.initialize();
  ...
}
```

**Update CLAUDE.md Section 1 with new initialization step.**

### Task 0.5: Design ResultsContentBuilder for Dual Sessions

**Problem:** You or Me needs both user and partner sessions.

**Solution: Fetch in Widget**
```dart
class YouOrMeResultsContent extends StatefulWidget {
  final YouOrMeSession userSession;

  @override
  void initState() {
    super.initState();
    _loadPartnerSession();
  }

  Future<void> _loadPartnerSession() async {
    final partner = StorageService().getPartner();
    final timestamp = userSession.id.split('_').last;
    final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

    final service = YouOrMeService();
    final partnerSession = await service.getSession(partnerSessionId);
    setState(() => _partnerSession = partnerSession);
  }
}
```

**Builder signature stays simple:**
```dart
typedef ResultsContentBuilder<T extends BaseSession> = Widget Function(T session);
```

---

## Phase 1: Foundation

### Task 1.1: Create Quest Type Config Model

**File:** `lib/models/quest_type_config.dart`

```dart
enum PollingType { manual, auto, none }

class WaitingConfig {
  final PollingType pollingType;
  final Duration? pollingInterval;
  final bool showTimeRemaining;
  final bool isDualSession;  // For You or Me
  final String waitingMessage;

  const WaitingConfig({
    required this.pollingType,
    this.pollingInterval,
    this.showTimeRemaining = false,
    this.isDualSession = false,
    required this.waitingMessage,
  });
}

class ResultsConfig {
  final bool showConfetti;
  final double? confettiThreshold;
  final bool showLPBanner;

  const ResultsConfig({
    this.showConfetti = false,
    this.confettiThreshold,
    this.showLPBanner = true,
  });
}

class QuestTypeConfig<T extends BaseSession> {
  final String formatType;
  final Widget Function(T session) introBuilder;
  final Widget Function(T session) questionBuilder;
  final Widget Function(T session) resultsContentBuilder;
  final WaitingConfig waitingConfig;
  final ResultsConfig resultsConfig;

  const QuestTypeConfig({
    required this.formatType,
    required this.introBuilder,
    required this.questionBuilder,
    required this.resultsContentBuilder,
    required this.waitingConfig,
    required this.resultsConfig,
  });
}

class QuestTypeConfigRegistry {
  static final Map<String, QuestTypeConfig> _configs = {};

  static void register(String type, QuestTypeConfig config) {
    _configs[type] = config;
  }

  static QuestTypeConfig? get(String type) => _configs[type];

  static void registerDefaults() {
    // Populated in Phase 3-5
  }
}
```

### Task 1.2: Create Quest Navigation Service

**File:** `lib/services/quest_navigation_service.dart`

```dart
class QuestNavigationService {
  final StorageService _storage;

  QuestNavigationService({StorageService? storage})
      : _storage = storage ?? StorageService();

  /// Launch quest from card tap
  Future<void> launchQuest(BuildContext context, DailyQuest quest) async {
    final config = QuestTypeConfigRegistry.get(quest.formatType ?? 'classic');
    if (config == null) throw Exception('Unknown quest type: ${quest.formatType}');

    final session = _getSession(quest);
    if (session == null) throw Exception('Session not found');

    final user = _storage.getUser();
    if (user == null) return;

    // Route based on state
    if (_isCompleted(session, quest)) {
      await navigateToResults(context, session, config);
    } else if (_hasUserAnswered(session, user.id)) {
      await navigateToWaiting(context, session, config);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => config.introBuilder(session)),
      );
    }
  }

  Future<void> navigateToWaiting(
    BuildContext context,
    BaseSession session,
    QuestTypeConfig config,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedWaitingScreen(
          session: session,
          config: config.waitingConfig,
          resultsConfig: config.resultsConfig,
          resultsContentBuilder: config.resultsContentBuilder,
        ),
      ),
    );
  }

  Future<void> navigateToResults(
    BuildContext context,
    BaseSession session,
    QuestTypeConfig config,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedResultsScreen(
          session: session,
          config: config.resultsConfig,
          contentBuilder: config.resultsContentBuilder,
        ),
      ),
    );
  }

  BaseSession? _getSession(DailyQuest quest) {
    if (quest.formatType == 'youorme') {
      return _storage.getYouOrMeSession(quest.contentId);
    }
    return _storage.getQuizSession(quest.contentId);
  }

  bool _isCompleted(BaseSession session, DailyQuest quest) {
    // Check both session.isCompleted and quest completion
    return session.isCompleted;
  }

  bool _hasUserAnswered(BaseSession session, String userId) {
    if (session is QuizSession) {
      return session.hasUserAnswered(userId);
    } else if (session is YouOrMeSession) {
      return session.answers != null;
    }
    return false;
  }
}
```

### Task 1.3: Create Unified Waiting Screen

**File:** `lib/screens/unified_waiting_screen.dart`

**Key Features:**
- Manual vs auto-polling based on config
- Single-session vs dual-session partner check
- Error handling (network, session not found, expiration)
- Timer cleanup on dispose
- Navigate to results when complete

**Extract logic from:**
- `quiz_waiting_screen.dart:29-96` - Polling and status check
- `you_or_me_waiting_screen.dart:66-86` - Dual-session partner lookup

**Implementation:**
```dart
class UnifiedWaitingScreen extends StatefulWidget {
  final BaseSession session;
  final WaitingConfig config;
  final ResultsConfig resultsConfig;
  final Widget Function(BaseSession) resultsContentBuilder;

  const UnifiedWaitingScreen({
    required this.session,
    required this.config,
    required this.resultsConfig,
    required this.resultsContentBuilder,
  });
}

class _UnifiedWaitingScreenState extends State<UnifiedWaitingScreen> {
  Timer? _pollingTimer;
  late BaseSession _session;
  bool _isChecking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = widget.session;

    if (widget.config.pollingType == PollingType.auto) {
      _startAutoPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startAutoPolling() {
    _pollingTimer = Timer.periodic(
      widget.config.pollingInterval ?? Duration(seconds: 5),
      (_) => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      if (widget.config.isDualSession) {
        await _checkDualSession();
      } else {
        await _checkSingleSession();
      }
    } catch (e) {
      setState(() => _error = e.toString());
      Logger.error('Status check failed', error: e, service: 'unified');
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _checkSingleSession() async {
    // Classic or Affirmation
    final service = QuizService();
    final updated = await service.getSession(_session.id);

    if (updated == null) {
      setState(() => _error = 'Session not found');
      return;
    }

    setState(() => _session = updated);

    if (updated.isCompleted) {
      _navigateToResults();
    }
  }

  Future<void> _checkDualSession() async {
    // You or Me
    final partner = StorageService().getPartner();
    if (partner == null) return;

    final timestamp = _session.id.split('_').last;
    final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

    final service = YouOrMeService();
    final partnerSession = await service.getSession(partnerSessionId, forceRefresh: true);

    if (partnerSession != null &&
        partnerSession.answers != null &&
        (_session as YouOrMeSession).answers != null) {
      _navigateToResults();
    }
  }

  void _navigateToResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UnifiedResultsScreen(
          session: _session,
          config: widget.resultsConfig,
          contentBuilder: widget.resultsContentBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI with manual refresh button or auto-polling indicator
    // Partner status, time remaining (if config.showTimeRemaining)
    // Error state display
    // ...
  }
}
```

### Task 1.4: Create Unified Results Screen

**File:** `lib/screens/unified_results_screen.dart`

**Key Features:**
- Confetti animation (if config.showConfetti)
- LP earned banner (via existing LovePointService)
- Quest completion logic (extracted from old results screens)
- Pluggable content via builder
- Back navigation

**Extract logic from:**
- `quiz_results_screen.dart:26-41` - Confetti
- `quiz_results_screen.dart:48-127` - Quest completion

**Implementation:**
```dart
class UnifiedResultsScreen extends StatefulWidget {
  final BaseSession session;
  final ResultsConfig config;
  final Widget Function(BaseSession) contentBuilder;

  const UnifiedResultsScreen({
    required this.session,
    required this.config,
    required this.contentBuilder,
  });
}

class _UnifiedResultsScreenState extends State<UnifiedResultsScreen> {
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));

    if (_shouldShowConfetti()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    }

    _checkQuestCompletion();
  }

  bool _shouldShowConfetti() {
    if (!widget.config.showConfetti) return false;
    if (widget.config.confettiThreshold == null) return false;

    if (widget.session is QuizSession) {
      final session = widget.session as QuizSession;
      return (session.matchPercentage ?? 0) >= widget.config.confettiThreshold!;
    }
    return false;
  }

  Future<void> _checkQuestCompletion() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return;

    // Find quest by session ID
    final questService = DailyQuestService(storage: _storage);
    final todayQuests = questService.getTodayQuests();

    final quest = todayQuests.firstWhereOrNull(
      (q) => q.contentId == widget.session.id
    );

    if (quest == null) return;

    // Mark complete for user
    final bothCompleted = await questService.completeQuestForUser(
      questId: quest.id,
      userId: user.id,
    );

    // Sync to Firebase
    final syncService = QuestSyncService(storage: _storage);
    await syncService.markQuestCompleted(
      questId: quest.id,
      currentUserId: user.id,
    );

    // Award LP if both complete (LovePointService handles deduplication)
    if (bothCompleted) {
      await LovePointService.awardPoints(
        userId: user.id,
        amount: 30,
        reason: 'Quest completed: ${quest.id}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results')),
      body: Stack(
        children: [
          // Pluggable content
          widget.contentBuilder(widget.session),

          // Confetti overlay
          if (widget.config.showConfetti)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                // ... confetti config
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## Phase 2: Content Migration

### Task 2.1: Extract Classic Quiz Results Content

**File:** `lib/widgets/results_content/classic_quiz_results_content.dart`

**Extract from:** `quiz_results_screen.dart:150-620`

**Components:**
- Match percentage circle
- Answer comparison (toggleable)
- User/partner answer display

### Task 2.2: Extract Affirmation Results Content

**File:** `lib/widgets/results_content/affirmation_results_content.dart`

**Extract from:** `affirmation_results_screen.dart:100-465`

**Components:**
- Individual score display
- Partner status section
- Scale visualization

### Task 2.3: Extract You or Me Results Content

**File:** `lib/widgets/results_content/you_or_me_results_content.dart`

**Extract from:** `you_or_me_results_screen.dart:100-538`

**Components:**
- Agreement percentage
- Answer badges
- Fetch partner session in initState (per Task 0.5)

---

## Phase 3: Classic Quiz Migration

### Task 3.1: Register Classic Quiz Config

```dart
// In quest_type_config.dart registerDefaults()
register('classic', QuestTypeConfig<QuizSession>(
  formatType: 'classic',
  introBuilder: (session) => QuizIntroScreen(),
  questionBuilder: (session) => QuizQuestionScreen(session: session),
  resultsContentBuilder: (session) => ClassicQuizResultsContent(session: session),
  waitingConfig: WaitingConfig(
    pollingType: PollingType.manual,
    showTimeRemaining: true,
    waitingMessage: 'Waiting for partner to complete the quiz...',
  ),
  resultsConfig: ResultsConfig(
    showConfetti: true,
    confettiThreshold: 80.0,
  ),
));
```

### Task 3.2: Update QuizQuestionScreen Navigation

**File:** `lib/screens/quiz_question_screen.dart:151-155`

**Change:**
```dart
// BEFORE
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => QuizWaitingScreen(session: widget.session),
  ),
);

// AFTER
final navService = QuestNavigationService();
final config = QuestTypeConfigRegistry.get(widget.session.formatType ?? 'classic');
if (config != null) {
  await navService.navigateToWaiting(context, widget.session, config);
}
```

### Task 3.3: Update DailyQuestsWidget

**File:** `lib/widgets/daily_quests_widget.dart:317-432`

**Replace navigation logic:**
```dart
Future<void> _handleQuestTap(DailyQuest quest) async {
  final navService = QuestNavigationService();
  await navService.launchQuest(context, quest);
  setState(() {});  // Refresh after navigation
}
```

### Task 3.4: Test Classic Quiz End-to-End

- [ ] Intro → Questions → Unified Waiting (manual refresh) → Unified Results
- [ ] Match percentage displays correctly
- [ ] Confetti for 80%+ matches
- [ ] LP awarded (10-50 based on match)
- [ ] Quest marked complete

---

## Phase 4: Affirmation Quiz Migration

### Task 4.1: Register Affirmation Config

```dart
register('affirmation', QuestTypeConfig<QuizSession>(
  formatType: 'affirmation',
  introBuilder: (session) => AffirmationIntroScreen(session: session),
  questionBuilder: (session) => QuizQuestionScreen(session: session),
  resultsContentBuilder: (session) => AffirmationResultsContent(session: session),
  waitingConfig: WaitingConfig(
    pollingType: PollingType.auto,
    pollingInterval: Duration(seconds: 5),
    waitingMessage: 'Waiting for partner...',
  ),
  resultsConfig: ResultsConfig(
    showConfetti: false,
  ),
));
```

**Note:** Auto-polling makes UX acceptable (minimal wait).

### Task 4.2: Test Affirmation End-to-End

- [ ] Intro → Questions → Unified Waiting (auto-polls) → Unified Results
- [ ] Individual score displays
- [ ] Partner status shows
- [ ] LP awarded (30 flat)
- [ ] No confetti

---

## Phase 5: You or Me Migration

### Task 5.1: Register You or Me Config

```dart
register('youorme', QuestTypeConfig<YouOrMeSession>(
  formatType: 'youorme',
  introBuilder: (session) => YouOrMeIntroScreen(session: session),
  questionBuilder: (session) => YouOrMeGameScreen(session: session),
  resultsContentBuilder: (session) => YouOrMeResultsContent(userSession: session),
  waitingConfig: WaitingConfig(
    pollingType: PollingType.auto,
    pollingInterval: Duration(seconds: 3),
    isDualSession: true,  // CRITICAL
    waitingMessage: 'Waiting for partner...',
  ),
  resultsConfig: ResultsConfig(
    showConfetti: false,
  ),
));
```

### Task 5.2: Update YouOrMeGameScreen Navigation

**File:** `lib/screens/you_or_me_game_screen.dart`

**Find where answers are submitted, replace navigation:**
```dart
final navService = QuestNavigationService();
final config = QuestTypeConfigRegistry.get('youorme');
if (config != null) {
  await navService.navigateToWaiting(context, widget.session, config);
}
```

### Task 5.3: Test You or Me End-to-End

- [ ] Intro → Game → Unified Waiting (auto-polls, dual-session check) → Unified Results
- [ ] Agreement percentage correct
- [ ] Answer badges display
- [ ] LP awarded (30 flat)
- [ ] Dual-session partner detection works

---

## Phase 6: Validation & Cleanup

### Task 6.1: Complete Regression Testing

**Clean test (Alice on Android, Bob on Chrome):**

```bash
# Setup
adb uninstall com.togetherremind.togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
flutter run -d emulator-5554 &
flutter run -d chrome &
```

**Test all three quest types:**
- [ ] Classic: Match percentage, confetti, manual refresh, LP award
- [ ] Affirmation: Individual score, auto-poll, LP award
- [ ] You or Me: Agreement %, dual-session, auto-poll, LP award

### Task 6.2: Mark Old Files as Deprecated

**Do NOT delete yet. Add warnings:**

```dart
// lib/screens/quiz_waiting_screen.dart
// ⚠️ DEPRECATED - Use UnifiedWaitingScreen instead
// Will be deleted after production validation
// See: docs/QUEST_UNIFICATION_PLAN_V2.md

@Deprecated('Use UnifiedWaitingScreen')
class QuizWaitingScreen extends StatefulWidget { ... }
```

**Files to mark:**
- `quiz_waiting_screen.dart`
- `quiz_results_screen.dart`
- `you_or_me_waiting_screen.dart`
- `you_or_me_results_screen.dart`
- `affirmation_results_screen.dart`

### Task 6.3: Update CLAUDE.md

**Section: UI Screens**

Replace separate waiting/results entries with:

```markdown
### Quest Screens (Unified Architecture)

**Shared Components:**
- `lib/screens/unified_waiting_screen.dart` - Config-driven waiting (all quest types)
- `lib/screens/unified_results_screen.dart` - Pluggable results frame (all quest types)
- `lib/widgets/results_content/` - Quest-specific content widgets

**Quest-Specific Components:**
- Classic Quiz: `quiz_intro_screen.dart`, `quiz_question_screen.dart`, `classic_quiz_results_content.dart`
- Affirmation: `affirmation_intro_screen.dart`, `quiz_question_screen.dart`, `affirmation_results_content.dart`
- You or Me: `you_or_me_intro_screen.dart`, `you_or_me_game_screen.dart`, `you_or_me_results_content.dart`

**Configuration:**
- `lib/models/quest_type_config.dart` - Quest type registry
- `lib/services/quest_navigation_service.dart` - Centralized routing
```

**Section: Critical Architecture Rules**

Add:

```markdown
### Quest Type Configuration

**CRITICAL:** All quest types must be registered in `main.dart` during initialization.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  QuestTypeConfigRegistry.registerDefaults();  // REQUIRED
  await StorageService.init();
  ...
}
```

**Adding new quest types:**
1. Create intro, question/game, and results content widgets
2. Register config in `QuestTypeConfigRegistry.registerDefaults()`
3. Navigation handled automatically via `QuestNavigationService`

See: `docs/QUEST_UNIFICATION_PLAN_V2.md`
```

### Task 6.4: Create Migration Guide

**File:** `docs/ADDING_NEW_QUEST_TYPES.md`

Quick reference for adding new quest types using the unified framework.

**Content:**
- Required files (3: intro, game, results content)
- Config registration example
- Navigation auto-handled
- Testing checklist

---

## Success Criteria

- [ ] All three quest types work end-to-end
- [ ] LP awards trigger correctly (with deduplication)
- [ ] Quest completion syncs to Firebase
- [ ] Partner status displays correctly
- [ ] No console errors or warnings
- [ ] `flutter analyze` passes
- [ ] Confetti shows for Classic 80%+
- [ ] Auto-polling works for Affirmation and You or Me
- [ ] Manual refresh works for Classic
- [ ] Dual-session partner detection works for You or Me

---

## Rollback Plan

**Per Quest Type:**
- Uncomment old screen imports
- Revert navigation changes for that type
- Other quest types continue to work

**Complete Rollback:**
```bash
git checkout HEAD -- lib/screens/quiz_waiting_screen.dart
git checkout HEAD -- lib/screens/quiz_results_screen.dart
git checkout HEAD -- lib/screens/you_or_me_waiting_screen.dart
git checkout HEAD -- lib/screens/you_or_me_results_screen.dart
git checkout HEAD -- lib/screens/affirmation_results_screen.dart
git checkout HEAD -- lib/screens/quiz_question_screen.dart
git checkout HEAD -- lib/widgets/daily_quests_widget.dart
git checkout HEAD -- lib/screens/you_or_me_game_screen.dart

rm lib/models/quest_type_config.dart
rm lib/services/quest_navigation_service.dart
rm lib/screens/unified_waiting_screen.dart
rm lib/screens/unified_results_screen.dart
rm -rf lib/widgets/results_content/
```

---

## Files Summary

**Create:**
- `lib/models/base_session.dart`
- `lib/models/quest_type_config.dart`
- `lib/services/quest_navigation_service.dart`
- `lib/screens/unified_waiting_screen.dart`
- `lib/screens/unified_results_screen.dart`
- `lib/widgets/results_content/classic_quiz_results_content.dart`
- `lib/widgets/results_content/affirmation_results_content.dart`
- `lib/widgets/results_content/you_or_me_results_content.dart`
- `docs/ADDING_NEW_QUEST_TYPES.md`

**Modify:**
- `lib/main.dart` (add config registration)
- `lib/screens/quiz_question_screen.dart` (navigation)
- `lib/screens/you_or_me_game_screen.dart` (navigation)
- `lib/widgets/daily_quests_widget.dart` (use navigation service)
- `CLAUDE.md` (update architecture docs)

**Deprecate (delete after validation):**
- `lib/screens/quiz_waiting_screen.dart`
- `lib/screens/quiz_results_screen.dart`
- `lib/screens/you_or_me_waiting_screen.dart`
- `lib/screens/you_or_me_results_screen.dart`
- `lib/screens/affirmation_results_screen.dart`

---

## Implementation Status

**Completed Phases:**
- ✅ **Phase 0:** Pre-Implementation (2025-11-17)
  - Created BaseSession abstract class
  - Verified LP award deduplication system
  - Added config registration to main.dart

- ✅ **Phase 1:** Foundation (2025-11-17)
  - Created quest_type_config.dart with registry
  - Created quest_navigation_service.dart
  - Created unified_waiting_screen.dart
  - Created unified_results_screen.dart

- ✅ **Phase 2:** Content Migration (2025-11-17)
  - Extracted ClassicQuizResultsContent widget

- ✅ **Phase 3:** Classic Quiz Migration (2025-11-17)
  - Registered Classic Quiz config
  - Updated QuizIntroScreen with optional session parameter
  - Integrated QuestNavigationService in daily_quests_widget.dart
  - **Bug Fix:** Removed duplicate LP awarding from QuizService
  - **Bug Fix:** Improved LP deduplication using relatedId as Firebase key
  - **Tested:** End-to-end flow with 30 LP award (correct, no duplicates)

**Pending Phases:**
- ⏳ **Phase 4:** Affirmation Quiz Migration
- ⏳ **Phase 5:** You or Me Migration
- ⏳ **Phase 6:** Validation & Cleanup

---

**End of Plan**
