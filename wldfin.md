# 💕 TogetherRemind – Word Ladder Duet (MVP Game Spec + Parallel Play Flow + Finnish Word Support)

## 🎯 Overview
**Word Ladder Duet** is an asynchronous, cooperative mini-game where a couple works together to transform one word into another by changing a single letter at a time, forming valid words at each step.  
Each solved ladder adds to their shared **Love Points** total and contributes to their lifelong leaderboard progression.

The game emphasizes light, thoughtful interaction — quick enough for busy lives, yet emotionally connective when shared.

---

## 🧩 Core Gameplay Loop

### Objective
Transform the **start word** into the **end word**, one letter at a time, ensuring every intermediate word is valid.

**Example:**
```
LOVE → LONE → LINE → LIFE
```

Each valid transformation:
- Changes exactly one letter.
- Must form a real word in the chosen language.
- Cannot repeat any previous word.

---

### Turn Structure
1. **Partner A’s Turn**  
   - Views current ladder and inputs a valid new word.  
   - If valid, the move is recorded and displayed for both players.  
   - Partner B receives a gentle notification:  
     > “Your partner made a move! See if you can get closer to the goal 💕.”

2. **Partner B’s Turn**  
   - Continues the chain by changing one letter.  
   - Turn alternates asynchronously — no need for simultaneous play.

3. **Completion**  
   - When the end word is reached, both see a shared completion screen with Love Point rewards and a short celebratory animation.  
   - Example message:  
     > “You reached LIFE together! +30 Love Points ❤️”

---

## 💫 Parallel Layers of Play

To prevent downtime between turns and keep engagement high, multiple **active ladders** can exist simultaneously.

### Design Rules
- Up to **three active ladders** per couple.  
- Each ladder has its own word pair and progress chain.  
- Players can freely switch between active ladders while waiting for their partner’s turn.  
- Completing a ladder unlocks a new one automatically from the daily pool.  

### Benefits
- Always something available to play.  
- Keeps emotional rhythm consistent despite asynchronous play.  
- Encourages light, daily habit use without pressure.

---

## 💖 Rewards & Scoring

| Action | Reward |
|--------|--------|
| Valid word step | +10 Love Points |
| Completing a ladder | +30 Love Points |
| Invalid word | −2 Love Points |
| Finishing under a move target | Bonus +10 Love Points |

**Progress Floors:**  
At 1000, 2000, 3000 Love Points, the couple cannot drop below that floor even after future losses.

**Leaderboard:**  
Love Points accumulate indefinitely across all puzzles. Couples can view lifetime totals and soft rankings among others.

---

## 🌼 Aesthetic & Tone

- Minimal, modern UI matching TogetherRemind’s soft color palette.  
- Each move shows smooth, calm animations (letter morphs, glowing transitions).  
- Completion screen reveals a short uplifting quote or message themed around connection, trust, or growth.  
- Push notifications use warm, human language rather than gamified urgency.

---

## 🕰 Session Design

- Each move takes only a few seconds.  
- Typical ladder length: **3–6 steps**.  
- Daily ladders reset at midnight local time.  
- Average engagement goal: **2–3 sessions per day**, lasting 1–3 minutes each.

---

## 🔔 Notifications

- “Your partner just made a move 💌”  
- “A new daily ladder is ready to climb together!”  
- “You’re one word away from the goal ❤️”  
- “Great teamwork! You’ve earned 30 Love Points!”

Notifications should be emotionally positive, never nagging.

---

## 🪴 Future Enhancements

- **Custom Word Mode**: One partner sets start and end words.  
- **Themed Packs**: e.g., “Adventure Words,” “Affection Words.”  
- **Language Variants**: Finnish or multilingual ladders later.  
- **Seasonal Leaderboards**: Monthly resets with cosmetic rewards.

---

## 🇫🇮 Finnish Word Support (Localization Lite)

### Purpose
Add a secondary **Finnish word dataset** to allow players to switch between English and Finnish ladders, without localizing the entire UI.  
All menus, notifications, and UI text remain in English for now.

---

### Implementation Plan

#### 1. Word Lists
- Two static word JSON files stored in the app bundle or Firestore:
  - `/words/en.json`
  - `/words/fi.json`
- Each organized by word length (4–6 letters typical):
  ```json
  {
    "4": ["love", "life", "hope", "home"],
    "5": ["trust", "light"],
    "6": ["future", "honest"]
  }
  ```

