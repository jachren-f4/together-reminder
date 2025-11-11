# 🃏 Memory Flip Co-op - Implementation Plan for TogetherRemind

**Status:** Ready for Development
**Priority:** MVP Phase 1
**Complexity:** ★★☆ (Medium)
**Estimated Dev Time:** 2-3 weeks

---

## 📋 Executive Summary

Memory Flip Co-op is an asynchronous cooperative memory card game where couples work together to find matching pairs over multiple days. Each partner gets limited daily flips (e.g., 3-5 per day), and each turn involves flipping 2 cards - if they match, they stay revealed; if not, they flip back hidden after a moment.

**Interactive Mockup:** A fully functional HTML mockup matching TogetherRemind's design system is available at:
`/Users/joakimachren/Desktop/togetherremind/mockups/memoryflip/index.html`

**Key Innovation:** The async gameplay works by having each player flip pairs during their own session. When both partners contribute flips over time, they gradually reveal all matches together, creating a collaborative bonding experience spread across multiple days.

---

## 🎯 Core Game Mechanics

### Game Flow

1. **Daily Puzzle Generation**
   - New puzzle board generated every 24 hours (or weekly for slower pace)
   - 12-16 cards (6-8 pairs) arranged in 3×4 or 4×4 grid
   - Each pair has a romantic quote/memory that unlocks when matched

2. **Flip Allowance System**
   - Each partner gets 4-8 flips per day (must be even number, since each turn = 2 flips)
   - Recommended: 6 flips per day (allows 3 matching attempts)
   - Resets at midnight (or 24h after first flip)
   - Unused flips don't roll over (encourages daily engagement)
   - Counter shows: "6 flips left • Resets in 8h"

3. **Turn-Based Flipping**
   - Each turn, player flips exactly 2 cards
   - Cards are revealed simultaneously (or one after another)
   - If cards match → they stay revealed permanently (green border)
   - If cards don't match → they flip back hidden after 1-2 seconds
   - This follows traditional memory game rules

4. **Match Detection**
   - Auto-detects when 2 flipped cards have the same emoji
   - Locks both cards as "matched" (green border)
   - Shows romantic quote/memory associated with that pair
   - Decrements flip counter by 2 (one flip per card revealed)
   - Push notification to partner: "Match found! 🌸 Flowers"

5. **Completion & Rewards**
   - When all pairs matched, show completion animation
   - Award Love Points based on completion time (faster = more points)
   - Unlock a shared "memory" (photo caption or romantic note)
   - New puzzle available next day/week

---

## 🗂️ Data Models

### MemoryPuzzle (Hive)

```dart
@HiveType(typeId: 3)
class MemoryPuzzle extends HiveObject {
  @HiveField(0) late String id;              // UUID
  @HiveField(1) late DateTime createdAt;     // When puzzle was generated
  @HiveField(2) late DateTime expiresAt;     // When next puzzle generates
  @HiveField(3) late List<MemoryCard> cards; // All cards in puzzle
  @HiveField(4) late String status;          // 'active' | 'completed'
  @HiveField(5) late int totalPairs;         // 6-8 pairs
  @HiveField(6) late int matchedPairs;       // Count of completed pairs
  @HiveField(7) DateTime? completedAt;       // When fully solved
  @HiveField(8) late String completionQuote; // Unlock when done
}
```

### MemoryCard (Hive)

```dart
@HiveType(typeId: 4)
class MemoryCard extends HiveObject {
  @HiveField(0) late String id;              // UUID
  @HiveField(1) late String puzzleId;        // Parent puzzle
  @HiveField(2) late int position;           // 0-15 (grid position)
  @HiveField(3) late String emoji;           // 🌸, ☕, 🎵, etc.
  @HiveField(4) late String pairId;          // Links 2 cards together
  @HiveField(5) late String status;          // 'hidden' | 'matched'
  @HiveField(6) String? matchedBy;           // userId who completed match
  @HiveField(7) DateTime? matchedAt;         // Timestamp of match
  @HiveField(8) late String revealQuote;     // Quote shown when pair matched
}
```

### MemoryFlipAllowance (Hive)

```dart
@HiveType(typeId: 5)
class MemoryFlipAllowance extends HiveObject {
  @HiveField(0) late String userId;          // Current user
  @HiveField(1) late int flipsRemaining;     // 0-5
  @HiveField(2) late DateTime resetsAt;      // When allowance refills
  @HiveField(3) late int totalFlipsToday;    // Track daily usage
  @HiveField(4) late DateTime lastFlipAt;    // Last flip timestamp
}
```

---

## 🏗️ Technical Architecture

