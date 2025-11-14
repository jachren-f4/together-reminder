# You or Me? Game - Feature Specification

**Version:** 1.0
**Date:** 2025-11-13
**Status:** Draft

---

## Overview

"You or Me?" is a couples personality game that presents playful questions comparing partners across various traits, behaviors, and scenarios. Players answer questions about who best matches each prompt, creating an engaging way to learn more about each other while having fun.

### Goals
- Provide an entertaining, low-pressure activity for couples
- Encourage self-reflection and conversation
- Integrate with TogetherRemind's Love Points system
- Support both synchronous and asynchronous gameplay

---

## User Flow

### Entry Points
1. **Activities Screen** - Game card labeled "You or Me?"
2. **Daily Quests** - Can be assigned as a daily activity
3. **Push Notification** - Partner invitation to play together

### Game Flow

```
Launch Game
    ↓
Intro Screen (optional)
    ↓
Question 1/10 - Card with prompt
    ↓
User selects answer (Me / Partner / Neither / Both)
    ↓
Card animates away
    ↓
Question 2/10
    ↓
... (repeat for 10 questions)
    ↓
Results Screen
    ↓
Share with partner / Return to Activities
```

---

## UI/UX Design

### Design System
- **Color Palette:** Black & White (matches app theme)
  - Background: `#FAFAFA`
  - Cards: `#FFFEFD` with `#F0F0F0` borders
  - Text: `#1A1A1A` (primary), `#6E6E6E` (secondary)

- **Typography:**
  - Headers: Playfair Display (serif) - 36px for prompts, 42px for traits
  - Body: Inter (sans-serif) - all other text

- **Layout:** Mobile-first, max-width 430px, centered

### Screen Components

#### 1. Header
- Back button (top-left, circular with border)
- No title or badge (minimal design)

#### 2. Progress Bar
- Linear progress indicator
- Shows current question (1-10)
- Black fill on light gray background
- Updates smoothly between questions

#### 3. Question Area
**Question Prompt** (dynamic text):
- "Who's more..."
- "Who would..."
- "Who's more likely to..."
- "Which of you..."

**Card Stack** (3 layered cards):
- Front card: Fully visible, contains question
- Middle card: 96% width, slightly faded (60% opacity)
- Back card: 92% width, very faded (30% opacity)
- Creates depth and shows upcoming questions

**Card Content:**
- Top: "Question X of 10" (gray, 15px)
- Center: Trait/scenario text (Playfair Display, 42px)

#### 4. Answer Section
White card containing:

**Primary Answers** (circular buttons):
- Left: User initial in circle (e.g., "J")
- Center: "or" text divider
- Right: "Your partner" text in circle

**Secondary Options:**
- "More options" link (underlined, gray)

**Button States:**
- Default: White background, black border
- Hover: Black background, white text
- Active: Slightly scaled down

#### 5. Bottom Sheet Modal
Triggered by "More options" button.

**Visual Design:**
- Slides up from bottom (~25% of screen height)
- Semi-transparent overlay (40% black)
- Rounded top corners (32px radius)
- Drag handle at top (40px × 4px gray bar)

**Content:**
- Title: "Select an option" (18px, bold)
- Option buttons (full-width):
  - "Neither"
  - "Both"

**Flutter Implementation Example:**
```dart
void _showMoreOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Select an option',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          _buildSheetOption('Neither', () => _selectAnswer('neither')),
          const SizedBox(height: 12),
          _buildSheetOption('Both', () => _selectAnswer('both')),
        ],
      ),
    ),
  );
}
```

---

## Question System

### Question Structure

Each question consists of:
- **Prompt:** The question format (e.g., "Who's more...")
- **Content:** The specific trait/scenario (e.g., "Creative")
- **Category:** Grouping for variety (Personality, Habits, Scenarios)

### Question Categories

#### 1. Personality Traits
**Prompt:** "Who's more..."
- Creative
- Organized
- Spontaneous
- Introverted
- Ambitious
- Patient
- Playful
- Romantic
- Practical
- Optimistic

#### 2. Actions & Behaviors
**Prompt:** "Who would..."
- Plan the perfect date
- Cook dinner tonight
- Wake up first
- Apologize first after an argument
- Win at trivia night
- Suggest a spontaneous trip
- Choose the movie
- Remember important dates

#### 3. Likelihood Scenarios
**Prompt:** "Who's more likely to..."
- Start a spontaneous adventure
- Forget an anniversary
- Fall asleep during a movie
- Try a new hobby
- Get lost while driving
- Make the bed in the morning
- Cry during a sad movie
- Stay up late talking

