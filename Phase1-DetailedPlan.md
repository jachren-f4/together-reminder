# Phase 1: Core LP System - Detailed Implementation Plan

**Goal:** Integrate Love Points into existing features (reminders & pokes) and build Profile screen
**Timeline:** Week 1-2
**Journeys Covered:** #2 (Send Reminder with LP), #3 (Poke Exchange)

---

## 📋 Current State Analysis

### Existing Infrastructure
- ✅ Hive local storage with 3 models: User, Partner, Reminder
- ✅ StorageService with box operations
- ✅ ReminderService with Cloud Function integration
- ✅ PokeService with rate limiting and mutual detection
- ✅ Bottom navigation with 3 tabs: Send (💕), Inbox (📝), Settings (⚙️)
- ✅ Poke FAB with animation on Home screen
- ✅ Reminder cards in InboxScreen
- ✅ Cloud Functions deployed (sendReminder, sendPoke, sendPairingConfirmation)

### What We Need to Add
- ❌ Love Points tracking in User model
- ❌ Arena tier and floor protection
- ❌ LovePointTransaction history model
- ❌ LovePointService for awarding/tracking points
- ❌ Profile screen showing LP, tier, progress
- ❌ LP rewards in ReminderService and PokeService
- ❌ UI indicators showing LP earned
- ❌ Cloud Function updates to award LP server-side

---

## 🗂️ Task Breakdown

### **Task 1: Data Model Updates**

#### 1.1 Update User Model (`app/lib/models/user.dart`)

**Changes:**
```dart
@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String pushToken;
  @HiveField(2) late DateTime createdAt;
  @HiveField(3) String? name;

  // NEW FIELDS - Use defaultValue for backward compatibility
  @HiveField(4, defaultValue: 0) int lovePoints;
  @HiveField(5, defaultValue: 1) int arenaTier; // 1-5 (Cabin to Castle)
  @HiveField(6, defaultValue: 0) int floor; // Floor protection threshold
  @HiveField(7) DateTime? lastActivityDate;
}
```

**Why these fields:**
- `lovePoints`: Total LP accumulated (can go up/down, but not below floor)
- `arenaTier`: Current vacation arena (1=Cabin, 2=Beach, 3=Yacht, 4=Penthouse, 5=Castle)
- `floor`: Highest floor reached (protects from dropping below milestone)
- `lastActivityDate`: For decay system (Phase 5+)

**Files to modify:**
- `app/lib/models/user.dart` - Add fields
- Must regenerate: `flutter pub run build_runner build --delete-conflicting-outputs`

---

#### 1.2 Create LovePointTransaction Model (`app/lib/models/love_point_transaction.dart`)

**New file:**
```dart
import 'package:hive/hive.dart';

part 'love_point_transaction.g.dart';

@HiveType(typeId: 3) // Next available typeId
class LovePointTransaction extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late int amount; // Can be positive or negative
  @HiveField(2) late String reason; // 'reminder_sent', 'reminder_done', 'mutual_poke', etc.
  @HiveField(3) late DateTime timestamp;
  @HiveField(4) String? relatedId; // reminderId or pokeId for reference
  @HiveField(5, defaultValue: 1) int multiplier; // For weekly challenge 2x, default 1x

  LovePointTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.timestamp,
    this.relatedId,
    this.multiplier = 1,
  });

  // Helper to get display text
  String get displayReason {
    switch (reason) {
      case 'reminder_sent': return 'Sent reminder';
      case 'reminder_done': return 'Completed reminder';
      case 'mutual_poke': return 'Mutual poke';
      case 'poke_back': return 'Poke back';
      case 'quiz_completed': return 'Couple quiz';
      case 'weekly_challenge_bonus': return 'Weekly challenge';
      default: return reason;
    }
  }
}
```

**Why this model:**
- Tracks LP history for transparency
- Shows user what earned them points
- Enables future analytics and weekly recap
- Supports multipliers for challenges

**Files to create:**
- `app/lib/models/love_point_transaction.dart`
- Must register adapter in `StorageService.init()`
- Must regenerate adapters

---

#### 1.3 Update StorageService (`app/lib/services/storage_service.dart`)

**Changes needed:**

1. Add new box constant:
```dart
static const String _transactionsBox = 'love_point_transactions';
```

