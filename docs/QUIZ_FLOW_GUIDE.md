# Quiz Flow Guide - Complete & Next Button

This document explains what happens when you press the "Complete & Next" button in the debug menu, and shows the first 10 button presses for each game type.

## Overview

The app has **3 daily quest slots** that appear each day:
- **Slot 0**: Classic Quiz
- **Slot 1**: Affirmation Quiz
- **Slot 2**: You-or-Me

Each game type has **independent branch progression** that cycles through 5 branches:

| Branch Index | Branch Name | Type |
|--------------|-------------|------|
| 0 | lighthearted | Playful (40%) |
| 1 | playful | Playful (40%) |
| 2 | connection | Deep (60%) |
| 3 | attachment | Deep (60%) |
| 4 | growth | Deep (60%) |

## Branch Progression Formula

```
currentBranch = totalCompletions % 5
```

Each completion advances to the next branch, cycling back to `lighthearted` after `growth`.

---

## First 10 "Complete & Next" Button Presses

### Starting State (Fresh Install)
All game types start at:
- `totalCompletions = 0`
- `currentBranch = 0` (lighthearted)

---

### Classic Quiz Progression

| Press # | Branch | Quiz File | First Question (verify with this) |
|---------|--------|-----------|-----------------------------------|
| 1 | lighthearted | quiz_001 | "Do I prefer sweet or savory snacks?" |
| 2 | playful | quiz_001 | "After a long week, I prefer to recharge by..." |
| 3 | connection | quiz_001 | "What makes me feel most loved by you?" |
| 4 | attachment | quiz_001 | "When we're apart, how do I typically feel?" |
| 5 | growth | quiz_001 | "What's my biggest personal goal right now?" |
| 6 | lighthearted | quiz_002 | "How do I prefer to receive news?" |
| 7 | playful | quiz_002 | "When faced with a new opportunity, my first instinct is to..." |
| 8 | connection | quiz_002 | "What topic do I wish we talked about more?" |
| 9 | attachment | quiz_002 | "When we disagree, what's my typical pattern?" |
| 10 | growth | quiz_002 | "What's my biggest dream for our future together?" |

---

### Affirmation Quiz Progression

| Press # | Branch | Quiz File | First Statement (verify with this) |
|---------|--------|-----------|-------------------------------------|
| 1 | lighthearted | affirmation_001 | "I prefer quiet mornings over busy ones" |
| 2 | playful | affirmation_001 | "I consider myself more adventurous than cautious" |
| 3 | connection | affirmation_001 | "I feel emotionally safe sharing my deepest thoughts with my partner" |
| 4 | attachment | affirmation_001 | "I trust that my partner will be there when I need them" |
| 5 | growth | affirmation_001 | "This relationship has helped me become a better person" |
| 6 | lighthearted | affirmation_002 | "I enjoy sleeping in on weekends" |
| 7 | playful | affirmation_002 | "I make decisions based more on logic than feelings" |
| 8 | connection | affirmation_002 | "My partner notices the small things that matter to me" |
| 9 | attachment | affirmation_002 | "I can count on my partner to keep their promises" |
| 10 | growth | affirmation_002 | "My partner genuinely supports my goals and dreams" |

---

### You-or-Me Progression

| Press # | Branch | Quiz File | First Question (verify with this) |
|---------|--------|-----------|-----------------------------------|
| 1 | lighthearted | quiz_001 | "Who is more likely to try a new food without asking what's in it" |
| 2 | playful | quiz_001 | "Who is more likely to laugh at their own jokes" |
| 3 | connection | quiz_001 | "Who is more expressive with their feelings" |
| 4 | attachment | quiz_001 | "Who needs more reassurance that everything is okay" |
| 5 | growth | quiz_001 | "Who has grown more in how they communicate" |
| 6 | lighthearted | quiz_002 | "Who is more likely to be the life of the party" |
| 7 | playful | quiz_002 | "Who would be more excited about finding a secret door" |
| 8 | connection | quiz_002 | "Who finds it easier to open up about fears and insecurities" |
| 9 | attachment | quiz_002 | "Who finds it easier to trust without needing proof" |
| 10 | growth | quiz_002 | "Who thinks more about long-term plans" |

