# Phase 3: Leaderboard System - Detailed Implementation Plan

**Goal:** Add competitive element to drive retention and social engagement
**Timeline:** Week 5
**Journeys Covered:** #5 (Check Leaderboard Ranking: Home → Leaderboard → Friends View)

---

## 📋 Overview

The Leaderboard is a global ranking system showing how couples compare based on Love Points. It includes:
- **Global leaderboard**: Top 100 couples worldwide
- **Friends leaderboard**: Compare with paired friends (optional for MVP)
- **Rank tracking**: Show current position and change (↑↓)
- **6-hour updates**: Leaderboard refreshes 4x daily
- **Elastic progression**: LP can go up/down, but floor protection prevents major losses

**Why Leaderboard in Phase 3?**
- Requires cloud infrastructure (Firestore) - significant architectural change
- Needs server-side LP tracking for security (can't trust client)
- Adds social/competitive element after core activities are established
- Drives long-term retention through comparison and status

---

## 🎯 Success Criteria

Phase 3 is complete when:

1. ✅ Couples are ranked globally by Love Points
2. ✅ Leaderboard updates every 6 hours (4x daily)
3. ✅ Users see their current rank, tier, and LP total
4. ✅ Rank delta (↑↓) shown since last update
5. ✅ Top 100 couples displayed in Global view
6. ✅ Leaderboard accessible from bottom navigation
7. ✅ LP now tracked server-side (Firestore) with local cache
8. ✅ Floor protection enforced (LP never drops below milestone)
9. ✅ 4-week mini chart shows LP trend (optional)
10. ✅ Rank notifications: "You moved up 12 spots! 🎉"

---

## ⚠️ Major Architectural Change

**Phase 3 requires migrating from local-only LP storage to hybrid Firestore + local cache.**

### Why Migrate?

| Before (Phase 1-2) | After (Phase 3) |
|-------------------|----------------|
| LP stored only in local Hive | LP stored in Firestore + cached locally |
| No global ranking | Global leaderboard possible |
| Vulnerable to tampering | Server-side validation |
| Offline-first, no sync | Sync on app open, offline fallback |

### What Changes?

1. **Firestore collections added**:
   - `couples` - stores LP, rank, tier for each couple
   - `leaderboard` - materialized view for fast queries
   - `lp_transactions` - server-side audit log

2. **LovePointService refactored**:
   - Awards LP locally (instant feedback)
   - Syncs to Firestore (background)
   - Polls Firestore for rank updates

3. **New sync mechanism**:
   - On app start: fetch latest LP from Firestore
   - On LP change: push to Firestore immediately
   - Conflict resolution: Firestore is source of truth

---

## 🗂️ Task Breakdown

### **Task 1: Firestore Data Schema**

#### 1.1 Couples Collection

```
couples/{coupleId}
  - lovePoints: int
  - arenaTier: int (1-5)
  - floor: int (milestone protection)
  - lastActivityDate: timestamp
  - user1Id: string
  - user2Id: string
  - user1Name: string
  - user2Name: string
  - createdAt: timestamp
  - rank: int (computed by Cloud Function)
  - rankDelta: int (change since last update)
  - lastRankUpdate: timestamp
```

**Indexes needed:**
- `lovePoints` DESC (for leaderboard query)
- `lastActivityDate` (for decay calculation)

---

#### 1.2 Leaderboard Collection (Materialized View)

```
leaderboard/{coupleId}
  - coupleId: string
  - user1Name: string
  - user2Name: string
  - lovePoints: int
  - arenaTier: int
  - rank: int
  - rankDelta: int
  - lastUpdated: timestamp
```

**Purpose:** Optimized for fast reads, updated by scheduled Cloud Function

---

#### 1.3 LP Transactions Collection (Server-side Audit)

```
lp_transactions/{transactionId}
  - coupleId: string
  - amount: int
  - reason: string
  - timestamp: timestamp
  - relatedId: string (reminderId, quizId, etc.)
  - multiplier: int
  - validatedBy: string ('server' | 'client')
```

**Purpose:** Server-side validation, anti-cheating, analytics

---

### **Task 2: Cloud Functions for Leaderboard**

#### 2.1 Update LP Cloud Function (`functions/index.js`)

```javascript
// Called by client after local LP award (validation + sync)
exports.awardLovePoints = functions.https.onCall(async (request) => {
  const { coupleId, amount, reason, relatedId, multiplier = 1 } = request.data;

  // Validation
  if (!coupleId || !amount || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Verify couple exists
  const coupleRef = db.collection('couples').doc(coupleId);
  const coupleDoc = await coupleRef.get();

  if (!coupleDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Couple not found');
  }

  const coupleData = coupleDoc.data();
  const actualAmount = amount * multiplier;

  // Update LP
  const newTotal = coupleData.lovePoints + actualAmount;
  const newTier = calculateTier(newTotal);
  const newFloor = getTierFloor(newTier);

  await coupleRef.update({
    lovePoints: newTotal,
    arenaTier: newTier,
    floor: Math.max(coupleData.floor, newFloor),
    lastActivityDate: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Log transaction
  await db.collection('lp_transactions').add({
    coupleId,
    amount: actualAmount,
    reason,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    relatedId: relatedId || null,
    multiplier,
    validatedBy: 'server',
  });

  console.log(`✅ Awarded ${actualAmount} LP to ${coupleId} (Total: ${newTotal})`);

  return {
    success: true,
    newTotal,
    newTier,
    newFloor,
  };
});

function calculateTier(lovePoints) {
  if (lovePoints >= 10000) return 5;
  if (lovePoints >= 5000) return 4;
  if (lovePoints >= 2500) return 3;
  if (lovePoints >= 1000) return 2;
  return 1;
}

function getTierFloor(tier) {
  const floors = { 1: 0, 2: 1000, 3: 2500, 4: 5000, 5: 10000 };
  return floors[tier];
}
```

---

#### 2.2 Update Leaderboard Cloud Function (Scheduled)

```javascript
// Runs every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)
exports.updateLeaderboard = functions.pubsub
  .schedule('0 */6 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🔄 Updating leaderboard...');

    // Fetch all couples sorted by LP
    const couplesSnapshot = await db.collection('couples')
      .orderBy('lovePoints', 'desc')
      .limit(100)
      .get();

    const batch = db.batch();
    let rank = 1;

    for (const doc of couplesSnapshot.docs) {
      const coupleData = doc.data();
      const previousRank = coupleData.rank || 999;
      const rankDelta = previousRank - rank;

      // Update rank in couples collection
      const coupleRef = db.collection('couples').doc(doc.id);
      batch.update(coupleRef, {
        rank,
        rankDelta,
        lastRankUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update leaderboard materialized view
      const leaderboardRef = db.collection('leaderboard').doc(doc.id);
      batch.set(leaderboardRef, {
        coupleId: doc.id,
        user1Name: coupleData.user1Name,
        user2Name: coupleData.user2Name,
        lovePoints: coupleData.lovePoints,
        arenaTier: coupleData.arenaTier,
        rank,
        rankDelta,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      rank++;
    }

    await batch.commit();
    console.log(`✅ Leaderboard updated (${couplesSnapshot.size} couples)`);
  });
```

---

#### 2.3 Create Couple Cloud Function

```javascript
// Called when a new couple pairs (from pairing screen)
exports.createCouple = functions.https.onCall(async (request) => {
  const { user1Id, user2Id, user1Name, user2Name } = request.data;

  if (!user1Id || !user2Id) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing user IDs');
  }

  // Create couple document (coupleId = sorted user IDs)
  const coupleId = [user1Id, user2Id].sort().join('_');
  const coupleRef = db.collection('couples').doc(coupleId);

  // Check if already exists
  const existing = await coupleRef.get();
  if (existing.exists) {
    return { coupleId, alreadyExists: true };
  }

  await coupleRef.set({
    user1Id,
    user2Id,
    user1Name: user1Name || 'User 1',
    user2Name: user2Name || 'User 2',
    lovePoints: 0,
    arenaTier: 1,
    floor: 0,
    lastActivityDate: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    rank: 999999, // Placeholder until first leaderboard update
    rankDelta: 0,
  });

  console.log(`✅ Created couple: ${coupleId}`);

  return { coupleId, alreadyExists: false };
});
```

---

### **Task 3: Refactor LovePointService**

#### 3.1 Update LovePointService (`app/lib/services/love_point_service.dart`)

**Key changes:**
1. Award LP locally (instant UI feedback)
2. Call Cloud Function to sync to Firestore
3. Add sync methods for polling updates
4. Add conflict resolution (Firestore = source of truth)

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class LovePointService {
  static final StorageService _storage = StorageService();
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Vacation Arena Thresholds (unchanged)
  static const Map<int, Map<String, dynamic>> arenas = {
    1: {'name': 'Cozy Cabin', 'emoji': '🏕️', 'min': 0, 'max': 1000, 'floor': 0},
    2: {'name': 'Beach Villa', 'emoji': '🏖️', 'min': 1000, 'max': 2500, 'floor': 1000},
    3: {'name': 'Yacht Getaway', 'emoji': '⛵', 'min': 2500, 'max': 5000, 'floor': 2500},
    4: {'name': 'Mountain Penthouse', 'emoji': '🏔️', 'min': 5000, 'max': 10000, 'floor': 5000},
    5: {'name': 'Castle Retreat', 'emoji': '🏰', 'min': 10000, 'max': 999999, 'floor': 10000},
  };

  /// Award Love Points (optimistic local update + server sync)
  static Future<void> awardPoints({
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
  }) async {
    final user = _storage.getUser();
    if (user == null) {
      print('❌ No user found, cannot award points');
      return;
    }

    final actualAmount = amount * multiplier;

    // STEP 1: Update locally (instant feedback)
    await _updateLocalLP(user, actualAmount, reason, relatedId, multiplier);

    // STEP 2: Sync to Firestore (background)
    await _syncLPToFirestore(actualAmount, reason, relatedId, multiplier);
  }

  /// Update local LP (unchanged logic)
  static Future<void> _updateLocalLP(
    User user,
    int actualAmount,
    String reason,
    String? relatedId,
    int multiplier,
  ) async {
    // Create transaction record
    final transaction = LovePointTransaction(
      id: const Uuid().v4(),
      amount: actualAmount,
      reason: reason,
      timestamp: DateTime.now(),
      relatedId: relatedId,
      multiplier: multiplier,
    );

    await _storage.saveTransaction(transaction);

    // Update user's total LP
    final newTotal = user.lovePoints + actualAmount;
    user.lovePoints = newTotal;
    user.lastActivityDate = DateTime.now();

    // Check for tier upgrade
    final newTier = _calculateTier(newTotal);
    final previousTier = user.arenaTier;

    if (newTier > previousTier) {
      user.arenaTier = newTier;
      user.floor = arenas[newTier]!['floor'] as int;
      print('🎉 Tier upgraded to ${arenas[newTier]!['name']}!');
    }

    await user.save();

    print('💰 Awarded $actualAmount LP for $reason (Total: ${user.lovePoints})');
  }

  /// Sync LP to Firestore (new)
  static Future<void> _syncLPToFirestore(
    int amount,
    String reason,
    String? relatedId,
    int multiplier,
  ) async {
    try {
      final coupleId = await _getCoupleId();
      if (coupleId == null) {
        print('⚠️ No coupleId, skipping Firestore sync');
        return;
      }

      final callable = _functions.httpsCallable('awardLovePoints');
      final result = await callable.call({
        'coupleId': coupleId,
        'amount': amount,
        'reason': reason,
        'relatedId': relatedId,
        'multiplier': multiplier,
      });

      print('✅ LP synced to Firestore: ${result.data}');
    } catch (e) {
      print('❌ Error syncing LP to Firestore: $e');
      // Don't throw - local LP is still awarded
    }
  }

  /// Fetch latest LP from Firestore (reconcile on app start)
  static Future<void> syncFromFirestore() async {
    try {
      final coupleId = await _getCoupleId();
      if (coupleId == null) return;

      final doc = await _firestore.collection('couples').doc(coupleId).get();
      if (!doc.exists) {
        print('⚠️ Couple not found in Firestore');
        return;
      }

      final data = doc.data()!;
      final serverLP = data['lovePoints'] as int;
      final serverTier = data['arenaTier'] as int;
      final serverFloor = data['floor'] as int;

      // Update local cache
      final user = _storage.getUser();
      if (user != null) {
        user.lovePoints = serverLP;
        user.arenaTier = serverTier;
        user.floor = serverFloor;
        await user.save();

        print('🔄 Synced LP from Firestore: $serverLP LP');
      }
    } catch (e) {
      print('❌ Error syncing from Firestore: $e');
    }
  }

  /// Get coupleId (sorted user IDs)
  static Future<String?> _getCoupleId() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) return null;

    // CoupleId = sorted user IDs joined with underscore
    // (Assuming partner has a userId field - may need to store this)
    // For MVP, we can use pushToken as proxy, but ideally store userId
    final ids = [user.id, partner.pushToken].toList()..sort();
    return ids.join('_');
  }

  // Existing methods (unchanged)
  static int _calculateTier(int lovePoints) {
    for (int tier = 5; tier >= 1; tier--) {
      if (lovePoints >= arenas[tier]!['min']) {
        return tier;
      }
    }
    return 1;
  }

  static Map<String, dynamic> getCurrentTierInfo() {
    final user = _storage.getUser();
    if (user == null) return arenas[1]!;
    return arenas[user.arenaTier]!;
  }

  static Map<String, dynamic>? getNextTierInfo() {
    final user = _storage.getUser();
    if (user == null || user.arenaTier >= 5) return null;
    return arenas[user.arenaTier + 1];
  }

  static double getProgressToNextTier() {
    final user = _storage.getUser();
    if (user == null || user.arenaTier >= 5) return 1.0;

    final currentTier = arenas[user.arenaTier]!;
    final nextTier = arenas[user.arenaTier + 1]!;

    final currentMin = currentTier['min'] as int;
    final nextMin = nextTier['min'] as int;
    final range = nextMin - currentMin;
    final progress = user.lovePoints - currentMin;

    return (progress / range).clamp(0.0, 1.0);
  }

  static int getFloorProtection() {
    final user = _storage.getUser();
    if (user == null) return 0;
    return user.floor;
  }

  static bool canDeductPoints(int amount) {
    final user = _storage.getUser();
    if (user == null) return false;
    return (user.lovePoints - amount) >= user.floor;
  }

  static Map<String, dynamic> getStats() {
    final user = _storage.getUser();
    if (user == null) {
      return {
        'total': 0,
        'tier': 1,
        'floor': 0,
        'progressToNext': 0.0,
      };
    }

    return {
      'total': user.lovePoints,
      'tier': user.arenaTier,
      'floor': user.floor,
      'progressToNext': getProgressToNextTier(),
      'currentArena': getCurrentTierInfo(),
      'nextArena': getNextTierInfo(),
    };
  }
}
```

---

### **Task 4: Leaderboard Service**

#### 4.1 Create LeaderboardService (`app/lib/services/leaderboard_service.dart`)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch global leaderboard (top 100)
  static Future<List<Map<String, dynamic>>> fetchGlobalLeaderboard() async {
    try {
      final snapshot = await _firestore
          .collection('leaderboard')
          .orderBy('rank')
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get current user's rank
  static Future<Map<String, dynamic>?> getCurrentRank(String coupleId) async {
    try {
      final doc = await _firestore.collection('couples').doc(coupleId).get();
      if (!doc.exists) return null;

      return {
        'rank': doc.data()!['rank'],
        'rankDelta': doc.data()!['rankDelta'],
        'lovePoints': doc.data()!['lovePoints'],
        'arenaTier': doc.data()!['arenaTier'],
      };
    } catch (e) {
      print('❌ Error fetching rank: $e');
      return null;
    }
  }

  /// Listen to rank changes (real-time)
  static Stream<Map<String, dynamic>?> watchRank(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {
        'rank': doc.data()!['rank'],
        'rankDelta': doc.data()!['rankDelta'],
        'lovePoints': doc.data()!['lovePoints'],
        'arenaTier': doc.data()!['arenaTier'],
      };
    });
  }
}
```