### Services to Create

#### 1. `MemoryFlipService` (Core Logic)

**Location:** `lib/services/memory_flip_service.dart`

**Responsibilities:**
- Puzzle generation and card shuffling
- Flip allowance management
- Match detection and validation
- State synchronization between partners
- Love Points calculation

**Key Methods:**
```dart
// Generate new puzzle
Future<MemoryPuzzle> generateDailyPuzzle();

// Get current active puzzle
MemoryPuzzle? getCurrentPuzzle();

// Check if user can flip
Future<bool> canFlip(String userId);

// Flip a card
Future<MemoryCard> flipCard(String cardId, String userId);

// Check for matches after flip
Future<MatchResult?> checkForMatches(MemoryPuzzle puzzle);

// Mark cards as matched
Future<void> matchCards(String card1Id, String card2Id, String userId);

// Get flip allowance for user
MemoryFlipAllowance getFlipAllowance(String userId);

// Reset daily allowance
Future<void> resetDailyAllowance(String userId);

// Calculate Love Points reward
int calculateLovePoints(MemoryPuzzle puzzle);

// Send match notification to partner
Future<void> notifyPartnerOfMatch(String emoji, String quote);

// Send reveal notification to partner
Future<void> notifyPartnerOfFlip(String emoji);
```

#### 2. `MemoryContentBank` (Content Management)

**Location:** `lib/services/memory_content_bank.dart`

**Responsibilities:**
- Store emoji pairs and associated quotes
- Categorize content by theme (romantic, playful, nostalgic)
- Ensure variety in daily puzzles

**Content Structure:**
```dart
class MemoryPair {
  final String emoji;
  final String quote;
  final String theme; // 'romantic', 'playful', 'nostalgic'

  const MemoryPair(this.emoji, this.quote, this.theme);
}

// Example content bank
static const List<MemoryPair> pairs = [
  MemoryPair('🌸', 'Like flowers, our love blooms every season', 'romantic'),
  MemoryPair('☕', 'Every morning with you starts with warmth', 'playful'),
  MemoryPair('🌙', 'Under the same moon, always together', 'romantic'),
  MemoryPair('🎵', 'Our song plays in my heart all day', 'nostalgic'),
  MemoryPair('📚', 'Every page of our story gets better', 'romantic'),
  MemoryPair('🎨', 'You color my world in ways I never imagined', 'playful'),
  MemoryPair('🌟', 'You make every ordinary moment shine', 'romantic'),
  MemoryPair('🏖️', 'Sunshine feels brighter when we\'re together', 'nostalgic'),
  // ... 20-30 more pairs for variety
];
```

---

## 🎨 UI Components

### Visual Design Reference

**See the interactive mockup for exact visual styling:**
- File: `/mockups/memoryflip/index.html`
- Matches TogetherRemind's minimalist black & white design system
- Uses Playfair Display for headlines, Inter for body text
- Clean borders, no gradients, simple animations

### 1. MemoryFlipHubCard (Hub Integration)

**Location:** `lib/widgets/memory_flip_hub_card.dart`

**Displays:**
- Current puzzle progress (e.g., "2/8 pairs found")
- Flips remaining today
- Latest activity ("Partner found a match! ☕")
- Thumbnail preview of puzzle board
- Tap to open full game screen

**Design:**
```
┌─────────────────────────────────┐
│ 🃏 Memory Flip Co-op            │
├─────────────────────────────────┤
│ [Mini grid preview with colors] │
│                                  │
│ Progress: ████░░ 3/6 pairs      │
│                                  │
│ 💬 Partner matched ☕ Coffee!    │
│                                  │
│ 🔄 3 flips left • Resets in 5h  │
└─────────────────────────────────┘
```

### 2. MemoryFlipGameScreen (Main Game)

**Location:** `lib/screens/memory_flip_game_screen.dart`

**Layout:**
- AppBar with puzzle timer and progress
- Flip allowance banner (prominent at top)
- Partner activity feed (recent flips/matches)
- 3×4 or 4×4 card grid (responsive sizing)
- Match reveal overlay (when pair found)
- Bottom stats bar (pairs found, Love Points)

**Card States:**
- Hidden (black background, heart icon)
- Flipped (white background, black border, emoji visible - temporary state)
- Matched (white background, green border, emoji visible - permanent)

**Interactions:**
- Tap card → flip animation (0.3s)
- Check flip allowance before flipping
- Show quote overlay when match found (3s auto-dismiss)
- Confetti animation on puzzle completion

### 3. MatchRevealDialog (Celebration)

**Location:** `lib/widgets/match_reveal_dialog.dart`

