# Magnet Collection System - Implementation Plan

> **Status:** In Progress - Phase 1 & 2 Complete
> **Created:** 2025-01-07
> **Parent Document:** `docs/plans/MAGNET_COLLECTION_SYSTEM.md`

This document covers the technical implementation phases for the Magnet Collection System. For design specs and UI details, see the parent document.

---

## Table of Contents

1. [Implementation Phases Overview](#implementation-phases-overview)
2. [Phase 1: Database & Backend](#phase-1-database--backend)
3. [Phase 2: Quiz Pack System](#phase-2-quiz-pack-system)
4. [Phase 3: Flutter UI](#phase-3-flutter-ui)
5. [Phase 4: Content Migration](#phase-4-content-migration)
6. [Phase 5: Testing & Rollout](#phase-5-testing--rollout)
7. [Critical UX Considerations](#critical-ux-considerations)
8. [Files Requiring Update](#files-requiring-update)
9. [Additional Notifications](#additional-notifications)
10. [Decisions Made](#decisions-made)
11. [Mockups Reference](#mockups-reference)

---

## Implementation Phases Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: Database & Backend                                            │
│  ├── Magnet configuration & LP requirements                             │
│  ├── Database schema (couple_magnets, cooldowns)                        │
│  ├── Magnet unlock detection & API endpoints                            │
│  └── 8-hour cooldown system                                             │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: Quiz Pack System                                              │
│  ├── Quiz-to-magnet association schema                                  │
│  ├── Quiz selection logic (from unlocked packs)                         │
│  ├── Daily quest generation updates                                     │
│  └── Linked & Word Search pack gating (if applicable)                   │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: Flutter UI                                                    │
│  ├── Connection Bar (magnet images replace tier emojis)                 │
│  ├── Collection View screen                                             │
│  ├── Profile Section magnet preview                                     │
│  ├── Unlock Celebration screen                                          │
│  └── Cooldown indicators on activity cards                              │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: Content Migration                                             │
│  ├── Organize existing quizzes into packs                               │
│  ├── Create magnet image assets (30 destinations)                       │
│  ├── Write additional quizzes to fill packs                             │
│  └── Associate quiz packs with magnets in database                      │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 5: Testing & Rollout                                             │
│  ├── Migration script for existing users                                │
│  ├── Feature flag for gradual rollout                                   │
│  ├── A/B testing (if needed)                                            │
│  └── Monitor engagement metrics                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Database & Backend

### 1.1 Database Schema

```sql
-- ============================================
-- MAGNET COLLECTION
-- ============================================

-- NO NEW TABLE NEEDED!
-- Magnets are calculated from couples.total_lp (already exists)
-- This is simpler and avoids sync issues

-- ============================================
-- COOLDOWN TRACKING
-- ============================================

ALTER TABLE couples ADD COLUMN IF NOT EXISTS cooldowns JSONB DEFAULT '{}';

-- Each activity type has SEPARATE cooldown (2 plays each before 8hr wait)
-- Example:
-- {
--   "classic_quiz": { "batch_count": 2, "cooldown_until": "2025-01-07T18:00:00Z" },
--   "affirmation_quiz": { "batch_count": 1, "cooldown_until": null },
--   "you_or_me": { "batch_count": 0, "cooldown_until": null },
--   "linked": { "batch_count": 2, "cooldown_until": "2025-01-07T18:00:00Z" },
--   "wordsearch": { "batch_count": 1, "cooldown_until": null }
-- }
```

**Why no magnets table?** Magnet unlocks are deterministic from LP:
- 600 LP → Magnet 1
- 1300 LP → Magnet 2 (600+700)
- etc.

We calculate on-the-fly from `couples.total_lp`. One source of truth, no sync issues.

### 1.2 Magnet Configuration

```typescript
// api/lib/magnets/config.ts

export interface Magnet {
  id: number;
  name: string;
  theme: string;
  region: 'local' | 'us' | 'europe';
  assetPath: string;  // e.g., 'austin.jpg'
}

export const MAGNETS: Magnet[] = [
  // Local (1-7)
  { id: 1, name: 'Coffee Shop', theme: 'First date vibes', region: 'local', assetPath: 'coffee-shop.jpg' },
  { id: 2, name: 'City Park', theme: 'Picnic together', region: 'local', assetPath: 'city-park.jpg' },
  { id: 3, name: 'Rooftop Bar', theme: 'City night', region: 'local', assetPath: 'rooftop.jpg' },
  { id: 4, name: 'Beach Town', theme: 'Weekend getaway', region: 'local', assetPath: 'beach-town.jpg' },
  { id: 5, name: 'Mountain Cabin', theme: 'Cozy escape', region: 'local', assetPath: 'cabin.jpg' },
  { id: 6, name: 'Vineyard', theme: 'Wine country', region: 'local', assetPath: 'vineyard.jpg' },
  { id: 7, name: 'Lake House', theme: 'Peaceful retreat', region: 'local', assetPath: 'lake-house.jpg' },

  // US Cities (8-18)
  { id: 8, name: 'Austin', theme: 'Music & BBQ', region: 'us', assetPath: 'austin.jpg' },
  { id: 9, name: 'Los Angeles', theme: 'Hollywood dreams', region: 'us', assetPath: 'los_angeles.jpg' },
  { id: 10, name: 'San Francisco', theme: 'Golden Gate', region: 'us', assetPath: 'san_francisco.jpg' },
  { id: 11, name: 'Chicago', theme: 'Windy city', region: 'us', assetPath: 'chicago.jpg' },
  { id: 12, name: 'Miami', theme: 'Tropical heat', region: 'us', assetPath: 'miami.jpg' },
  { id: 13, name: 'New Orleans', theme: 'Jazz & beignets', region: 'us', assetPath: 'new_orleans.jpg' },
  { id: 14, name: 'New York', theme: 'Big city dreams', region: 'us', assetPath: 'new_york.jpg' },

  // Europe (15-30)
  { id: 15, name: 'London', theme: 'British charm', region: 'europe', assetPath: 'london.jpg' },
  { id: 16, name: 'Paris', theme: 'City of love', region: 'europe', assetPath: 'paris.png' },
  { id: 17, name: 'Amsterdam', theme: 'Canals & culture', region: 'europe', assetPath: 'amsterdam.jpg' },
  { id: 18, name: 'Berlin', theme: 'History & nightlife', region: 'europe', assetPath: 'berlin.jpg' },
  { id: 19, name: 'Barcelona', theme: 'Mediterranean sun', region: 'europe', assetPath: 'barcelona.jpg' },
  { id: 20, name: 'Naples', theme: 'Italian coast', region: 'europe', assetPath: 'naples.png' },
  { id: 21, name: 'Copenhagen', theme: 'Nordic design', region: 'europe', assetPath: 'copenhagen.jpg' },
  { id: 22, name: 'Stockholm', theme: 'Scandinavian beauty', region: 'europe', assetPath: 'stockholm.jpg' },
  { id: 23, name: 'Reykjavik', theme: 'Northern lights', region: 'europe', assetPath: 'reykjavik.jpg' },
  { id: 24, name: 'Rome', theme: 'Ancient romance', region: 'europe', assetPath: 'rome.jpg' },
  { id: 25, name: 'Vienna', theme: 'Classical elegance', region: 'europe', assetPath: 'vienna.jpg' },
  { id: 26, name: 'Prague', theme: 'Fairytale city', region: 'europe', assetPath: 'prague.jpg' },
  { id: 27, name: 'Lisbon', theme: 'Coastal beauty', region: 'europe', assetPath: 'lisbon.jpg' },
  { id: 28, name: 'Athens', theme: 'Ancient history', region: 'europe', assetPath: 'athens.jpg' },
  { id: 29, name: 'Santorini', theme: 'White & blue', region: 'europe', assetPath: 'santorini.jpg' },
  { id: 30, name: 'Dubrovnik', theme: 'Adriatic gem', region: 'europe', assetPath: 'dubrovnik.jpg' },
];

// LP requirements (progressive)
export function getLPRequirement(magnetId: number): number {
  if (magnetId <= 3) return 600;
  if (magnetId <= 6) return 700;
  if (magnetId <= 9) return 800;
  if (magnetId <= 14) return 900;
  return 1000;
}

// Total LP needed to unlock magnet N
export function getTotalLPForMagnet(magnetId: number): number {
  let total = 0;
  for (let i = 1; i <= magnetId; i++) {
    total += getLPRequirement(i);
  }
  return total;
}

// Get magnet that should be unlocked at given LP
export function getMagnetForLP(totalLp: number): number {
  let accumulated = 0;
  for (let i = 1; i <= 30; i++) {
    accumulated += getLPRequirement(i);
    if (totalLp < accumulated) {
      return i - 1;  // Return last fully unlocked magnet
    }
  }
  return 30;  // All unlocked
}
```

### 1.3 API Endpoints

```typescript
// api/app/api/magnets/route.ts
// GET: Fetch couple's magnet collection status
// All calculated from couples.total_lp - no magnets table query

interface MagnetCollectionResponse {
  unlockedCount: number;       // 4 (calculated from LP)
  nextMagnetId: number;        // 5 (next to unlock)
  currentLp: number;           // 2460
  lpForNextMagnet: number;     // 2800 (threshold for magnet 5)
  progressPercent: number;     // 0.65
  totalMagnets: number;        // 30
}

// Unlock detection happens client-side or in LP award endpoint
// Compare magnet count before/after LP change:

function detectUnlock(oldLp: number, newLp: number): number | null {
  const magnetsBefore = getUnlockedMagnetCount(oldLp);
  const magnetsAfter = getUnlockedMagnetCount(newLp);
  if (magnetsAfter > magnetsBefore) {
    return magnetsAfter;  // Return newly unlocked magnet ID
  }
  return null;
}
```

### 1.4 Cooldown System

```typescript
// api/lib/cooldowns/service.ts

const BATCH_SIZE = 2;  // 2 plays per activity type per batch
const COOLDOWN_HOURS = 8;

export interface CooldownStatus {
  canPlay: boolean;
  remainingInBatch: number;  // 0, 1, or 2
  cooldownEndsAt: Date | null;
  cooldownRemainingMs: number | null;
}

type ActivityType = 'classic_quiz' | 'affirmation_quiz' | 'you_or_me' | 'linked' | 'wordsearch';

export async function getCooldownStatus(
  coupleId: string,
  activityType: ActivityType
): Promise<CooldownStatus> {
  // 1. Fetch cooldown record for couple + activity
  // 2. If cooldown_until is in future, return canPlay: false
  // 3. If cooldown expired, reset batch_count to 0
  // 4. Return remaining plays in batch
}

export async function recordActivityPlay(
  coupleId: string,
  activityType: ActivityType
): Promise<{ cooldownStarted: boolean; cooldownEndsAt: Date | null }> {
  // 1. Increment batch_count
  // 2. If batch_count reaches BATCH_SIZE, set cooldown_until = now + 8 hours
  // 3. Return whether cooldown started
}
```

### 1.5 Phase 1 Testing Tasks

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Schema migration** | Run migration on test DB | Tables created, indexes exist |
| **LP calculation** | Test `getLPRequirement()` | Returns 600 for magnets 1-3, 700 for 4-6, etc. |
| **Magnet unlock detection** | Award LP to cross threshold | `couple_magnets` record created |
| **Multiple unlocks** | Award large LP amount | Multiple magnets unlock in sequence |
| **GET /magnets** | Fetch magnet collection | Returns correct `unlockedMagnets`, `progressPercent` |
| **POST /magnets/unlock** | Check unlock after LP | Returns `newUnlock: true` with magnet details |
| **Cooldown start** | Play 2 quizzes | `cooldown_until` set to +8 hours |
| **Cooldown check** | Check status during cooldown | `canPlay: false`, correct `remainingMs` |
| **Cooldown reset** | Wait for cooldown to expire | `batch_count` resets, `canPlay: true` |
| **Concurrent plays** | Two devices play simultaneously | No double-counting, cooldown triggers correctly |

---

## Phase 2: Quiz Pack System

### 2.1 Quiz-to-Magnet Association

**Decision:** No theming - quizzes are assigned arbitrarily to packs. Use JSON field approach (simplest).

```json
// Each quiz file gets a magnet_id field
// magnet_id: 0 or null = starter quiz (before first magnet)
// magnet_id: 1-30 = unlocked with that magnet
{
  "quizId": "quiz_006",
  "title": "Celebrating Each Other",
  "branch": "lighthearted",
  "magnet_id": 1,
  "questions": [...]
}
```

**Starter quizzes:** `magnet_id: 0` or `magnet_id: null` - available to new users before any magnet is unlocked.

### 2.2 Quiz Selection Logic

```typescript
// api/lib/quests/quiz-selector.ts

export async function getAvailableQuizzes(
  coupleId: string,
  quizType: 'classic' | 'affirmation' | 'you_or_me'
): Promise<string[]> {
  // 1. Get couple's unlocked magnets
  const unlockedMagnets = await getUnlockedMagnets(coupleId);

  // 2. Get all quizzes associated with those magnets
  const availableQuizIds = await getQuizzesByMagnets(quizType, unlockedMagnets);

  // 3. Filter out already-completed quizzes (optional: allow replay)
  const completedQuizIds = await getCompletedQuizzes(coupleId, quizType);

  return availableQuizIds.filter(id => !completedQuizIds.includes(id));
}

export async function selectDailyQuiz(
  coupleId: string,
  quizType: 'classic' | 'affirmation' | 'you_or_me'
): Promise<string> {
  const available = await getAvailableQuizzes(coupleId, quizType);

  if (available.length === 0) {
    // All quizzes completed - allow replay from most recent magnet pack
    return selectReplayQuiz(coupleId, quizType);
  }

  // Use existing quiz selection logic - no changes needed
  return existingSelectionLogic(available, coupleId, quizType);
}
```

### 2.3 Daily Quest Generation Updates

Current system: `lib/services/quest_type_manager.dart` generates 3 daily quests.

**Changes needed:**

```dart
// lib/services/quest_type_manager.dart

Future<List<DailyQuest>> generateDailyQuests(String coupleId) async {
  // 1. Check cooldown status for quiz activity
  final cooldownStatus = await _cooldownService.getStatus(coupleId, 'quiz');

  // 2. Get unlocked magnets
  final unlockedMagnets = await _magnetService.getUnlockedMagnets(coupleId);

  // 3. Get available quizzes from unlocked packs
  final classicQuizzes = await _getAvailableQuizzes('classic', unlockedMagnets);
  final affirmationQuizzes = await _getAvailableQuizzes('affirmation', unlockedMagnets);
  final youOrMeQuizzes = await _getAvailableQuizzes('you_or_me', unlockedMagnets);

  // 4. Select quizzes for today
  return [
    DailyQuest(
      slot: 0,
      type: 'classic',
      contentId: _selectQuiz(classicQuizzes),
      isLocked: !cooldownStatus.canPlay,
      cooldownEndsAt: cooldownStatus.cooldownEndsAt,
    ),
    // ... affirmation, you_or_me
  ];
}
```

### 2.4 Linked & Word Search Gating

**Decision:** Not gated by magnets (for now).

- Linked and Word Search have their own progression (branch rotation)
- Only cooldowns apply, not magnet unlocks
- All puzzles available from start
- Can add magnet gating as a future enhancement

### 2.5 Phase 2 Testing Tasks

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Quiz assignment** | Verify quiz-to-magnet mapping | Each quiz has valid `magnet_id` |
| **Available quizzes** | New user with 1 magnet | Only pack 1 quizzes returned (6 per type) |
| **After unlock** | User unlocks magnet 2 | Pack 2 quizzes now available |
| **Completed filtering** | User finishes quiz_001 | Not returned in available list |
| **Empty pack** | User completes all unlocked quizzes | Returns empty array, triggers exhausted modal |
| **Daily quest selection** | Generate daily quests | Selects from unlocked packs only |
| **Replay mode** | All quizzes done, `allowReplay: true` | Quizzes available again for replay |
| **Pack boundaries** | Verify 6 quizzes per magnet per type | 18 total per magnet (6 classic + 6 affirmation + 6 you-or-me) |
| **Cooldown integration** | Quiz on cooldown | Quest card shows locked state |

---

## Phase 3: Flutter UI

### 3.1 File Changes Summary

| File | Changes |
|------|---------|
| `lib/widgets/brand/us2/us2_connection_bar.dart` | Replace tier emojis with magnet images |
| `lib/screens/magnet_collection_screen.dart` | **NEW** - Collection View |
| `lib/screens/magnet_unlock_screen.dart` | **NEW** - Unlock Celebration |
| `lib/widgets/brand/us2/us2_profile_magnets.dart` | **NEW** - Profile section widget |
| `lib/widgets/quizzes_exhausted_modal.dart` | **NEW** - Modal when all quizzes completed |
| `lib/services/magnet_service.dart` | **NEW** - Magnet data & sync |
| `lib/services/cooldown_service.dart` | **NEW** - Cooldown tracking |
| `lib/models/magnet.dart` | **NEW** - Magnet model |
| `lib/models/magnet.g.dart` | **NEW** - Hive adapter |

### 3.2 Connection Bar Updates

**Mockup:** `mockups/magnet-collection/collection-view.html` → "Connection Bar (Mid-Progress)" and "Connection Bar (New User)"

```dart
// lib/widgets/brand/us2/us2_connection_bar.dart

class Us2ConnectionBar extends StatelessWidget {
  final int currentLp;
  final int nextMagnetLp;
  final Magnet? currentMagnet;  // null for new users
  final Magnet nextMagnet;

  // Replace _TierEndpoint with _MagnetEndpoint
  Widget _buildMagnetEndpoint(Magnet magnet, {bool isNext = false}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/brands/us2/images/magnets/${magnet.assetPath}',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
```

### 3.3 New Screens

**Mockups:** `mockups/magnet-collection/collection-view.html` → "Collection View", "Profile Section", "Unlock Celebration"

```dart
// lib/screens/magnet_collection_screen.dart

class MagnetCollectionScreen extends StatefulWidget {
  final int? highlightMagnetId;  // For post-unlock highlight

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: Us2Theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressSection(),
              Expanded(
                child: _buildMagnetGrid(),  // Polaroid style
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/screens/magnet_unlock_screen.dart

class MagnetUnlockScreen extends StatefulWidget {
  final Magnet unlockedMagnet;

  @override
  void initState() {
    super.initState();
    // Trigger confetti on load
    _confettiController.play();
  }

  void _onAddToCollection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MagnetCollectionScreen(
          highlightMagnetId: widget.unlockedMagnet.id,
        ),
      ),
    );
  }
}
```

### 3.4 Confetti Implementation

```dart
// Using confetti package (pub.dev/packages/confetti)
// pubspec.yaml: confetti: ^0.7.0

import 'package:confetti/confetti.dart';

class _MagnetUnlockScreenState extends State<MagnetUnlockScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Start confetti after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        _buildContent(),

        // Confetti overlay - aligned to top center, falls down
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,  // Downward
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.2,
            colors: const [
              Color(0xFFFF6B6B),  // Pink
              Color(0xFFFFE066),  // Gold
              Color(0xFFFF9F43),  // Orange
              Color(0xFFFFB347),  // Amber
            ],
          ),
        ),
      ],
    );
  }
}
```

### 3.5 Cooldown Indicators

**Note:** Each activity type has its own cooldown. When one quiz type is on cooldown, others may still be available.

```dart
// lib/widgets/quest_card.dart - Add cooldown overlay

Widget _buildCooldownOverlay(Duration remaining) {
  return Container(
    color: Colors.black.withOpacity(0.5),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.white, size: 32),
          SizedBox(height: 8),
          Text(
            'Back in ${_formatDuration(remaining)}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Try other activities to earn LP',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
```

**Overlay behavior:**
- Shows only on the specific activity that's on cooldown
- Generic message - doesn't list other activities by name
- User naturally sees other quest cards are still playable

**IMPORTANT: Cooldown timing**
- Cooldown overlay only shows AFTER user has reviewed results of their 2nd play
- Flow: Play 1 → Results → Home (no overlay) → Play 2 → Results → Home (overlay shows)
- Until results are viewed, show normal quest card or "Waiting for partner" state
- Cooldown timer starts when 2nd game is completed, not when results are viewed

**Mockup:** `mockups/magnet-collection/quiz-cooldown.html`

### 3.6 Quizzes Exhausted Modal

**Trigger:** User taps a quiz quest when they've completed all available quizzes from their unlocked magnet packs.

**Mockup:** `mockups/magnet-collection/quizzes-exhausted.html` (Variant B)

```dart
// lib/widgets/quizzes_exhausted_modal.dart

class QuizzesExhaustedModal extends StatelessWidget {
  final Magnet nextMagnet;
  final int currentLp;
  final int lpRequired;

  void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = currentLp / lpRequired;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge
            _buildBadge('All Done!'),
            const SizedBox(height: 12),

            // Title
            Text(
              "You've Completed All Quizzes",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              'Unlock your next magnet to get 18 fresh quizzes to explore together.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Next Destination Card
            _buildNextDestinationCard(nextMagnet, progress, currentLp, lpRequired),
            const SizedBox(height: 20),

            // OK Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextDestinationCard(Magnet magnet, double progress, int current, int required) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'NEXT DESTINATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Magnet preview
          Row(
            children: [
              // Magnet image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/brands/us2/images/magnets/${magnet.assetPath}',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                magnet.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE0E0E0),
            ),
          ),
          const SizedBox(height: 6),

          // LP text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current LP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6B6B),
                ),
              ),
              Text(
                '$required LP',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hint
          Text(
            'Try other activities to earn LP',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Usage in quest card:**

```dart
// lib/widgets/quest_card.dart

void _onQuestTap() async {
  // Check if user has available quizzes
  final hasQuizzes = await _magnetService.hasAvailableQuizzes(quizType);

  if (!hasQuizzes) {
    // Show exhausted modal instead of navigating to quiz
    final nextMagnet = await _magnetService.getNextMagnet();
    final progress = await _magnetService.getMagnetProgress();

    QuizzesExhaustedModal(
      nextMagnet: nextMagnet,
      currentLp: progress.currentLp,
      lpRequired: progress.lpRequired,
    ).show(context);
    return;
  }

  // Normal quiz navigation...
}
```

### 3.7 Phase 3 Testing Tasks

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Connection Bar** | Verify magnets display correctly | Previous/next magnet images show, progress bar fills |
| **New user state** | New user with 0 magnets | Heart at far left, first magnet on right |
| **Collection View** | Tap to open collection | Grid shows all 30 magnets, locked ones dimmed |
| **Polaroid styling** | Verify magnet card style | White frame, shadow, 4px border-radius |
| **Profile magnets** | 6 badges in profile section | Shows collected + locked badges, arrows navigate |
| **Unlock celebration** | Trigger magnet unlock | Confetti falls from top, magnet displays, "Add to Collection" works |
| **Exhausted modal** | Complete all available quizzes | Modal shows next magnet, progress, LP hint |
| **Modal dismissal** | Tap "OK" on modal | Modal closes, stays on home screen |
| **Cooldown indicator** | Hit 2-play limit | Timer overlay shows on quest card |

---

## Phase 4: Content Migration

### 4.1 Quiz Organization

**Current structure:**
```
api/data/puzzles/
├── classic-quiz/
│   ├── lighthearted/
│   │   ├── quiz_001.json
│   │   ├── quiz_002.json
│   │   └── ...
│   └── playful/
├── affirmation/
└── you-or-me/
```

**New structure (Option A - by magnet):**
```
api/data/puzzles/
├── classic-quiz/
│   ├── pack_01/  # Magnet 1: Coffee Shop
│   │   ├── quiz_001.json
│   │   ├── quiz_002.json
│   │   └── ... (6 quizzes)
│   ├── pack_02/  # Magnet 2: City Park
│   └── ...
```

**New structure (Option B - metadata mapping):**
```
// Keep existing structure, add magnet_id to each quiz JSON
{
  "quizId": "quiz_006",
  "title": "Celebrating Each Other",
  "branch": "lighthearted",
  "magnet_id": 1,  // NEW: Associated with Coffee Shop magnet
  "questions": [...]
}
```

### 4.2 Content Requirements

| Pack | Classic | Affirmation | You or Me | Total |
|------|---------|-------------|-----------|-------|
| Starter (no magnet) | 6 | 6 | 6 | 18 |
| Magnets 1-30 | 6 each | 6 each | 6 each | 18 each |
| **Total** | **186** | **186** | **186** | **558** |

**Current inventory:** ~50 quizzes (need ~508 more)

**Note:** Starter quizzes are played before any magnet is unlocked. They have `magnet_id: 0` or `magnet_id: null` to indicate they're not tied to a specific destination.

### 4.3 Magnet Asset Creation

**Tool:** AI image generation (DALL-E, Midjourney) or commission illustrator

**Prompt template:**
```
Flat illustrated travel poster for [DESTINATION], minimalist style,
warm colors, destination name "[NAME]" integrated into design,
square aspect ratio, suitable for app icon display
```

**Asset location:** `mockups/magnet-collection/magnets/`

**Asset checklist (16/30 complete):**

*Local (0/7):*
- [ ] Coffee Shop
- [ ] City Park
- [ ] Rooftop Bar
- [ ] Beach Town
- [ ] Mountain Cabin
- [ ] Vineyard
- [ ] Lake House

*US Cities (7/7 complete):*
- [x] Austin (`austin.jpg`)
- [x] Los Angeles (`los_angeles.jpg`)
- [x] San Francisco (`san_francisco.jpg`)
- [x] Chicago (`chicago.jpg`)
- [x] Miami (`miami.jpg`)
- [x] New Orleans (`new_orleans.jpg`)
- [x] New York (`new_york.jpg`)

*Europe (9/16):*
- [x] London (`london.jpg`)
- [x] Paris (`paris.png`)
- [x] Amsterdam (`amsterdam.jpg`)
- [x] Berlin (`berlin.jpg`)
- [x] Barcelona (`barcelona.jpg`)
- [x] Naples (`naples.png`)
- [x] Copenhagen (`copenhagen.jpg`)
- [x] Stockholm (`stockholm.jpg`)
- [x] Reykjavik (`reykjavik.jpg`)
- [ ] Rome
- [ ] Vienna
- [ ] Prague
- [ ] Lisbon
- [ ] Athens
- [ ] Santorini
- [ ] Dubrovnik

### 4.4 Phase 4 Testing Tasks

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Quiz count** | Verify quiz inventory | At least 6 quizzes per type per magnet (540 total) |
| **JSON validation** | Validate all quiz files | No JSON syntax errors, required fields present |
| **Magnet ID assignment** | Check `magnet_id` on each quiz | All quizzes have valid magnet_id 1-30 |
| **Asset loading** | Load each magnet image | All 30 images load without error |
| **Asset dimensions** | Check image sizes | All images are square, min 200x200px |
| **Branch distribution** | Quizzes per branch | Balanced distribution across lighthearted/playful/etc. |
| **Question quality** | Review quiz content | No duplicates, appropriate difficulty |
| **Pack completeness** | Each magnet has full pack | 18 quizzes assigned to each magnet |

---

## Phase 5: Testing & Rollout

### 5.1 Migration for Existing Users

**No migration script needed for magnets!**

Since magnets are calculated from `couples.total_lp` (which already exists), existing users automatically have the correct magnet count when we deploy. No data migration required.

**Only database change:**
```sql
-- Add cooldowns column (safe, has default)
ALTER TABLE couples ADD COLUMN IF NOT EXISTS cooldowns JSONB DEFAULT '{}';
```

Existing users start with empty cooldowns = all activities available.

### 5.2 Feature Flag

```typescript
// api/lib/feature-flags.ts

export const FEATURE_FLAGS = {
  MAGNET_SYSTEM_ENABLED: process.env.MAGNET_SYSTEM_ENABLED === 'true',
  COOLDOWN_SYSTEM_ENABLED: process.env.COOLDOWN_SYSTEM_ENABLED === 'true',
};

// Usage in endpoints
if (FEATURE_FLAGS.MAGNET_SYSTEM_ENABLED) {
  // New magnet logic
} else {
  // Legacy tier logic
}
```

### 5.3 Rollout Phases

| Phase | Audience | Duration | Success Criteria |
|-------|----------|----------|------------------|
| Alpha | Internal team | 1 week | No crashes, flows work |
| Beta | 10% of users | 2 weeks | Engagement stable, no major bugs |
| GA | 100% of users | - | - |

### 5.4 Metrics to Monitor

- Daily active users (DAU) - should not drop
- Quiz completion rate - should stay stable or increase
- Average LP earned per day - monitor for gaming
- Magnet unlock events per day
- Cooldown hit rate (how often users hit cooldowns)
- Collection View screen visits

### 5.5 Phase 5 Testing Tasks

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| **Migration - new user** | User with 0 LP | 0 magnets unlocked |
| **Migration - mid user** | User with 1500 LP | Correct magnets unlocked (based on thresholds) |
| **Migration - power user** | User with 10000+ LP | All earned magnets unlocked |
| **Migration idempotency** | Run migration twice | No duplicate records |
| **Feature flag off** | `MAGNET_SYSTEM_ENABLED=false` | Legacy tier system works |
| **Feature flag on** | `MAGNET_SYSTEM_ENABLED=true` | Magnet system active |
| **Flag toggle mid-session** | Toggle flag | No crashes, graceful transition |
| **E2E: New user flow** | Fresh signup through magnet unlock | Full flow works |
| **E2E: Couple sync** | Both partners view collection | Same magnets shown |
| **E2E: Exhausted → unlock** | Complete quizzes, earn LP, unlock | Modal appears, then celebration |
| **Performance: Grid load** | Open collection with 30 magnets | Loads in < 1 second |
| **Performance: API response** | GET /magnets endpoint | Response in < 200ms |
| **Rollback test** | Disable feature flag after use | Users see legacy UI, no data loss |

### 5.6 Test Script: reset_two_test_couples.ts

**File:** `api/scripts/reset_two_test_couples.ts`

Modify existing test script to create two couples at different magnet stages:

| Couple | Users | LP | Magnets | Use Case |
|--------|-------|-----|---------|----------|
| **Couple 1** | Pertsa & Kilu | 450 | 0 (starter phase) | Testing starter quizzes, first magnet progress bar |
| **Couple 2** | Bob & Alice | 2500 | 3 unlocked, working on 4th | Testing collection view, cooldowns, mid-game state |

**LP Thresholds for Reference:**
- 600 LP → Magnet 1
- 1300 LP → Magnet 2 (cumulative)
- 2100 LP → Magnet 3 (cumulative)
- 3000 LP → Magnet 4 (cumulative)

**Test Scenarios:**

| Test | Login As | Expected |
|------|----------|----------|
| **Starter phase UI** | Pertsa | No magnets in collection, progress bar shows 450/600 (75%) |
| **First unlock flow** | Pertsa | Complete quiz → earn LP → hit 600 → unlock celebration for Magnet 1 |
| **Collection with magnets** | Bob | 3 magnets unlocked, shows progress toward Magnet 4 (2500-2100=400/900 = 44%) |
| **Cooldown testing** | Bob | Play 2 quizzes → cooldown overlay appears → "Back in 8h" |
| **Different quiz pools** | Compare | Pertsa sees starter quizzes, Bob sees Magnet 1-3 quizzes |

**Usage:**
```bash
cd api && npx tsx scripts/reset_two_test_couples.ts
```

---

## Critical UX Considerations

### New User First Magnet

**Problem:** If quizzes are gated by magnets, and magnets require LP, how do new users earn their first LP?

**Solution: Starter Quizzes (No Free Magnet)**

New users with 0 magnets get access to 18 "starter quizzes" (6 classic + 6 affirmation + 6 you-or-me) that are NOT tied to any magnet. These let them:
1. Play quizzes immediately after onboarding
2. Earn LP toward their FIRST magnet (600 LP needed)
3. Experience the unlock celebration when they earn Magnet 1
4. Get 18 NEW quizzes with each magnet unlock

**Quiz selection logic:**
```typescript
if (unlockedMagnets.length === 0) {
  // Return starter quizzes (not associated with any magnet)
  return getStarterQuizzes(quizType);
} else {
  // Return quizzes from unlocked magnet packs
  return getQuizzesByMagnets(quizType, unlockedMagnets);
}
```

**Benefits:**
- First magnet feels EARNED (not given free)
- Clear progression: Starter → Magnet 1 → Magnet 2 → ...
- Welcome Quiz 30 LP contributes toward first magnet
- More rewarding unlock experience

**Connection Bar (New User State):**
- No magnet on the left (user hasn't collected any yet)
- Heart indicator starts at far left
- First magnet (Coffee Shop) shown on right as the goal
- See mockup: `mockups/magnet-collection/collection-view.html` → "Connection Bar (New User)"

### Welcome Quiz Integration

**Current flow:** Pairing → Welcome Quiz (30 LP) → Features unlock

**Decision:** Welcome Quiz is separate from magnet packs, but its 30 LP contributes toward the first magnet.

- Welcome Quiz has special onboarding UI/flow (distinct from regular quizzes)
- The 30 LP awarded goes toward Magnet 1 (600 LP threshold)
- After Welcome Quiz, user has 30 LP → 570 LP remaining for first magnet
- User continues with "starter quizzes" until they hit 600 LP and unlock Magnet 1

### All 30 Magnets Collected State

**What happens when user collects ALL magnets?**

**Connection Bar:**
- Last collected magnet (Dubrovnik) shown on the LEFT (current position)
- No magnet on the RIGHT (there's no next magnet to unlock)
- Progress bar shows LP accumulating toward future magnets
- Heart indicator at far right (or special "complete" state)

**Collection View:**
- Shows all 30 magnets unlocked
- Banner/message at top: *"You've collected all the magnets! New destinations are coming soon and your LPs will contribute towards these."*
- LP counter continues to show total accumulated

**Profile Section:**
- All 6 badges filled with most recent magnets
- Special glow or "Complete" indicator

**What happens when user completes ALL 540 quizzes?**

- Exhausted modal shows: "You've explored every quiz! New content is coming soon."
- Enable replay mode so users always have something to play
- LP earned from replays still counts toward future magnets

### Partner Quiz Completion Tracking

**Clarification needed:** When Partner A completes a quiz, can Partner B still play it?

**Current system:** Both partners answer the same quiz independently, then compare results.

**Recommendation:** Keep current behavior - quiz completion is per-couple (both play same quiz), not per-individual.

### Steps Together LP Integration

**Verify:** Steps Together awards 15-30 LP per claim. This should:
1. Contribute to magnet progress (already does via `couples.total_lp`)
2. Trigger magnet unlock check after LP award
3. **NOT** be affected by cooldowns (Steps is separate system)

**No cooldown on Steps** - Users can claim step rewards whenever they hit milestones.

### LP Sources Summary

| Activity | LP | Cooldown | Gated by Magnets |
|----------|-----|----------|------------------|
| Classic Quiz | 30 | 2 plays / 8hr (separate) | Yes |
| Affirmation Quiz | 30 | 2 plays / 8hr (separate) | Yes |
| You or Me | 30 | 2 plays / 8hr (separate) | Yes |
| Linked | 30 | 2 plays / 8hr (separate) | No (future) |
| Word Search | 30 | 2 plays / 8hr (separate) | No (future) |
| Steps Together | 15-30 | None | No |
| Welcome Quiz | 30 | One-time | N/A (onboarding) |

**Note:** Each activity has its own independent cooldown. User can play up to 2 of each type per 8-hour window = max 10 activities (300 LP) + Steps.

---

## Files Requiring Update

Beyond the new files in Phase 3, these existing files reference tier/arena and need updates:

### Must Replace/Remove

| File | Action | Notes |
|------|--------|-------|
| `lib/services/arena_service.dart` | Replace with `magnet_service.dart` | Core service change |
| `lib/models/arena.dart` | Replace with `magnet.dart` | Model change |
| `lib/widgets/brand/us2/us2_tier_emoji.dart` | Remove | No longer needed |

### Must Update

| File | Changes Needed |
|------|----------------|
| `lib/screens/profile_screen.dart` | Replace tier display with magnet count/preview |
| `lib/widgets/brand/us2/us2_connection_bar.dart` | Tier emojis → magnet images (in plan) |
| `lib/widgets/brand/us2/us2_home_content.dart` | Remove tier references if any |
| `lib/widgets/brand/brand_widget_factory.dart` | Update tier widget creation |
| `lib/widgets/lp_intro_overlay.dart` | Update tier messaging to magnets |
| `lib/widgets/leaderboard_bottom_sheet.dart` | Update tier display |
| `lib/services/love_point_service.dart` | Add magnet unlock check trigger |
| `lib/services/dev_data_service.dart` | Update mock data for magnets |
| `lib/services/mock_data_service.dart` | Update mock data for magnets |
| `lib/widgets/debug/tabs/lp_sync_tab.dart` | Add magnet debug info |

### Debug Menu Additions

Add to debug menu (`lib/widgets/debug/`):
- "Reset magnets" - Clear all couple_magnets records
- "Grant magnet X" - Manually unlock specific magnet
- "Grant all magnets" - Unlock all 30 for testing
- "Reset cooldowns" - Clear all cooldown timers
- View current magnet status

---

## Additional Notifications

### Cooldown End Push Notification (Optional)

When 8-hour cooldown ends, send push notification:
- Title: "Ready for more!"
- Body: "Your quizzes are waiting. Jump back in and keep exploring together!"

**Implementation:** Schedule local notification when cooldown starts.

### Magnet Progress in LP Banner (Optional)

Current: "+30 LP" banner on home screen.

Enhanced: "+30 LP • 180 to next magnet" or small magnet icon with progress ring.

---

## Decisions Made

### 1. Quiz Theming

**Decision: No theming (Option B)**

Quizzes are assigned to packs without destination-specific content. Any quiz can go in any pack. This keeps content flexible and easy to organize.

Track completion counts per quiz type (classic, affirmation, you-or-me) to manage progression.

---

### 2. Quiz Selection Strategy

**Decision: Use existing system**

Keep the current quiz selection system as-is. The magnet system only adds a filter layer:
- Filter available quizzes based on unlocked magnets (+ starter pack if no magnets)
- Let existing selection logic pick from filtered pool
- No changes to how quizzes are chosen, just which ones are available

---

### 3. Linked & Word Search Gating

**Decision: Not gated (for now)**

All puzzles available from start, only cooldowns apply. Puzzle gating by magnets can be added as a future enhancement.

---

### 4. Empty Pack Handling

**Decision: Show exhausted modal + allow replay**

When user completes all available quizzes:
1. Show "All Done!" modal with next magnet progress
2. Allow replay of completed quizzes
3. LP from replays still counts toward next magnet

---

## Mockups Reference

All mockups are in `mockups/magnet-collection/`:

| File | Contains |
|------|----------|
| `collection-view.html` | Collection View grid (Polaroid style), Connection Bar (Mid-Progress), Connection Bar (New User), Profile Section (6 badges), Unlock Celebration (confetti) |
| `quizzes-exhausted.html` | Modal when all quizzes completed - shows next magnet progress |
| `quiz-cooldown.html` | Cooldown overlay on quest cards - shows timer and hint |
| `magnets/` | Magnet image assets (16/30 complete) |

---

## Related Documents

- `docs/plans/MAGNET_COLLECTION_SYSTEM.md` - Design & UI specifications
- `docs/features/LOVE_POINTS.md` - Current LP system
- `docs/features/DAILY_QUESTS.md` - Quest generation system

---

## Changelog

| Date | Change |
|------|--------|
| 2025-01-07 | Initial implementation plan created |
| 2025-01-07 | Added Quizzes Exhausted Modal (Section 3.6) with Dart implementation |
| 2025-01-07 | Added testing tasks for all 5 phases |
| 2025-01-07 | Updated magnet list with available assets (16/30), correct file extensions |
| 2025-01-07 | Added Critical UX Considerations (new user first magnet, endgame states) |
| 2025-01-07 | Added Files Requiring Update (tier/arena system replacement) |
| 2025-01-07 | Added Additional Notifications (cooldown end, LP banner enhancement) |
| 2025-01-07 | Updated: Starter quizzes (18) for new users, no free magnet - first magnet is earned |
| 2025-01-07 | Updated: Welcome Quiz 30 LP contributes toward first magnet |
| 2025-01-07 | Updated: All magnets collected state - no next magnet shown, "coming soon" message |
| 2025-01-07 | Finalized decisions: No quiz theming, use existing selection system, replay on exhausted |
| 2025-01-07 | Updated: Separate cooldowns per activity type (not shared), generic "try other activities" messaging |
