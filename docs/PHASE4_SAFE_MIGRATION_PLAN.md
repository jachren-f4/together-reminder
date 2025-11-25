# Phase 4 Safe Migration Plan

**Goal:** Migrate remaining features from Firebase → Supabase without breaking active Linked game development

**Strategy:** Additive-only changes with feature flags (OFF by default)

---

## 🛡️ Safety Guarantees

### 1. Zero Breakage for Linked Development

| Guarantee | How It's Enforced |
|-----------|-------------------|
| **No code removal** | Keep all Firebase code until Phase 5 |
| **Feature flags OFF** | All migration code gated behind `DevConfig` flags (default: false) |
| **Additive only** | Add new methods, don't modify existing ones |
| **No API changes** | Linked uses `/api/sync/linked/` (untouched) |
| **Independent testing** | I test with flags ON, you build with flags OFF |

### 2. Code Changes Pattern

**❌ NEVER DO THIS (breaks existing code):**
```dart
// Modifying existing method - DANGEROUS!
Future<void> loadQuests() async {
  // Old code deleted
  // New code added
  // If new code breaks, your builds break!
}
```

**✅ ALWAYS DO THIS (safe):**
```dart
// Keep old method working
Future<void> loadQuests() async {
  if (DevConfig.useSuperbaseForDailyQuests) {
    return _loadQuestsFromSupabase();  // NEW (flag-gated)
  }
  return _loadQuestsFromFirebase();    // OLD (still works)
}

// New method added (doesn't affect existing code)
Future<void> _loadQuestsFromSupabase() async {
  // Phase 4 implementation
  // Only runs when flag is TRUE
}
```

---

## 📋 Phase 4 Work Plan

### Week 1: Love Points Migration (Lowest Risk)

**Why start here:** Already dual-writes to Supabase, just need to remove Firebase reads

**Files touched:**
- `lib/services/love_point_service.dart` - Add `_loadFromSupabase()` method
- `api/app/api/sync/love-points/route.ts` - Already exists (no changes)

**Changes:**
```dart
// NEW method (flag-gated)
Future<void> _loadLPFromSupabase() async {
  if (!DevConfig.useSupabaseForLovePoints) return;
  // Fetch from Supabase API instead of Firebase RTDB
}

// MODIFIED method (existing code preserved)
Future<void> startListeningForLPAwards() async {
  if (DevConfig.useSupabaseForLovePoints) {
    return _startSupabaseListener();  // NEW path
  }
  // OLD Firebase listener code (unchanged)
}
```

**Your builds:** Flag is `false`, old Firebase code runs, nothing breaks ✅

---

### Week 2: Daily Quests Migration

**Files touched:**
- `lib/services/quest_sync_service.dart` - Add `_loadFromSupabase()` method
- `api/app/api/sync/daily-quests/route.ts` - Already dual-writes (no changes)

**Changes:**
```dart
// NEW method (flag-gated)
Future<List<DailyQuest>> _loadQuestsFromSupabase() async {
  if (!DevConfig.useSuperbaseForDailyQuests) return [];
  // Fetch from Supabase API
}

// MODIFIED method (existing code preserved)
Future<void> loadDailyQuests() async {
  if (DevConfig.useSuperbaseForDailyQuests) {
    return _loadQuestsFromSupabase();  // NEW
  }
  return _loadQuestsFromFirebase();    // OLD (unchanged)
}
```

**Your builds:** Flag is `false`, old Firebase code runs, nothing breaks ✅

---

### Week 3: Memory Flip + You or Me (Final Features)

**Same pattern:** Add new methods, gate behind flags, preserve old code

---

## 🧪 Testing Protocol (Every Change)

**Before committing ANY code:**

1. **Test with flag OFF (default):**
   ```bash
   # Your workflow - should work perfectly
   cd app && flutter run -d chrome
   # Verify: Linked game works, old features work
   ```

2. **Test with flag ON (my testing):**
   ```dart
   // Temporarily enable in dev_config.dart
   static const bool useSupabaseForLovePoints = true;
   ```
   ```bash
   # My testing workflow
   /runtogether
   # Verify: Love Points works with Supabase
   ```

3. **Revert flag to OFF before commit:**
   ```dart
   static const bool useSupabaseForLovePoints = false;  // SAFE DEFAULT
   ```

4. **Commit with clear message:**
   ```bash
   git commit -m "feat(phase4): Add Supabase path for Love Points (flag-gated, OFF by default)"
   ```

---

## 📁 Files That Will NEVER Be Touched

**Guaranteed safe files (Linked uses these):**
- ✅ `lib/services/linked_service.dart` - No changes
- ✅ `lib/screens/linked_*.dart` - No changes
- ✅ `lib/models/linked.dart` - No changes
- ✅ `api/app/api/sync/linked/*` - No changes
- ✅ `lib/widgets/linked/*` - No changes

**Why:** Linked is already Supabase-only, no migration needed!

---

## 🚀 Deployment Strategy

### Option A: Merge Both at Once (Recommended)

```bash
# When BOTH are complete:
main
├── feature/linked-game (merged) ✅
└── feature/phase4-migration (merged) ✅

# Then flip flags to TRUE
static const bool useSupabaseForLovePoints = true;
static const bool useSuperbaseForDailyQuests = true;
# etc.

# Deploy v2.0.0 with both features
```

### Option B: Merge Phase 4 Early, Enable Later

```bash
# Merge Phase 4 code (flags OFF)
git merge feature/phase4-migration
# Your builds: Still use Firebase, nothing breaks ✅

# Later: Merge Linked
git merge feature/linked-game
# Still works ✅

# Much later: Flip flags when ready
# Edit dev_config.dart → set flags to true
```

---

## ❓ FAQ

**Q: What if your Phase 4 code has bugs?**
A: Flags are OFF, your builds never run the buggy code.

**Q: What if I accidentally enable a flag?**
A: Each flag has clear docs. Default is OFF. IDE shows the value.

**Q: How do I know what's safe to merge?**
A: Check git commit messages: "flag-gated, OFF by default" = safe to merge.

**Q: What if we conflict on the same file?**
A: Unlikely - I'm adding NEW methods, not modifying your code. Merge conflicts will be minimal and easy to resolve (just keep both methods).

**Q: When will Firebase be removed?**
A: Phase 5 (after Linked ships). We'll remove old code paths together when all flags are TRUE and tested.

---

## 📊 Progress Tracking

| Feature | API Endpoint | Flag Added | Supabase Path Added | Tested | Ready for Phase 5 |
|---------|--------------|------------|---------------------|---------|-------------------|
| Love Points | `/api/sync/love-points` | ✅ | ⏳ | ⏳ | ⏳ |
| Daily Quests | `/api/sync/daily-quests` | ✅ | ⏳ | ⏳ | ⏳ |
| Memory Flip | `/api/sync/memory-flip` | ✅ | ⏳ | ⏳ | ⏳ |
| You or Me | `/api/sync/you-or-me` | ✅ | ⏳ | ⏳ | ⏳ |

---

## 🎯 Success Criteria

**Phase 4 complete when:**
- ✅ All flags can be enabled without breaking anything
- ✅ Linked game ships successfully (independent of migration)
- ✅ All features tested with Supabase-only mode
- ✅ Performance validated (Supabase ≥ Firebase speed)
- ✅ Ready for Phase 5 Firebase removal

---

**Last Updated:** 2025-11-25
**Status:** Feature flags added, ready to begin Love Points migration