**Displays:**
- Matched emoji pair (large icons)
- Romantic quote
- Love Points earned (+10-20)
- "Your partner will see this too!" message
- Tap to dismiss or auto-dismiss after 3s

---

## 🔄 State Synchronization

### Cloud Functions

#### 1. `syncMemoryFlip`

**Location:** `functions/index.js`

**Trigger:** Called when user flips a card or match is found

**Responsibilities:**
- Update puzzle state in Firestore (backup)
- Validate flip allowance server-side
- Send push notification to partner
- Detect cheating (too many flips, invalid moves)

**Payload:**
```javascript
{
  puzzleId: string,
  cardId: string,
  userId: string,
  action: 'flip' | 'match',
  timestamp: number
}
```

**Response:**
```javascript
{
  success: boolean,
  updatedPuzzle: MemoryPuzzle,
  matchFound?: {
    emoji: string,
    quote: string,
    lovePoints: number
  },
  error?: string
}
```

#### 2. `notifyMemoryFlipAction`

**Sends push notifications:**
- "Your partner found a match! ☕ Coffee"
- "Partner revealed a card • 2 flips left today"
- "New Memory Flip puzzle available!"

---

## 📱 Push Notifications

### Notification Types

1. **Match Found** (High Priority)
   ```
   Title: "Match Found! 🌸"
   Body: "Your partner completed the Flowers pair"
   Action: Open game screen
   ```

2. **Partner Flipped Card** (Low Priority, batched)
   ```
   Title: "Memory Flip Activity"
   Body: "Your partner revealed 2 cards today"
   Action: Open game screen
   ```

3. **New Puzzle Available**
   ```
   Title: "New Memory Flip puzzle! 🃏"
   Body: "Fresh cards are waiting for you both"
   Action: Open game screen
   ```

4. **Puzzle Completed**
   ```
   Title: "Puzzle Complete! 🎉"
   Body: "You both matched all 6 pairs in 2 days"
   Action: Open completion screen
   ```

---

## 🎮 Game Balancing

### Difficulty Tuning

**Easy Mode (Recommended for MVP):**
- 8 pairs (16 cards) in 4×4 grid
- 6 flips per day per person (allows 3 matching attempts)
- Puzzles reset weekly

**Medium Mode:**
- 8 pairs (16 cards) in 4×4 grid
- 4 flips per day per person (allows 2 matching attempts)
- Puzzles reset every 3 days

**Hard Mode (Future):**
- 10 pairs (20 cards) in 4×5 grid
- 4 flips per day per person (allows 2 matching attempts)
- Puzzles reset daily

### Love Points Calculation

```dart
int calculateLovePoints(MemoryPuzzle puzzle) {
  int basePoints = 50; // Completion bonus
  int pairBonus = puzzle.totalPairs * 10; // 10 per pair

  // Time bonus (complete faster = more points)
  Duration timeToComplete = puzzle.completedAt!.difference(puzzle.createdAt);
  int daysTaken = timeToComplete.inDays;
  int timeBonus = max(0, 30 - (daysTaken * 5)); // -5 per day

  return basePoints + pairBonus + timeBonus;
}
```

**Example:**
- 6 pairs completed in 2 days = 50 + 60 + 20 = **130 points**
- 6 pairs completed in 7 days = 50 + 60 + 0 = **110 points**

---

## 🧪 Testing Strategy

### Unit Tests

**`memory_flip_service_test.dart`:**
- ✅ Generate puzzle with correct number of pairs
- ✅ Shuffle cards randomly
- ✅ Flip allowance decrements by 2 per turn
- ✅ Match detection works for 2 flipped cards
- ✅ Non-matching cards flip back to hidden
- ✅ Matching cards stay permanently revealed
- ✅ Can't flip when allowance exhausted
- ✅ Can't flip when allowance is odd (requires 2 flips minimum)
- ✅ Daily allowance resets at midnight
- ✅ Love Points calculated correctly

### Integration Tests

**Two-device testing:**
- ✅ User A flips card → User B sees it immediately
- ✅ User B matches User A's card → both see completion
- ✅ Push notifications arrive on partner's device
- ✅ Puzzle state syncs across devices
- ✅ Allowance tracked independently per user

### Edge Cases

- ⚠️ What if both partners flip cards simultaneously?
  - **Solution:** Server-side validation with timestamps, proper state locking
- ⚠️ What if user has only 1 flip remaining?
  - **Solution:** Disable flip button, show message "Need 2 flips for one turn"
- ⚠️ What if user runs out of flips before puzzle complete?
  - **Solution:** Partner can continue, or wait for daily reset