#### 4. Comparative Questions
**Prompt:** "Which of you..."
- Is the better dancer
- Is the better cook
- Is funnier
- Is more adventurous
- Is the better listener
- Is more competitive

### Question Pool Management

**Total Questions:** 50+ (deliver 10 per session)
**Selection Strategy:**
- Random selection from pool
- Ensure variety across categories (3-4 categories per session)
- Track previously asked questions to avoid repetition
- Reset after all questions exhausted

**Data Model:**
```dart
class YouOrMeQuestion {
  final String id;
  final String prompt;        // "Who's more...", "Who would...", etc.
  final String content;       // "Creative", "Plan the perfect date", etc.
  final String category;      // "personality", "actions", "scenarios", "comparative"

  YouOrMeQuestion({
    required this.id,
    required this.prompt,
    required this.content,
    required this.category,
  });
}
```

---

## Game Mechanics

### Answer Types

1. **"Me"** - User selects themselves
2. **"Your partner"** - User selects their partner
3. **"Neither"** - Neither partner fits the description
4. **"Both"** - Both partners equally fit the description

### Session Data

**Data Model:**
```dart
class YouOrMeSession {
  final String sessionId;
  final String userId;
  final String coupleId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<YouOrMeAnswer> answers;
  final SessionStatus status;    // in_progress, completed, abandoned

  YouOrMeSession({
    required this.sessionId,
    required this.userId,
    required this.coupleId,
    required this.startedAt,
    this.completedAt,
    required this.answers,
    required this.status,
  });
}

class YouOrMeAnswer {
  final String questionId;
  final String questionPrompt;
  final String questionContent;
  final AnswerType answerType;   // me, partner, neither, both
  final DateTime answeredAt;

  YouOrMeAnswer({
    required this.questionId,
    required this.questionPrompt,
    required this.questionContent,
    required this.answerType,
    required this.answeredAt,
  });
}

enum AnswerType { me, partner, neither, both }
```

### Card Animations

**Answer Selection Animation:**
```dart
// When user selects an answer
void _animateCardExit() {
  setState(() {
    _cardController.forward().then((_) {
      // Move to next question
      _nextQuestion();
      // Reset card position for next question
      _cardController.reset();
    });
  });
}

// Animation definition
AnimationController _cardController = AnimationController(
  duration: const Duration(milliseconds: 300),
  vsync: this,
);

Animation<Offset> _slideAnimation = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(1.5, 0),  // Slide right
).animate(CurvedAnimation(
  parent: _cardController,
  curve: Curves.easeInOut,
));

Animation<double> _rotationAnimation = Tween<double>(
  begin: 0,
  end: 0.35,  // ~20 degrees
).animate(CurvedAnimation(
  parent: _cardController,
  curve: Curves.easeInOut,
));
```

**Card Stack Implementation:**
Use `Stack` widget with positioned cards at different z-indexes and scales to create depth effect.

---

## Results Screen

### Results Display

**Stats to Show:**
1. **Most selected answer:**
   - "You mostly picked yourself!" (with percentage)
   - "You mostly picked your partner!" (with percentage)
   - "You see things equally!" (if balanced)

2. **Category Breakdown:**
   - Personality: 60% You, 40% Partner
   - Actions: 50% You, 50% Partner
   - Scenarios: 70% Partner, 30% You

3. **Interesting Insights:**
   - "You both agreed on 3 'Both' answers!"
   - "You picked 'Neither' only once"

### Sharing Options

1. **Share with Partner**
   - Send results as a message/notification
   - Partner can view and compare (if they also played)

2. **Compare Results** (if both played)
   - Show side-by-side comparison
   - Highlight agreements and disagreements
   - "You both think [Partner] is more creative!"
   - "You disagree on who's more organized"

3. **Play Again**
   - Start new session with different questions

---

## Love Points Integration

### Earning Love Points

**Completion Rewards:**
- Complete game: **+10 LP**
- Both partners complete: **+20 LP** (bonus)

**Engagement Bonuses:**
- Use "Both" answer: **+2 LP** (shows appreciation)
- Complete within 24 hours of partner: **+5 LP** (timely engagement)

### Love Point Transaction Model

```dart
// After session completion
LovePointTransaction(
  id: generateId(),
  coupleId: coupleId,
  amount: 10,
  source: 'you_or_me_game',
  description: 'Completed You or Me? game',
  earnedBy: userId,
  createdAt: DateTime.now(),
  metadata: {
    'sessionId': sessionId,
    'questionsAnswered': 10,
  },
);
```

---

## Storage & Sync

### Local Storage (Hive)

