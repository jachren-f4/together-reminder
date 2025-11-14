# Pairing Code Redesign - Implementation Plan

**Status:** Planning Phase
**Created:** 2025-11-13
**Mockup:** `/mockups/pairing_code_screen_v2.html`

---

## Overview

Redesign the remote pairing flow to replace the current "Generate Code" → "Waiting" screen approach with a persistent code display that users can share at any time.

---

## Current Implementation Analysis

### Current Flow (Remote Tab)
1. User taps "Generate Pairing Code" → generates 6-char code with 10min expiration
2. Code display screen shows code + timer + copy/share buttons
3. After sharing, transitions to "Waiting for partner" screen
4. Partner enters code in separate dialog
5. Codes expire after 10 minutes

### Current Files
- `lib/screens/pairing_screen.dart` - Main pairing UI with tabs
- `lib/services/remote_pairing_service.dart` - Code generation and verification
- `lib/models/pairing_code.dart` - PairingCode model with expiration logic
- `functions/index.js` - Cloud function for code storage/verification
- `database.rules.json` - RTDB security rules for pairing_codes

---

## New Design Requirements

### User Experience Changes
1. **No code expiration** - Codes persist until user pairs or generates new one
2. **Single-screen view** - Two sections on one screen, no navigation between states
3. **Tab rename** - "Remote" → "Letter Code", "In Person" → "QR Code"
4. **Default tab** - "Letter Code" tab opens by default instead of "QR Code"
5. **Persistent display** - Code always visible, no waiting screen

### Visual Changes
1. Two cards in "Letter Code" tab:
   - **Top card:** "I want to invite [Partner Name]" with code display + share button
   - **Bottom card:** "I have a code from [Partner Name]" with 6 input boxes + pair button
2. "or" divider between cards
3. Code displays on single line (e.g., "WKR-8BK")
4. "Tap to copy" hint instead of separate copy button
5. No expiration timer display

---

## Technical Changes Needed

### 1. Data Model Changes

**File:** `lib/models/pairing_code.dart`

**Current:**
```dart
class PairingCode {
  final String code;
  final String userId;
  final String userName;
  final String pushToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  String get formattedTimeRemaining => ...;
}
```