- ⚠️ What if user uninstalls app mid-puzzle?
  - **Solution:** Puzzle state saved in Firestore, restores on reinstall
- ⚠️ What if puzzle expires before completion?
  - **Solution:** Mark as "incomplete," generate new puzzle, archive old

---

## 📦 Asset Requirements

### Emojis (Card Content)

Need 20-30 emoji pairs with romantic/relationship themes:

**Romantic:**
- 🌸 Flowers, 💐 Bouquet, 🌹 Rose
- ❤️ Heart, 💕 Hearts, 💖 Sparkling Heart
- 💍 Ring, 💎 Diamond
- 🌙 Moon, ⭐ Star, 🌟 Sparkle

**Shared Activities:**
- ☕ Coffee, 🍕 Pizza, 🍝 Pasta, 🍷 Wine
- 🎵 Music, 🎬 Movie, 📚 Books
- 🏖️ Beach, 🏔️ Mountain, 🌴 Palm Tree
- ✈️ Travel, 🎒 Adventure

**Playful:**
- 🐱 Cat, 🐶 Dog, 🐻 Bear
- 🎨 Art, 🎮 Gaming, 📷 Photo

### Sounds (Optional)

- `flip.mp3` - Card flip sound (0.2s)
- `match.mp3` - Match found chime (0.5s)
- `complete.mp3` - Puzzle completed fanfare (2s)

### Animations (Lottie - Optional)

- `card_flip.json` - 3D card flip animation
- `match_sparkle.json` - Sparkle effect on match
- `puzzle_complete.json` - Confetti celebration

---

## 🚀 Implementation Phases

### Phase 1: Core Mechanics (Week 1)

**Tasks:**
- [ ] Create Hive data models (MemoryPuzzle, MemoryCard, MemoryFlipAllowance)
- [ ] Generate adapters: `flutter pub run build_runner build`
- [ ] Implement MemoryFlipService with puzzle generation
- [ ] Implement flip allowance system with daily reset
- [ ] Create MemoryContentBank with 30 emoji pairs + quotes
- [ ] Write unit tests for core logic

**Deliverable:** Service layer functional, testable via Dart console

### Phase 2: UI Implementation (Week 1-2)

**Tasks:**
- [ ] Build MemoryFlipGameScreen with card grid
- [ ] Implement card flip animation (setState or AnimatedContainer)
- [ ] Show flip allowance banner at top
- [ ] Display revealed cards with badges ("You", "❤️")
- [ ] Build MatchRevealDialog overlay
- [ ] Integrate with StorageService (save/load puzzles)
- [ ] Add MemoryFlipHubCard to home screen hub

**Deliverable:** Fully playable single-device experience

### Phase 3: Multi-Device Sync (Week 2)

**Tasks:**
- [ ] Create `syncMemoryFlip` Cloud Function
- [ ] Add Firestore backup for puzzle state
- [ ] Implement real-time sync on card flip
- [ ] Implement real-time sync on match found
- [ ] Send push notifications for matches
- [ ] Test on two physical devices (Alice & Bob)

**Deliverable:** Async multiplayer working between partners

### Phase 4: Polish & Integration (Week 2-3)

**Tasks:**
- [ ] Add confetti animation on puzzle completion
- [ ] Implement Love Points calculation and storage
- [ ] Add daily puzzle generation cron (midnight UTC)
- [ ] Create onboarding tutorial (first time playing)
- [ ] Add "How to Play" info icon in AppBar
- [ ] Write integration tests (dual emulator setup)
- [ ] Performance testing (card grid rendering)

**Deliverable:** Production-ready MVP feature

---

## 🔗 Integration Points with TogetherRemind

### 1. Home Screen Hub

Add Memory Flip card to hub:

```dart
// lib/screens/home_screen.dart
children: [
  PokeCard(),
  WordLadderCard(),
  MemoryFlipHubCard(), // <-- NEW
  QuizCard(),
]
```

### 2. Love Points System

Integrate with existing points tracking:

```dart
// After puzzle completion
await LovePointsService().awardPoints(
  userId: user.id,
  partnerId: partner.id,
  points: lovePoints,
  source: 'memory_flip_complete',
  metadata: {'puzzleId': puzzle.id, 'daysTaken': 2}
);
```

### 3. Push Notifications

Use existing NotificationService:

```dart
// lib/services/notification_service.dart
Future<void> sendMemoryFlipNotification({
  required String partnerToken,
  required String type, // 'match' | 'flip' | 'new_puzzle'
  required Map<String, dynamic> data,
}) async {
  // Use existing FCM logic
}
```