---

### **Task 5: Leaderboard Screen**

#### 5.1 Create LeaderboardScreen (`app/lib/screens/leaderboard_screen.dart`)

**Layout:**

```
┌─────────────────────────┐
│  🏆 Leaderboard         │
│  ┌─────────┬─────────┐  │
│  │ Global  │ Friends │  │ ← Tabs
│  └─────────┴─────────┘  │
│                         │
│  Your Rank: #127 ↑12   │ ← User's position
│  1,280 LP • Beach Villa │
│                         │
│  ┌─────────────────┐    │
│  │ #1  John & Jane │    │
│  │     10,523 LP   │    │
│  │     🏰 Castle   │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ #2  Alex & Sam  │    │
│  │     9,841 LP    │    │
│  │     🏔️ Penthouse│    │
│  └─────────────────┘    │
│  ...                    │
└─────────────────────────┘
```

**Code structure:**

```dart
class LeaderboardScreen extends StatefulWidget {
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _filter = 'global'; // 'global' | 'friends'
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _userRank;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);

    // Fetch leaderboard
    final leaderboard = await LeaderboardService.fetchGlobalLeaderboard();

    // Fetch user's rank
    final coupleId = await _getCoupleId();
    final userRank = coupleId != null
        ? await LeaderboardService.getCurrentRank(coupleId)
        : null;

    setState(() {
      _leaderboard = leaderboard;
      _userRank = userRank;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // User's rank card
            if (_userRank != null) _buildUserRankCard(),

            // Leaderboard list
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.all(20),
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        return _buildLeaderboardCard(_leaderboard[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRankCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Rank',
                style: AppTheme.bodyFont.copyWith(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '#${_userRank!['rank']}',
                    style: AppTheme.headlineFont.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  _buildRankDelta(_userRank!['rankDelta']),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '${_userRank!['lovePoints']} LP • ${_getArenaName(_userRank!['arenaTier'])}',
                style: AppTheme.bodyFont.copyWith(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankDelta(int delta) {
    if (delta == 0) return SizedBox.shrink();

    final isUp = delta > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUp ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: isUp ? Colors.green : Colors.red,
          ),
          SizedBox(width: 4),
          Text(
            delta.abs().toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUp ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(Map<String, dynamic> entry) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            child: Text(
              '#${entry['rank']}',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(width: 12),

          // Couple names & LP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['user1Name']} & ${entry['user2Name']}',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${entry['lovePoints']} LP',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Arena emoji
          Text(
            _getArenaEmoji(entry['arenaTier']),
            style: TextStyle(fontSize: 28),
          ),
        ],
      ),
    );
  }

  String _getArenaEmoji(int tier) {
    const emojis = ['🏕️', '🏖️', '⛵', '🏔️', '🏰'];
    return emojis[tier - 1];
  }

  String _getArenaName(int tier) {
    const names = ['Cozy Cabin', 'Beach Villa', 'Yacht Getaway', 'Mountain Penthouse', 'Castle Retreat'];
    return names[tier - 1];
  }
}
```