- Finnish example:
  ```json
  {
    "4": ["rata", "sana", "kala", "loma"],
    "5": ["rauta", "kukka"],
    "6": ["taivas", "taito"]
  }
  ```

#### 2. Word Validation
- Word validity check runs against the current locale’s dictionary.
- If `language = fi`, use Finnish dataset for validation and ladder generation.

#### 3. Word Pair Generation
- For MVP, use manually curated start/end pairs stored in a JSON list:
  ```json
  {
    "fi_pairs": [
      { "start": "sana", "end": "talo" },
      { "start": "kala", "end": "loma" },
      { "start": "valo", "end": "palo" }
    ]
  }
  ```
- Later: auto-generate Finnish pairs using a Levenshtein distance script (difference of 3–5 letters).

#### 4. Language Toggle
- Simple in-app toggle (⚙️ Settings → Language → English / Finnish).  
- Default: English.  
- Switching language resets the ladder pool and word validation source.

---

### Benefits
- Adds immediate replay value for Finnish players.  
- Tests the multilingual structure early with low overhead.  
- Allows collecting engagement metrics by language preference.  
- Builds foundation for future multilingual expansion (Swedish, German, etc.).

---

### Constraints
- Finnish morphology makes long words complex; restrict ladders to 4–6 letters.  
- No UI text translation yet (only word data changes).  
- Quote database remains English-only in MVP.

---

### Development Effort Estimate
| Task | Effort | Description |
|------|--------|-------------|
| Prepare Finnish word list | 1–2 days | Extract + clean 5k–10k valid 4–6 letter Finnish words |
| Implement validation toggle | 0.5 day | Switch dictionary reference based on locale |
| Add Finnish word pairs | 1 day | Hand-curate ~30 pairs for testing |
| QA testing | 1–2 days | Ensure word checks and ladders generate correctly |

✅ **Total:** ~3–5 developer days

---

## 🧭 Design Goals Recap
- Lightweight, romantic asynchronous play.  
- Continuous engagement through **parallel ladders**.  
- Early proof of concept for **multilingual word datasets** (English + Finnish).  
- Foundation for future language expansions with minimal UI complexity.

---

# 🌙 Parallel Play Flow – Couple’s Daily Experience

## 1. Morning (Soft Start)
- Partner A opens TogetherRemind and sees the daily ladders.  
- Solves one move in Ladder #1 before breakfast.  
- The app sends a soft notification to Partner B:  
  > “Morning word from your partner ☀️. Can you make it closer to the goal?”

---

## 2. Midday (Light Engagement)
- Partner B takes a short break and continues Ladder #1.  
- They also peek at Ladder #2 or start a fresh one if available.  
- The app subtly tracks both ladders’ progress on a shared progress ring.  

---

## 3. Evening (Connection Moment)
- Both partners have multiple ladders mid-progress.  
- One may finish Ladder #2, triggering a shared quote:  
  > “You’ve turned words into connection. +30 Love Points.”  
- They might switch to Ladder #3 for tomorrow’s continuation.  

---

## 4. Meta-Layer Integration
- Word Ladder Duet lives under the **Play** tab beside other TogetherRemind features (Reminders, Alarms, Leaderboard).  
- Couples can check:
  - Current active ladders (1–3).  
  - Lifetime Love Points and progress floors.  
  - Partner’s last activity (timestamp + last played ladder).  
  - Emotional “Streaks” visualization for long-term motivation.

---

## 5. UX Anchors
| UX Element | Purpose |
|-------------|----------|
| **Parallel Ladder Tabs** | Quick access to active puzzles; color-coded progress rings. |
| **Subtle Bloom Animation** | Reinforces progress and affection on ladder completion. |
| **Shared Feed** | Shows partner’s last actions (“Taija solved LINE → LIFE 2h ago”). |
| **Soft Sound Cues** | Optional — small chime when a partner finishes a move. |
| **End-of-Day Wrap-Up** | Auto-generated summary: “You made 5 moves today, earned 50 Love Points 🌸.” |

---

## 6. Emotional Design Summary
Parallel Layers turn short async tasks into a **shared ritual**.  
Instead of waiting, players always have a light next action — either continuing a different ladder or simply seeing their partner’s progress bloom across the day.

The goal is not to challenge but to **create gentle, continuous emotional presence** between two people through words.

---

*End of Document – Word Ladder Duet (MVP Spec + Parallel Play Flow + Finnish Word Support v2)*