### 4. Partner Detection

Use existing Partner model:

```dart
final partner = StorageService().getPartner();
if (partner == null) {
  // Show "Pair with partner first" screen
  return;
}
```

---

## 📊 Success Metrics

### Engagement Metrics
- **Daily Active Users (DAU):** % of paired users who open Memory Flip daily
- **Completion Rate:** % of puzzles completed vs. started
- **Average Days to Complete:** Track if puzzles are too easy/hard
- **Flips Per Day:** Average flips used (target: 3-4 out of 5)

### Retention Metrics
- **7-Day Retention:** Do users return to complete puzzles?
- **Partner Engagement:** Do both partners play, or just one?
- **Drop-off Points:** Where do users abandon puzzles?

### Social Metrics
- **Match Notifications Click-Through:** % who tap notification to see match
- **Quote Shares:** (Future) Users sharing completion quotes

---

## 🛡️ Security & Validation

### Server-Side Checks

**Cloud Function validation:**
```javascript
// functions/index.js - syncMemoryFlip
exports.syncMemoryFlip = functions.https.onCall(async (request) => {
  const { puzzleId, cardId, userId, action } = request.data;

  // 1. Validate user is part of paired couple
  const user = await admin.firestore()
    .collection('users').doc(userId).get();
  if (!user.exists || !user.data().partnerId) {
    throw new functions.https.HttpsError('permission-denied', 'Not paired');
  }

  // 2. Check flip allowance (prevent cheating)
  const allowance = await getFlipAllowance(userId);
  if (allowance.flipsRemaining <= 0) {
    throw new functions.https.HttpsError('resource-exhausted', 'No flips left');
  }

  // 3. Validate card exists and is not already matched
  const card = await getCard(cardId);
  if (card.status === 'matched') {
    throw new functions.https.HttpsError('failed-precondition', 'Already matched');
  }

  // 4. Update state and return
  return await processFlip(puzzleId, cardId, userId);
});
```

### Client-Side Safeguards

```dart
// Prevent rapid tapping/double flips
bool _isFlipping = false;

Future<void> _onCardTap(MemoryCard card) async {
  if (_isFlipping) return;

  _isFlipping = true;
  try {
    await MemoryFlipService().flipCard(card.id, user.id);
  } finally {
    _isFlipping = false;
  }
}
```

---

## 🔮 Future Enhancements (Post-MVP)

### V2 Features
- **Custom Card Packs:** Upload your own photos as cards
- **Themed Puzzles:** Holiday, anniversary, date night themes
- **Difficulty Levels:** Easy (6 pairs), Medium (8), Hard (10)
- **Leaderboards:** Compare completion times with other couples
- **Achievements:** "Speed Matcher," "Perfect Memory," "Daily Streak"

### V3 Features
- **Multiplayer Tournaments:** Compete against other couples
- **Custom Quotes:** Write your own quotes for pairs
- **Video/GIF Cards:** Unlock mini video memories on match
- **Seasonal Events:** Special puzzles for Valentine's, anniversaries

---

## ✅ Definition of Done

Memory Flip is ready for production when:

- [ ] All Phase 1-4 tasks completed
- [ ] Unit test coverage >80%
- [ ] Integration tests pass on dual emulator setup
- [ ] Tested on 2 physical devices (iOS + Android)
- [ ] Push notifications working reliably
- [ ] No memory leaks in card grid rendering
- [ ] Puzzle generation produces variety (no duplicate emojis in same puzzle)
- [ ] Daily allowance reset working (cron or local timer)
- [ ] Cloud Function deployed and monitoring set up
- [ ] Love Points integration tested
- [ ] Onboarding tutorial created
- [ ] Documentation updated in CLAUDE.md

---

## 📞 Questions for Product Review

Before starting implementation:

1. **Puzzle Cadence:** Daily, weekly, or user-selected?
2. **Flip Allowance:** 4, 6, or 8 flips per day? (Must be even)
3. **Grid Size:** Start with 3×4 (6 pairs) or 4×4 (8 pairs)? **Recommended: 4×4**
4. **Content Tone:** More romantic vs. more playful quotes?
5. **Completion Reward:** Just Love Points, or unlock something special?
6. **Incomplete Puzzles:** Archive or delete when new one generates?
7. **Solo Play:** Allow playing without partner (vs. AI?) or require pairing?
8. **Odd Flip Handling:** Disable button or show warning when only 1 flip remains?

---

**End of Implementation Plan**

*This plan follows TogetherRemind's architecture (Flutter + Hive + Firebase) and integrates seamlessly with existing features like pokes, reminders, and Love Points.*