---

## Complete Flow: All 3 Daily Quests

When you complete all 3 daily quests (or press "Complete & Next All"), this happens:

### Day 1 (Starting Fresh)

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | lighthearted | quiz_001 | "Do I prefer sweet or savory snacks?" |
| 1 | Affirmation | lighthearted | affirmation_001 | "I prefer quiet mornings over busy ones" |
| 2 | You-or-Me | lighthearted | quiz_001 | "Who is more likely to try a new food..." |

After completion: All advance to `playful`

### Day 2

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | playful | quiz_001 | "After a long week, I prefer to recharge by..." |
| 1 | Affirmation | playful | affirmation_001 | "I consider myself more adventurous than cautious" |
| 2 | You-or-Me | playful | quiz_001 | "Who is more likely to laugh at their own jokes" |

After completion: All advance to `connection`

### Day 3

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | connection | quiz_001 | "What makes me feel most loved by you?" |
| 1 | Affirmation | connection | affirmation_001 | "I feel emotionally safe sharing my deepest thoughts..." |
| 2 | You-or-Me | connection | quiz_001 | "Who is more expressive with their feelings" |

After completion: All advance to `attachment`

### Day 4

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | attachment | quiz_001 | "When we're apart, how do I typically feel?" |
| 1 | Affirmation | attachment | affirmation_001 | "I trust that my partner will be there when I need them" |
| 2 | You-or-Me | attachment | quiz_001 | "Who needs more reassurance that everything is okay" |

After completion: All advance to `growth`

### Day 5

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | growth | quiz_001 | "What's my biggest personal goal right now?" |
| 1 | Affirmation | growth | affirmation_001 | "This relationship has helped me become a better person" |
| 2 | You-or-Me | growth | quiz_001 | "Who has grown more in how they communicate" |

After completion: All cycle back to `lighthearted`, move to quiz_002

### Day 6 (Second Cycle Begins)

| Quest Slot | Game Type | Branch | Quiz File | First Question |
|------------|-----------|--------|-----------|----------------|
| 0 | Classic Quiz | lighthearted | quiz_002 | "How do I prefer to receive news?" |
| 1 | Affirmation | lighthearted | affirmation_002 | "I enjoy sleeping in on weekends" |
| 2 | You-or-Me | lighthearted | quiz_002 | "Who is more likely to be the life of the party" |

---

## Full Content Cycle

With 12 quizzes per branch and 5 branches:
- **60 completions** = full cycle through all content for one game type
- **180 completions** = full cycle through all content for all 3 game types
- At current rate (1 per day per type): **60 days** to see all content

---

## Branch Distribution Over Time

| Days | Lighthearted | Playful | Connection | Attachment | Growth |
|------|--------------|---------|------------|------------|--------|
| 1-5 | 1 | 1 | 1 | 1 | 1 |
| 6-10 | 2 | 2 | 2 | 2 | 2 |
| 11-15 | 3 | 3 | 3 | 3 | 3 |
| ... | ... | ... | ... | ... | ... |
| 56-60 | 12 | 12 | 12 | 12 | 12 |

**Playful branches (lighthearted + playful)**: 40% of content
**Deep branches (connection + attachment + growth)**: 60% of content

---

## Key Files

| File | Purpose |
|------|---------|
| `app/lib/models/branch_progression_state.dart` | Branch config & progression logic |
| `app/lib/services/branch_progression_service.dart` | Branch state management |
| `app/lib/services/quest_type_manager.dart` | Daily quest generation |
| `app/lib/widgets/debug/tabs/actions_tab.dart` | Debug "Complete & Next" button |
| `api/data/puzzles/{game-type}/{branch}/quiz-order.json` | Quiz ordering per branch |

---

## What "Complete & Next" Does

1. **Calls API** `/api/dev/complete-games` - Server creates matches and awards LP
2. **Marks quests completed** - Updates local Hive storage
3. **Advances branch** - Calls `branchProgressionService.completeActivity()`
4. **Syncs LP** - Fetches updated LP from server

The next day's quests will be generated from the new branch.