**Box:** `you_or_me_sessions`

**Data to Store:**
- User's sessions (all attempts)
- Question pool and last-used questions
- Results history

**Hive Type Adapter:**
```dart
@HiveType(typeId: 15)  // Assign next available typeId
class YouOrMeSession extends HiveObject {
  @HiveField(0)
  late String sessionId;

  @HiveField(1)
  late String userId;

  @HiveField(2)
  late String coupleId;

  @HiveField(3)
  late DateTime startedAt;

  @HiveField(4)
  DateTime? completedAt;

  @HiveField(5)
  late List<YouOrMeAnswer> answers;

  @HiveField(6, defaultValue: 'in_progress')
  late String status;
}
```

### Firebase RTDB Sync

**Path Structure:**
```
/you_or_me_sessions/{coupleId}/{sessionId}
  - userId: string
  - startedAt: timestamp
  - completedAt: timestamp (nullable)
  - answers: array
  - status: string
```

**Security Rules:**
```json
{
  "you_or_me_sessions": {
    "$coupleId": {
      "$sessionId": {
        ".read": "auth != null",
        ".write": "auth != null && !data.exists()"
      }
    }
  }
}
```

**Sync Strategy:**
- Save locally first (instant feedback)
- Sync to Firebase in background
- Partner can view completed sessions
- Use for comparison feature

---

## Daily Quest Integration

### Quest Definition

**Quest Type:** `you_or_me_game`

**Quest Model:**
```dart
DailyQuest(
  id: generateId(),
  type: QuestType.youOrMeGame,
  title: 'You or Me?',
  description: 'Play the You or Me? game',
  icon: '🎭',
  lovePointReward: 10,
  requiresBothPartners: false,  // Can be completed solo
  bonusLovePoints: 10,          // If both partners complete
  participants: [],
  status: QuestStatus.pending,
  createdAt: DateTime.now(),
);
```

### Quest Completion

**Completion Criteria:**
- User completes all 10 questions
- Session saved to local and Firebase

**Service Integration:**
```dart
// In DailyQuestService
Future<void> completeYouOrMeQuest(String sessionId) async {
  final quest = await _getQuestByType(QuestType.youOrMeGame);
  if (quest != null) {
    await markQuestComplete(quest.id, sessionId);
    await _checkBothPartnersComplete(quest);
  }
}
```

---

## Technical Implementation

### File Structure

```
lib/
  models/
    you_or_me_question.dart       # Question data model
    you_or_me_session.dart        # Session data model
    you_or_me_session.g.dart      # Hive adapter

  screens/
    you_or_me_intro_screen.dart   # Optional intro screen
    you_or_me_game_screen.dart    # Main game screen
    you_or_me_results_screen.dart # Results/stats screen

  services/
    you_or_me_service.dart        # Game logic & question management
    you_or_me_sync_service.dart   # Firebase sync

  widgets/
    you_or_me_card.dart           # Question card widget
    you_or_me_answer_buttons.dart # Answer button group
    you_or_me_progress_bar.dart   # Progress indicator

assets/
  data/
    you_or_me_questions.json      # Question bank
```

### Service Architecture

**YouOrMeService Responsibilities:**
- Load questions from JSON
- Select 10 random questions per session
- Track used questions to avoid repetition
- Manage session state
- Calculate results/stats
- Award Love Points

**YouOrMeSyncService Responsibilities:**
- Sync completed sessions to Firebase
- Fetch partner's sessions
- Enable comparison functionality
- Handle offline/online states

### Question Bank JSON Structure

```json
{
  "questions": [
    {
      "id": "q001",
      "prompt": "Who's more...",
      "content": "Creative",
      "category": "personality"
    },
    {
      "id": "q002",
      "prompt": "Who would...",
      "content": "Plan the perfect date",
      "category": "actions"
    },
    {
      "id": "q003",
      "prompt": "Who's more likely to...",
      "content": "Start a spontaneous adventure",
      "category": "scenarios"
    }
  ]
}
```

### State Management

Use existing app patterns (likely StatefulWidget or Provider):

**Session State:**
- Current question index
- Answers list
- Animation states
- Bottom sheet visibility

**Example State Variables:**
```dart
class _YouOrMeGameScreenState extends State<YouOrMeGameScreen> {
  int _currentQuestionIndex = 0;
  List<YouOrMeQuestion> _questions = [];
  List<YouOrMeAnswer> _answers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await YouOrMeService.getRandomQuestions(10);
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _handleAnswer(AnswerType answerType) {
    final answer = YouOrMeAnswer(
      questionId: _questions[_currentQuestionIndex].id,
      questionPrompt: _questions[_currentQuestionIndex].prompt,
      questionContent: _questions[_currentQuestionIndex].content,
      answerType: answerType,
      answeredAt: DateTime.now(),
    );

    setState(() {
      _answers.add(answer);
    });

    _animateToNextQuestion();
  }
}
```