**Changes Required:**
- Remove `expiresAt` field (codes don't expire)
- Remove `isExpired` getter
- Remove `timeRemaining` getter
- Remove `formattedTimeRemaining` getter
- Keep: `code`, `userId`, `userName`, `pushToken`

**Alternative:** Keep the model but set `expiresAt` to far future date (e.g., 100 years) for backward compatibility

---

### 2. Service Layer Changes

**File:** `lib/services/remote_pairing_service.dart`

**Current Behavior:**
- `generatePairingCode()` - Creates code with 10min expiration
- Stores in RTDB under `/pairing_codes/{code}`
- Timer-based cleanup of expired codes

**Changes Required:**
- Remove expiration logic from code generation
- Keep code in RTDB until:
  - User successfully pairs (delete code)
  - User generates new code (delete old code)
  - User leaves pairing screen (optional: delete code)
- Update `pairWithCode()` to handle non-expiring codes

**New Methods to Add:**
- `getOrGeneratePersistentCode()` - Returns existing code or generates new one
- `deletePairingCode(String code)` - Cleanup when pairing succeeds or user leaves

---

### 3. UI Changes

**File:** `lib/screens/pairing_screen.dart`

#### Tab Configuration
**Current:**
```dart
TabController(length: 2, vsync: this, initialIndex: 0) // QR Code default
```

**New:**
```dart
TabController(length: 2, vsync: this, initialIndex: 1) // Letter Code default
```

**Tab Labels:**
- Tab 0: "QR Code" (was "In Person")
- Tab 1: "Letter Code" (was "Remote")

#### State Management Changes

**Remove:**
- `_isWaitingForPartner` state
- `_buildWaitingScreen()` widget
- `_buildRemoteChoiceScreen()` widget (Generate vs Enter choice)
- Countdown timer for expiration

**Keep:**
- `_generatedCode` - Store persistent code
- `_isGeneratingCode` - Loading state during generation
- `_isVerifyingCode` - Loading state during verification
- `_buildCodeDisplayScreen()` - Modify to show new layout

**Add:**
- Auto-generate code on tab load (or first time user opens Letter Code tab)
- Tap-to-copy on code display box

#### New "Letter Code" Tab Layout

**Structure:**
```
Column
├─ Card: "I want to invite [Partner]"
│  ├─ Row: "Your code:" + "Tap to copy" hint
│  ├─ GestureDetector (tap to copy)
│  │  └─ Code Display Box (WKR-8BK)
│  └─ [No expiration text]
├─ "Share your invite code" button
├─ Divider with "or" circle
└─ Card: "I have a code from [Partner]"
   ├─ "Partner's code" label
   ├─ 6 input boxes with auto-advance
   └─ "Pair now" button
```

**Behavior:**
- When tab opens: Check if code exists, if not generate one
- Tap code box: Copy to clipboard + visual feedback
- Share button: Use existing `Share.share()` but remove expiration message
- Input boxes: Use existing auto-advance logic from dialog
- Pair now: Call existing `_verifyCode()` method

---

### 4. Backend Changes

**File:** `functions/index.js`

**Current Cloud Functions:**
- `sendReminder`
- `sendPoke`
- `sendPairingConfirmation`
- (Pairing code verification likely handled client-side via RTDB)

**Changes Needed:**
- If using cloud function for code generation: Remove expiration logic
- Keep RTDB structure same: `/pairing_codes/{code}`
- Consider adding cleanup function to remove codes older than X days (e.g., 30 days) to prevent database bloat

**RTDB Structure (Unchanged):**
```json
{
  "pairing_codes": {
    "WKR8BK": {
      "userId": "user123",
      "userName": "Alice",
      "pushToken": "fcm_token_here",
      "createdAt": 1234567890
    }
  }
}
```

**File:** `database.rules.json`

**Current Rules:**
- Allow read/write to `/pairing_codes/{code}` with expiration checks

**Changes Needed:**
- Remove expiration-based rules
- Keep authentication rules (if any)
- Consider adding timestamp-based cleanup rules

---

## Implementation Steps

### Phase 1: Data Layer (Non-Breaking Changes)
1. Update `PairingCode` model to make expiration optional
2. Update `RemotePairingService` to support non-expiring codes
3. Add `getOrGeneratePersistentCode()` method
4. Test that existing QR code pairing still works

### Phase 2: UI Updates
5. Update tab labels ("QR Code", "Letter Code")
6. Change default tab to Letter Code (index 1)
7. Remove waiting screen and choice screen
8. Build new two-card layout in `_buildRemoteTab()`
9. Move input boxes from dialog to bottom card
10. Add tap-to-copy gesture on code display
11. Update share message to remove expiration text

### Phase 3: Behavior & State Management
12. Auto-generate code when Letter Code tab opens
13. Remove countdown timer logic
14. Update `_verifyCode()` to work from inline inputs instead of dialog
15. Add code cleanup on successful pairing
16. (Optional) Add code cleanup when user leaves pairing screen

### Phase 4: Backend Cleanup
17. Update RTDB rules to remove expiration checks
18. Consider adding periodic cleanup cloud function
19. Test pairing flow end-to-end

### Phase 5: Testing
20. Test code generation and persistence
21. Test copy-to-clipboard functionality
22. Test share functionality
23. Test code entry and pairing
24. Test switching between QR Code and Letter Code tabs
25. Test pairing success flow
26. Test error handling (invalid code, network errors)

---

## Edge Cases to Handle

### Code Persistence
- **Q:** What happens if user generates code, closes app, comes back?
- **A:** Code should persist in RTDB, fetch on app restart

### Multiple Devices
- **Q:** What if user opens pairing screen on two devices?
- **A:** Each device gets its own code (tied to `userId` + `pushToken`)

### Code Conflicts
- **Q:** What if generated code already exists in RTDB?
- **A:** Regenerate until unique (existing behavior)

### Cleanup Strategy
- **Q:** When to delete codes from RTDB?
- **A:**
  - On successful pairing (both users' codes deleted)
  - On new code generation (old code deleted)
  - Optional: Periodic cleanup of codes >30 days old

### Network Failures
- **Q:** What if code generation fails?
- **A:** Show error, allow retry button

---

## Migration Considerations

### Backward Compatibility
- Existing codes in RTDB with `expiresAt` field will continue to work
- New codes won't have `expiresAt` field
- Code cleanup logic should handle both formats

### User Impact
- **Low impact:** Users don't lose any functionality
- **Improvement:** Simpler flow, no pressure to pair within 10 minutes
- **No data migration needed:** Old codes can expire naturally or be cleaned up

---

## Files to Modify

### Must Change
- [ ] `lib/screens/pairing_screen.dart` - UI overhaul
- [ ] `lib/services/remote_pairing_service.dart` - Remove expiration logic
- [ ] `lib/models/pairing_code.dart` - Make expiration optional

### May Change
- [ ] `database.rules.json` - Remove expiration rules (if present)
- [ ] `functions/index.js` - Add cleanup function (optional)

### No Changes Needed
- `lib/services/notification_service.dart` - Pairing confirmation flow stays same
- `lib/models/reminder.dart` - Partner model unchanged
- `lib/services/storage_service.dart` - Partner storage unchanged

---

## Open Questions

1. **Partner Name Display:** Currently hardcoded to "Taija" in mockup. Should we:
   - Use actual partner name from storage if exists?
   - Use "your partner" as generic placeholder?
   - Allow user to see their own name in "I want to invite [My Name]"?

2. **Code Generation Timing:** When should code be generated?
   - On first tab open?
   - On pairing screen load?
   - Lazy load (only when user switches to Letter Code tab)?

3. **Code Cleanup:** Should we delete code when user leaves pairing screen?
   - Yes: Cleaner database, new code each session
   - No: Same code persists across sessions, easier to share later

4. **Copy Feedback:** How to show code was copied?
   - Flash animation on code display?
   - Snackbar message?
   - Brief color change (shown in mockup)?

5. **QR Code Tab:** Keep existing "In Person" tab UI exactly as-is?
   - Yes: Only rename tab, no functional changes
   - Modify: Update styling to match new cards?

---

## Success Criteria

- ✅ Letter Code tab is default on pairing screen load
- ✅ Code displays on single line without expiration timer
- ✅ Tap code box to copy works
- ✅ Share button opens native share dialog
- ✅ 6-character input with auto-advance works
- ✅ Pairing succeeds with valid code
- ✅ Invalid code shows error message
- ✅ QR Code tab still works (renamed but functional)
- ✅ No console errors or warnings
- ✅ Codes don't expire

---

## Next Steps

1. **Review this plan** with team/stakeholder
2. **Answer open questions** above
3. **Approve mockup** design
4. **Begin implementation** following phases 1-5
5. **Test thoroughly** on both Android and iOS
6. **Update documentation** (ARCHITECTURE.md, SETUP.md)

---

**Notes:**
- Keep this document updated as implementation progresses
- Mark tasks complete with timestamps
- Document any deviations from plan
