# Implementation Plan: "My Response Varies" Option for Classic Quiz

## Overview

Add a hardcoded 6th answer option to classic quiz questions that allows users to indicate their response varies too much by situation to pick a single answer. This acknowledges real human complexity while still providing therapeutic value.

## Design Mockup

See: `mockups/varies-option-exploration.html`

**Chosen approach: Option 3 (Text Link)**

The "varies" option will appear as a subtle text link below the 5 main answer cards:
```
or: My response varies too much to choose
```

This approach:
- Takes only ~30px vertical space (vs ~60px for a card)
- Works on iPhone 12 (smallest screen) without scrolling
- Visually signals it's a fallback, not a primary choice
- Doesn't compete with main options for attention

## Rationale

- Users may feel none of the 5 options truly represent them
- Forcing a "closest fit" can feel frustrating and reduce answer accuracy
- "My response varies" IS therapeutically meaningful:
  - Can indicate secure attachment (flexible, context-dependent responding)
  - Can indicate fearful-avoidant attachment (inconsistent patterns)
  - Shows self-awareness that behavior isn't fixed

## Scope

**In Scope:**
- Classic quiz only (personality/attachment questions)
- UI-only addition (not in quiz JSON files)
- Display in journal
- Handling in Us Profile calculations

**Out of Scope:**
- Affirmation quiz (picking what you want to hear - "varies" doesn't make sense)
- Welcome quiz (onboarding flow, keep simple)
- You or Me (binary choice by design)

---

## Implementation Details

### 1. Constants & Configuration

**File:** `app/lib/constants/quiz_constants.dart` (create if needed)

```dart
class QuizConstants {
  /// Index used for "My response varies" option
  static const int variesAnswerIndex = 5;

  /// Display text for varies option
  static const String variesAnswerText = "My response varies too much to choose";

  /// Short display text for tight spaces
  static const String variesAnswerShort = "Response varies";
}
```

### 2. Quiz Answer Screen UI

**File:** `app/lib/screens/quiz_match_game_screen.dart`

**Changes:**
- After rendering the 5 JSON-defined answer cards, add a text link for "varies"
- Style as subtle gray italic text to indicate it's a fallback
- Only show for classic quiz type, not affirmation

```dart
// In _buildAnswerOptions or equivalent:
Widget _buildAnswerOptions(List<String> choices) {
  return Column(
    children: [
      // Existing 5 choices from JSON (as cards)
      ...choices.asMap().entries.map((entry) =>
        _buildAnswerCard(entry.key, entry.value)
      ),

      // Add "varies" text link for classic quiz only
      if (_quizType == 'classic')
        _buildVariesLink(),
    ],
  );
}

Widget _buildVariesLink() {
  final isSelected = _selectedAnswer == QuizConstants.variesAnswerIndex;

  return GestureDetector(
    onTap: () => _selectAnswer(QuizConstants.variesAnswerIndex),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'or: ${QuizConstants.variesAnswerText}',
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: isSelected ? Colors.orange : Colors.grey[500],
          decoration: isSelected ? TextDecoration.underline : null,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
```

### 3. Answer Submission

**File:** `app/lib/services/quiz_service.dart` (or quiz submission logic)

**Changes:**
- Accept index 5 as valid answer
- No special encoding needed - just store as index 5

```dart
// Validation should allow 0-5 instead of 0-4
bool isValidAnswer(int index, String quizType) {
  if (quizType == 'classic') {
    return index >= 0 && index <= 5; // Allow varies option
  }
  return index >= 0 && index <= 4;
}
```

### 4. API Handling

**File:** `api/app/api/quiz/submit/route.ts` (or equivalent)

**Changes:**
- Accept answer index 5 in validation
- Store normally in `quiz_matches` table (JSONB array handles any integer)

```typescript
// Validation
const isValidAnswer = (index: number, quizType: string): boolean => {
  if (quizType === 'classic') {
    return index >= 0 && index <= 5;
  }
  return index >= 0 && index <= 4;
};
```

---

## Journal Integration

### 5. Journal Answer Display

**File:** `api/app/api/journal/quiz/[sessionId]/route.ts`

**Changes:**
- When translating answer index to text, handle index 5 specially

```typescript
function getAnswerText(answerIndex: number, choices: string[]): string {
  // Handle "varies" option
  if (answerIndex === 5) {
    return "My response varies too much to choose";
  }

  // Normal choice lookup
  return choices[answerIndex] ?? `Option ${answerIndex + 1}`;
}
```

### 6. Journal Alignment Display

**File:** `app/lib/widgets/journal/quiz_answer_card.dart`

**Changes:**
- Handle display when one or both partners selected "varies"
- Show appropriate badge/messaging

```dart
Widget _buildAlignmentBadge() {
  final userVaries = userAnswer == QuizConstants.variesAnswerIndex;
  final partnerVaries = partnerAnswer == QuizConstants.variesAnswerIndex;

  if (userVaries && partnerVaries) {
    return _badge("Both flexible", Colors.purple);
  } else if (userVaries || partnerVaries) {
    return _badge("One varies", Colors.blue);
  } else if (userAnswer == partnerAnswer) {
    return _badge("Aligned!", Colors.green);
  } else {
    return _badge("Different perspectives", Colors.orange);
  }
}
```

---

## Us Profile Integration

### 7. Dimension Calculation

**File:** `api/lib/us-profile/calculator.ts`

**Changes:**
- When processing poleMapping, treat index 5 as "neutral" (no contribution)
- Skip "varies" answers from dimension aggregation OR count as 0 weight

```typescript
function processDimensionAnswer(
  answerIndex: number,
  poleMapping: string[]
): number | null {
  // "Varies" option - skip from dimension calculation
  if (answerIndex === 5) {
    return null; // Skip this answer
  }

  const pole = poleMapping[answerIndex];
  if (pole === 'left') return -1;
  if (pole === 'right') return 1;
  return 0; // neutral
}

// In aggregation:
function calculateDimensionScore(answers: (number | null)[]): number {
  const validAnswers = answers.filter(a => a !== null);
  if (validAnswers.length === 0) return 0;
  return validAnswers.reduce((a, b) => a + b, 0) / validAnswers.length;
}
```

### 8. Discovery Handling

**File:** `api/lib/us-profile/calculator.ts`

**Changes:**
- Still create discoveries when answers differ
- Add flag or note when one answer is "varies"

```typescript
interface Discovery {
  questionText: string;
  user1Answer: string;
  user2Answer: string;
  user1Varies: boolean;  // NEW
  user2Varies: boolean;  // NEW
  stakes: 'high' | 'medium' | 'light';
  // ...
}

// When creating discovery:
const discovery: Discovery = {
  // ...
  user1Varies: user1AnswerIndex === 5,
  user2Varies: user2AnswerIndex === 5,
};
```

### 9. Love Language & Values

**File:** `api/lib/us-profile/calculator.ts`

**Changes:**
- Skip "varies" answers from love language tallying
- Skip from values alignment calculation

```typescript
// Skip varies from love language:
if (answerIndex !== 5 && metadata.loveLanguage) {
  const language = metadata.languageMapping[answerIndex];
  if (language) {
    languageCounts[language]++;
  }
}

// Skip varies from values:
if (answerIndex !== 5 && metadata.valueCategory) {
  // Process value alignment...
}
```

---

## UI/UX Considerations

### 10. Visual Design (Text Link Approach)

The "varies" text link should be:
- Positioned directly below the 5 answer cards
- Styled in gray italic text (~14px)
- Prefixed with "or:" to indicate it's an alternative
- Shows selection state (orange color, underline) when tapped

```
[Answer Card A]
[Answer Card B]
[Answer Card C]
[Answer Card D]
[Answer Card E]

or: My response varies too much to choose

[Next Question Button]
```

This signals it's a fallback option, not competing with primary choices.

### 11. Result Insights

When showing Us Profile insights:
- If a user frequently picks "varies", could show insight: "You're highly context-dependent in your responses, showing flexibility and self-awareness"
- Track "varies" count per user for potential insights

---

## Testing Checklist

- [ ] Classic quiz shows 6th option
- [ ] Affirmation quiz does NOT show 6th option
- [ ] Answer index 5 submits successfully
- [ ] Answer stored correctly in quiz_matches
- [ ] Journal displays "varies" answer text correctly
- [ ] Journal shows appropriate alignment badge when varies selected
- [ ] Us Profile dimensions skip/neutralize varies answers
- [ ] Discoveries still created when one answer is varies
- [ ] Love language calculation skips varies answers
- [ ] Values alignment skips varies answers
- [ ] No errors when both partners select varies on same question

---

## Files to Modify

| File | Change |
|------|--------|
| `app/lib/constants/quiz_constants.dart` | Create with varies constants |
| `app/lib/screens/quiz_match_game_screen.dart` | Add 6th option UI |
| `app/lib/services/quiz_service.dart` | Accept index 5 validation |
| `api/app/api/quiz/submit/route.ts` | Accept index 5 in API |
| `api/app/api/journal/quiz/[sessionId]/route.ts` | Handle varies text display |
| `app/lib/widgets/journal/quiz_answer_card.dart` | Handle varies alignment |
| `api/lib/us-profile/calculator.ts` | Skip varies in dimension/language/value calc |

---

## Open Questions

1. **Frequency limit?** Should we warn users if they're selecting "varies" too often? (e.g., "Try to pick the closest match when possible")

2. **Compatibility scoring?** When calculating quiz match compatibility %, how should "varies" be handled?
   - Option A: Skip from calculation entirely
   - Option B: Count as partial match with any answer
   - Option C: Count as mismatch
   - **Recommendation:** Option A (skip) - neither penalize nor reward

3. **Progressive reveal?** Should "varies" answers count toward the quiz count for unlocking Us Profile dimensions?
   - **Recommendation:** Yes, the quiz was completed even if some answers were "varies"

4. **Partner notification?** Should we tell partners when the other selected "varies"?
   - **Recommendation:** Only in journal detail view, not as a notification

---

## Implementation Order

1. **Phase 1: Core functionality**
   - Add constants
   - Add UI to quiz screen
   - Update answer submission/validation (app + API)

2. **Phase 2: Journal integration**
   - Update answer text display
   - Update alignment badge logic

3. **Phase 3: Us Profile integration**
   - Update dimension calculation
   - Update discovery handling
   - Update love language/values

4. **Phase 4: Polish**
   - Visual styling refinement
   - Edge case testing
   - Optional: "varies" frequency insights