---

## Analytics & Metrics

### Events to Track

1. **Game Started**
   - Timestamp
   - Entry point (Activities, Daily Quest, Push)

2. **Question Answered**
   - Question ID
   - Answer type
   - Time to answer

3. **Game Completed**
   - Duration
   - Completion rate
   - Answer distribution

4. **Bottom Sheet Opened**
   - Track usage of "More options"

5. **Results Shared**
   - Track sharing to partner

### Engagement Metrics

- **Completion Rate:** % of started games that finish
- **Average Time per Question:** User engagement indicator
- **Answer Distribution:** Me vs Partner vs Neither vs Both
- **Repeat Play Rate:** Users who play multiple times
- **Couple Engagement:** Both partners playing

---

## Future Enhancements

### Phase 2 Features

1. **Custom Questions**
   - Couples can add their own questions
   - Share custom question packs

2. **Themed Packs**
   - Holiday editions
   - Relationship milestones
   - Long-distance couples

3. **Timed Mode**
   - Speed round with countdown
   - Extra LP for fast completion

4. **Comparison Mode**
   - Real-time play with partner
   - See partner's answers immediately
   - Discuss disagreements

5. **Streak System**
   - Play X days in a row
   - Bonus LP for streaks

6. **Question Expansion**
   - 100+ question pool
   - AI-generated personalized questions
   - Community-submitted questions

### Technical Debt & Considerations

1. **Question Quality**
   - Regularly review and update questions
   - A/B test new question formats
   - Monitor skip rates per question

2. **Localization**
   - Translate questions to multiple languages
   - Cultural sensitivity review

3. **Accessibility**
   - Screen reader support
   - Color blind friendly design
   - Font size adjustments

4. **Performance**
   - Optimize card animations
   - Lazy load questions
   - Cache question bank locally

---

## Launch Checklist

### Pre-Launch
- [ ] Design mockup approved
- [ ] Question bank finalized (50+ questions)
- [ ] Data models defined
- [ ] Hive adapters generated
- [ ] Firebase security rules deployed
- [ ] Love Points integration tested
- [ ] Daily Quest integration tested
- [ ] Analytics events configured

### Development
- [ ] Intro screen (optional)
- [ ] Game screen with card stack
- [ ] Answer buttons and interactions
- [ ] Bottom sheet modal
- [ ] Progress bar
- [ ] Results screen
- [ ] Service layer (question management)
- [ ] Sync service (Firebase)
- [ ] Storage layer (Hive)

### Testing
- [ ] UI/UX review
- [ ] Animation smoothness
- [ ] Both partners completion flow
- [ ] Love Points awarded correctly
- [ ] Offline functionality
- [ ] Cross-device sync
- [ ] Question randomization
- [ ] No duplicate questions in session

### Launch
- [ ] Activities screen entry point
- [ ] Push notification template
- [ ] App Store screenshots
- [ ] Feature announcement
- [ ] Monitor analytics
- [ ] Gather user feedback

---

## Open Questions

1. **Intro Screen:** Do we need an intro/tutorial screen, or jump straight to questions?
2. **Session Persistence:** Should abandoned sessions be resumable or discarded?
3. **Question Pool Updates:** How often should we refresh the question bank?
4. **Partner Notifications:** Should completing the game notify the partner automatically?
5. **Scoring System:** Beyond LP, should there be any in-game scoring or achievements?

---

## Appendix: Design References

### HTML Mockup
See: `/mockups/you_or_me_game.html`

**Key Features:**
- Responsive design (max-width 430px)
- Card stack with 3 layers
- Smooth slide animations
- Bottom sheet modal
- Progress bar updates
- Dynamic question prompts

### Color Palette Reference
```
Primary Black:    #1A1A1A
Primary White:    #FFFEFD
Background Gray:  #FAFAFA
Border Light:     #F0F0F0
Border Medium:    #E0E0E0
Text Secondary:   #6E6E6E
Text Tertiary:    #AAAAAA
```

### Font Reference
```
Playfair Display (serif):
- Question prompts: 36px, weight 700
- Trait/content text: 42px, weight 700

Inter (sans-serif):
- Body text: 15-16px, weight 400-500
- Buttons: 16-18px, weight 600
- Labels: 13-15px, weight 500
```

---

**End of Specification**