2. Register adapter in `init()`:
```dart
Hive.registerAdapter(LovePointTransactionAdapter());
await Hive.openBox<LovePointTransaction>(_transactionsBox);
```

3. Add transaction operations:
```dart
// Transaction operations
Box<LovePointTransaction> get transactionsBox =>
    Hive.box<LovePointTransaction>(_transactionsBox);

Future<void> saveTransaction(LovePointTransaction transaction) async {
  await transactionsBox.put(transaction.id, transaction);
}

List<LovePointTransaction> getAllTransactions() {
  final transactions = transactionsBox.values.toList();
  transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return transactions;
}

List<LovePointTransaction> getRecentTransactions({int limit = 10}) {
  return getAllTransactions().take(limit).toList();
}
```

**Files to modify:**
- `app/lib/services/storage_service.dart`

---

### **Task 2: Love Point Service Layer**

#### 2.1 Create LovePointService (`app/lib/services/love_point_service.dart`)

**New file with complete service:**

```dart
import 'package:togetherremind/models/user.dart';
import 'package:togetherremind/models/love_point_transaction.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class LovePointService {
  static final StorageService _storage = StorageService();

  // Vacation Arena Thresholds
  static const Map<int, Map<String, dynamic>> arenas = {
    1: {'name': 'Cozy Cabin', 'emoji': '🏕️', 'min': 0, 'max': 1000, 'floor': 0},
    2: {'name': 'Beach Villa', 'emoji': '🏖️', 'min': 1000, 'max': 2500, 'floor': 1000},
    3: {'name': 'Yacht Getaway', 'emoji': '⛵', 'min': 2500, 'max': 5000, 'floor': 2500},
    4: {'name': 'Mountain Penthouse', 'emoji': '🏔️', 'min': 5000, 'max': 10000, 'floor': 5000},
    5: {'name': 'Castle Retreat', 'emoji': '🏰', 'min': 10000, 'max': 999999, 'floor': 10000},
  };

  /// Award Love Points to the current user
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
      // TODO: Show tier upgrade animation/notification in Phase 2
    }

    await user.save();

    print('💰 Awarded $actualAmount LP for $reason (Total: ${user.lovePoints})');
  }

  /// Calculate tier based on LP total
  static int _calculateTier(int lovePoints) {
    for (int tier = 5; tier >= 1; tier--) {
      if (lovePoints >= arenas[tier]!['min']) {
        return tier;
      }
    }
    return 1; // Default to Cabin
  }

  /// Get current tier information
  static Map<String, dynamic> getCurrentTierInfo() {
    final user = _storage.getUser();
    if (user == null) return arenas[1]!;
    return arenas[user.arenaTier]!;
  }

  /// Get next tier information (null if at max tier)
  static Map<String, dynamic>? getNextTierInfo() {
    final user = _storage.getUser();
    if (user == null || user.arenaTier >= 5) return null;
    return arenas[user.arenaTier + 1];
  }

  /// Get progress to next tier (0.0 to 1.0)
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

  /// Get floor protection amount
  static int getFloorProtection() {
    final user = _storage.getUser();
    if (user == null) return 0;
    return user.floor;
  }

  /// Check if LP can be deducted (respects floor)
  static bool canDeductPoints(int amount) {
    final user = _storage.getUser();
    if (user == null) return false;
    return (user.lovePoints - amount) >= user.floor;
  }

  /// Get LP statistics
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

**Why this architecture:**
- Centralized LP logic - single source of truth
- Automatic tier calculation on point award
- Floor protection built-in
- Transaction history for transparency
- Easy to extend with decay/multipliers later

**Files to create:**
- `app/lib/services/love_point_service.dart`

---

### **Task 3: Reminder LP Integration**

#### 3.1 Update ReminderService (`app/lib/services/reminder_service.dart`)

**Changes:**

1. Import LovePointService:
```dart
import 'package:togetherremind/services/love_point_service.dart';
```

2. Award LP when sending reminder (in `sendReminder()` after success):
```dart
// After line 42: print('✅ Cloud Function response: ${result.data}');
await LovePointService.awardPoints(
  amount: 8,
  reason: 'reminder_sent',
  relatedId: reminder.id,
);
```

3. Create new method for marking reminder as done:
```dart
static Future<void> markReminderAsDone(String reminderId) async {
  await _storage.updateReminderStatus(reminderId, 'done');

  // Award LP for completing a reminder
  await LovePointService.awardPoints(
    amount: 10,
    reason: 'reminder_done',
    relatedId: reminderId,
  );

  print('✅ Reminder marked as done, awarded 10 LP');
}
```

**LP Rewards:**
- +8 LP when sending reminder
- +10 LP when marking reminder as done
- Total: 18 LP per complete reminder cycle

**Files to modify:**
- `app/lib/services/reminder_service.dart`

---

#### 3.2 Update Reminder Cards to Show LP (`app/lib/widgets/reminder_card.dart`)

**Need to check existing implementation, but plan:**

1. Add small LP badge to received reminder cards:
```dart
// In card UI, add a corner badge:
if (reminder.type == 'received' && reminder.status != 'done')
  Positioned(
    top: 12,
    right: 12,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGreen, width: 1),
      ),
      child: Text(
        '+10 LP',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentGreen,
        ),
      ),
    ),
  ),