---

### **Task 6: Add Leaderboard to Bottom Navigation**

Update `app/lib/screens/home_screen.dart`:

```dart
final List<Widget> _screens = const [
  SendReminderScreen(),
  InboxScreen(),
  ProfileScreen(),
  LeaderboardScreen(), // NEW
  SettingsScreen(),
];

// Add to bottom nav
_NavItem(
  icon: '🏆',
  label: 'Ranks',
  isActive: _currentIndex == 3,
  onTap: () => setState(() => _currentIndex = 3),
),
```

---

### **Task 7: Initialization & Sync**

#### 7.1 Update main.dart

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

  // Sync LP from Firestore (reconcile on app start)
  await LovePointService.syncFromFirestore();

  // Mock data
  await MockDataService.injectMockDataIfNeeded();

  runApp(const TogetherRemindApp());
}
```

---

#### 7.2 Create Couple on Pairing

Update `app/lib/screens/pairing_screen.dart` to call `createCouple` Cloud Function after successful pairing:

```dart
// After partner is saved locally
final callable = FirebaseFunctions.instance.httpsCallable('createCouple');
await callable.call({
  'user1Id': user.id,
  'user2Id': partner.pushToken, // Or store partner.userId
  'user1Name': user.name,
  'user2Name': partner.name,
});
```

---

### **Task 8: Testing**

#### 8.1 Manual Testing Checklist

- [ ] Pair two devices
- [ ] Create couple in Firestore (check console)
- [ ] Award LP on both devices
- [ ] Verify LP syncs to Firestore
- [ ] Check leaderboard appears
- [ ] Verify rank updates after 6-hour cron
- [ ] Test rank delta (↑↓) display
- [ ] Verify floor protection works
- [ ] Test offline mode (local LP still works)
- [ ] Test reconnection (syncs to Firestore)

---

#### 8.2 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Couples collection
    match /couples/{coupleId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }

    // Leaderboard collection
    match /leaderboard/{coupleId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }

    // LP Transactions
    match /lp_transactions/{transactionId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

## 📦 Deliverables

**New Files:**
- `app/lib/services/leaderboard_service.dart`
- `app/lib/screens/leaderboard_screen.dart`

**Modified Files:**
- `app/lib/services/love_point_service.dart` (major refactor)
- `app/lib/screens/home_screen.dart` (add leaderboard nav)
- `app/lib/screens/pairing_screen.dart` (create couple on pair)
- `functions/index.js` (add 3 new functions + scheduled job)
- `firestore.rules` (security rules)

**Cloud Functions:**
- `awardLovePoints` - Sync LP from client
- `createCouple` - Initialize couple on pairing
- `updateLeaderboard` - Scheduled job (every 6 hours)

---

## 🎯 Success Metrics

After Phase 3, measure:

| Metric | Target |
|--------|--------|
| Leaderboard views per user per week | ≥ 3 |
| Rank notification CTR | ≥ 40% |
| Couples checking rank after LP gain | ≥ 60% |
| Firestore sync success rate | ≥ 98% |

---

## 🚀 Next Steps After Phase 3

Once Phase 3 is complete:

1. Monitor Firestore usage (reads/writes)
2. Optimize leaderboard caching (6-hour TTL)
3. Add Friends leaderboard (if social features added)
4. Consider adding 4-week LP trend chart
5. Plan Phase 4: Weekly Challenges
6. Add decay system for inactive couples (optional)

---

**Ready to build competitive engagement! 🏆**