```

2. Show LP earned animation when marking as done (optional, Phase 2)

**Files to check/modify:**
- Need to find reminder card widget (likely in `app/lib/widgets/` or inline in `inbox_screen.dart`)

---

#### 3.3 Update SendReminderScreen to Show LP Preview

**Changes to `app/lib/screens/send_reminder_screen.dart`:**

1. Add small text below "Send Reminder" button:
```dart
Column(
  children: [
    // Existing send button
    ElevatedButton(...),

    // NEW: LP preview
    SizedBox(height: 8),
    Text(
      'Earn +8 LP',
      style: TextStyle(
        fontSize: 12,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    ),
  ],
)
```

**Files to modify:**
- `app/lib/screens/send_reminder_screen.dart`

---

### **Task 4: Poke LP Integration**

#### 4.1 Update PokeService (`app/lib/services/poke_service.dart`)

**Changes:**

1. Import LovePointService:
```dart
import 'package:togetherremind/services/love_point_service.dart';
```

2. Award LP for mutual pokes (update `sendPoke()` method):
```dart
// After line 94: _lastPokeTime = now;

// Check if this is a mutual poke (received one recently)
if (isMutualPoke(poke)) {
  await LovePointService.awardPoints(
    amount: 5,
    reason: 'mutual_poke',
    relatedId: pokeId,
  );
  print('🎉 Mutual poke! Awarded 5 LP');
}
```

3. Update `sendPokeBack()` to award LP:
```dart
// After line 147: final success = await sendPoke(emoji: '❤️');

if (success) {
  await LovePointService.awardPoints(
    amount: 3,
    reason: 'poke_back',
    relatedId: originalPokeId,
  );
  print('💕 Poke back! Awarded 3 LP');
}
```

**LP Rewards:**
- +5 LP for mutual poke (both send within 2min window)
- +3 LP for poke back (regular response)

**Files to modify:**
- `app/lib/services/poke_service.dart`

---

#### 4.2 Update Poke Bottom Sheet to Show LP (`app/lib/widgets/poke_bottom_sheet.dart`)

**Changes:**

1. Add LP preview text below send button:
```dart
// After send poke button
SizedBox(height: 8),
Text(
  'Mutual pokes earn +5 LP',
  style: TextStyle(
    fontSize: 12,
    color: AppTheme.textSecondary,
  ),
),
```

**Files to modify:**
- `app/lib/widgets/poke_bottom_sheet.dart`

---

### **Task 5: Profile Screen**

#### 5.1 Create ProfileScreen (`app/lib/screens/profile_screen.dart`)

**New file - Complete minimal profile screen:**

```dart
import 'package:flutter/material.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:togetherremind/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final stats = LovePointService.getStats();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Your Progress',
                style: AppTheme.headlineStyle.copyWith(fontSize: 32),
              ),
              SizedBox(height: 8),
              Text(
                'Together with ${partner?.name ?? 'your partner'}',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

              SizedBox(height: 32),

              // LP Counter Card
              _buildLovePointsCard(stats),

              SizedBox(height: 20),

              // Current Arena Card
              _buildCurrentArenaCard(stats),

              SizedBox(height: 20),

              // Progress to Next Tier
              _buildProgressCard(stats),

              SizedBox(height: 20),

              // Recent Activity
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLovePointsCard(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        children: [
          Text(
            '💰',
            style: TextStyle(fontSize: 48),
          ),
          SizedBox(height: 12),
          Text(
            '${stats['total']} LP',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Love Points',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          // Floor Protection Indicator
          if (stats['floor'] > 0) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🛡️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Protected at ${stats['floor']} LP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentArenaCard(Map<String, dynamic> stats) {
    final arena = stats['currentArena'];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Arena',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                arena['emoji'],
                style: TextStyle(fontSize: 56),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arena['name'],
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlack,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tier ${stats['tier']} of 5',
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(Map<String, dynamic> stats) {
    final nextArena = stats['nextArena'];
    final progress = stats['progressToNext'];

    if (nextArena == null) {
      // Max tier reached
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderLight, width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Text('👑', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                'Max Tier Reached!',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentLP = stats['total'];
    final nextTierLP = nextArena['min'];
    final remaining = nextTierLP - currentLP;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next Arena',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$remaining LP to go',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlack,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlack),
            ),
          ),

          SizedBox(height: 16),

          Row(
            children: [
              Text(
                nextArena['emoji'],
                style: TextStyle(fontSize: 32),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextArena['name'],
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Unlocks at $nextTierLP LP',
                    style: AppTheme.bodyStyle.copyWith(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final transactions = _storage.getRecentTransactions(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),

        if (transactions.isEmpty)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight, width: 1),
            ),
            child: Center(
              child: Text(
                'No activity yet',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
        else
          ...transactions.map((tx) => _buildTransactionItem(tx)).toList(),
      ],
    );
  }

  Widget _buildTransactionItem(transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: transaction.amount > 0
                  ? AppTheme.borderLight
                  : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                transaction.amount > 0 ? '+' : '-',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: transaction.amount > 0
                      ? AppTheme.primaryBlack
                      : Colors.red,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayReason,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _formatTimestamp(transaction.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.amount > 0 ? '+' : ''}${transaction.amount} LP',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: transaction.amount > 0
                  ? AppTheme.primaryBlack
                  : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
```

**Files to create:**
- `app/lib/screens/profile_screen.dart`

---

#### 5.2 Add Profile to Bottom Navigation

**Update `app/lib/screens/home_screen.dart`:**

1. Add ProfileScreen to imports:
```dart
import 'package:togetherremind/screens/profile_screen.dart';
```

2. Update screens list:
```dart
final List<Widget> _screens = const [
  SendReminderScreen(),
  InboxScreen(),
  ProfileScreen(), // NEW - replaces SettingsScreen at index 2
  SettingsScreen(), // Move to index 3
];
```

3. Update bottom nav items:
```dart
_NavItem(
  icon: '💕',
  label: 'Send',
  isActive: _currentIndex == 0,
  onTap: () => setState(() => _currentIndex = 0),
),
_NavItem(
  icon: '📝',
  label: 'Inbox',
  isActive: _currentIndex == 1,
  onTap: () => setState(() => _currentIndex = 1),
),
_NavItem(
  icon: '💎', // NEW - Profile icon
  label: 'Profile',
  isActive: _currentIndex == 2,
  onTap: () => setState(() => _currentIndex = 2),
),
_NavItem(
  icon: '⚙️',
  label: 'Settings',
  isActive: _currentIndex == 3,
  onTap: () => setState(() => _currentIndex = 3),
),
```

**Files to modify:**
- `app/lib/screens/home_screen.dart`

---

### **Task 6: Cloud Function Updates (Optional for MVP)**

**Note:** For Phase 1, we can award LP client-side since we're using local storage. However, for Phase 3+ (leaderboard), we'll need server-side LP tracking.

**For now, SKIP this task.** We'll implement server-side LP in Phase 3 when adding Firestore leaderboard.

---

### **Task 7: Testing & Mock Data Updates**

#### 7.1 Update Mock Data Service

**Update `app/lib/services/mock_data_service.dart`:**

1. Create mock user with LP:
```dart
final mockUser = User(
  id: 'mock-user-123',
  pushToken: 'mock-token',
  createdAt: DateTime.now().subtract(Duration(days: 30)),
  name: 'You',
)
  ..lovePoints = 1280 // Beach Villa tier
  ..arenaTier = 2
  ..floor = 1000
  ..lastActivityDate = DateTime.now();
```

2. Create some mock LP transactions:
```dart
final mockTransactions = [
  LovePointTransaction(
    id: '1',
    amount: 10,
    reason: 'reminder_done',
    timestamp: DateTime.now().subtract(Duration(hours: 2)),
  ),
  LovePointTransaction(
    id: '2',
    amount: 5,
    reason: 'mutual_poke',
    timestamp: DateTime.now().subtract(Duration(hours: 5)),
  ),
  // ... more transactions
];

for (var tx in mockTransactions) {
  await storage.saveTransaction(tx);
}
```

**Files to modify:**
- `app/lib/services/mock_data_service.dart`

---

## 📝 Implementation Checklist

### Week 1: Data Models & Services
- [ ] Update User model with LP fields (Task 1.1)
- [ ] Create LovePointTransaction model (Task 1.2)
- [ ] Update StorageService (Task 1.3)
- [ ] Regenerate Hive adapters: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Create LovePointService (Task 2.1)
- [ ] Test LP awarding in isolation (write unit test or manual test)

### Week 1-2: Integration
- [ ] Update ReminderService with LP rewards (Task 3.1)
- [ ] Update PokeService with LP rewards (Task 4.1)
- [ ] Update reminder cards to show "+10 LP" badge (Task 3.2)
- [ ] Update SendReminderScreen to show "Earn +8 LP" (Task 3.3)
- [ ] Update PokeBottomSheet to show LP info (Task 4.2)

### Week 2: Profile Screen
- [ ] Create ProfileScreen (Task 5.1)
- [ ] Add Profile to bottom navigation (Task 5.2)
- [ ] Update mock data with LP values (Task 7.1)
- [ ] Test complete flow: send reminder → earn LP → see in profile

### Final Testing
- [ ] Test tier progression (manually increment LP to test tier upgrades)
- [ ] Test floor protection (can't go below threshold)
- [ ] Test transaction history display
- [ ] Test on both simulator and real device
- [ ] Verify LP awards for:
  - [ ] Sending reminder (+8 LP)
  - [ ] Completing reminder (+10 LP)
  - [ ] Mutual poke (+5 LP)
  - [ ] Poke back (+3 LP)

---

## 🎯 Success Criteria

**Phase 1 is complete when:**

1. ✅ User model tracks LP, tier, and floor
2. ✅ LovePointService can award points and calculate tiers
3. ✅ Reminders award LP (+8 sent, +10 done)
4. ✅ Pokes award LP (+5 mutual, +3 back)
5. ✅ Profile screen displays:
   - Total LP with floor protection indicator
   - Current vacation arena with emoji
   - Progress bar to next tier
   - Recent LP transaction history
6. ✅ Bottom nav has 4 tabs: Send, Inbox, Profile, Settings
7. ✅ LP indicators visible in UI (reminder cards, send screen, poke sheet)
8. ✅ Mock data includes LP values for testing

---

## 📦 Deliverables

**New Files:**
- `app/lib/models/love_point_transaction.dart`
- `app/lib/services/love_point_service.dart`
- `app/lib/screens/profile_screen.dart`

**Modified Files:**
- `app/lib/models/user.dart`
- `app/lib/services/storage_service.dart`
- `app/lib/services/reminder_service.dart`
- `app/lib/services/poke_service.dart`
- `app/lib/screens/home_screen.dart`
- `app/lib/screens/send_reminder_screen.dart`
- `app/lib/widgets/poke_bottom_sheet.dart`
- `app/lib/services/mock_data_service.dart`
- (Find and update reminder card widget)

**Generated Files:**
- `app/lib/models/user.g.dart` (regenerated)
- `app/lib/models/love_point_transaction.g.dart` (new)

---

## 🚀 Next Steps After Phase 1

Once Phase 1 is complete and tested:

1. Demo the LP system with mock data
2. Gather feedback on UI/UX
3. Plan Phase 2: Couple Quiz activity
4. Consider animations for LP earning (optional polish)
5. Prepare for Firestore migration (Phase 3 leaderboard)

---

**Ready to begin implementation!**
