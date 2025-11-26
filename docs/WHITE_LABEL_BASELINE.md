# White-Label Baseline Documentation

> **Created:** 2025-11-26
> **Branch:** `feature/white-label`
> **Base commit:** `0769a2af` (docs: Add white-label architecture plan)

---

## Color Reference Counts (Before Migration)

| Type | Count | Notes |
|------|-------|-------|
| `Colors.*` | 737 | Material color constants |
| `Color(0x...)` | 151 | Hardcoded hex colors |
| `AppTheme.*` | 426 | Already using theme system |
| **Total hardcoded** | **888** | Need to migrate to BrandConfig |

---

## Top 20 Files Requiring Color Migration

| File | Colors.* Count | Priority |
|------|----------------|----------|
| `would_you_rather_results_screen.dart` | 53 | High |
| `linked_card.dart` | 32 | High (crossword) |
| `debug/tabs/actions_tab.dart` | 32 | Low (debug) |
| `linked_game_screen.dart` | 32 | High (crossword) |
| `quest_card.dart` | 26 | High |
| `would_you_rather_screen.dart` | 26 | High |
| `daily_pulse_results_screen.dart` | 25 | High |
| `new_home_screen.dart` | 24 | High |
| `daily_pulse_screen.dart` | 24 | High |
| `speed_round_results_screen.dart` | 22 | High |
| `debug/tabs/sessions_tab.dart` | 20 | Low (debug) |
| `would_you_rather_intro_screen.dart` | 19 | Medium |
| `word_ladder_game_screen.dart` | 19 | High |
| `speed_round_intro_screen.dart` | 19 | Medium |
| `linked_completion_screen.dart` | 18 | High (crossword) |
| `debug/tabs/quests_tab.dart` | 17 | Low (debug) |
| `debug/tabs/lp_sync_tab.dart` | 17 | Low (debug) |
| `activities_screen.dart` | 17 | High |
| `linked/answer_cell.dart` | 16 | High (crossword) |
| `word_ladder_completion_screen.dart` | 15 | High |

---

## Current Asset Structure

```
assets/
├── animations/      # Lottie animations
├── sounds/          # Audio files
├── data/            # JSON content (quizzes, questions)
├── words/           # Word lists for games
├── gfx/             # Graphics/icons
└── images/quests/   # Quest card images
```

**pubspec.yaml declarations:**
```yaml
assets:
  - assets/animations/
  - assets/sounds/
  - assets/data/
  - assets/words/
  - assets/gfx/
  - assets/images/quests/
```

---

## Crossword (Linked Game) Files

These files are part of the nearly-complete crossword feature and will need coordination:

| File | Colors.* | Notes |
|------|----------|-------|
| `lib/models/linked.dart` | - | Data model |
| `lib/models/linked.g.dart` | - | Generated Hive adapter |
| `lib/screens/linked_game_screen.dart` | 32 | Main game screen |
| `lib/screens/linked_completion_screen.dart` | 18 | Game completion |
| `lib/services/linked_service.dart` | - | Game logic |
| `lib/widgets/linked/linked_grid.dart` | - | Grid widget |
| `lib/widgets/linked/answer_cell.dart` | 16 | Cell rendering |
| `lib/widgets/linked_card.dart` | 32 | Activity card |

**Recent crossword commits:**
- `65eb2e73` - feat(linked): Implement Linked (arroword) puzzle game with 4 puzzles

---

## Files to Avoid Modifying on `main` Branch

While `feature/white-label` exists, avoid modifying these on main to prevent merge conflicts:

1. `lib/main.dart` - Initialization order changes
2. `lib/theme/app_theme.dart` - Color system changes
3. `lib/config/theme_config.dart` - Typography changes
4. `pubspec.yaml` - Asset path changes

**Exception:** If crossword needs urgent color fixes, coordinate with white-label branch.

---

## Baseline Screenshots

> **TODO:** Manually capture screenshots of these screens for visual regression testing:
>
> - [ ] Home screen
> - [ ] Activities screen
> - [ ] Inbox screen
> - [ ] Settings screen
> - [ ] Quiz flow (intro → questions → results)
> - [ ] Linked game (crossword)
> - [ ] Memory Flip game
> - [ ] Word Ladder game
> - [ ] Poke send/receive dialogs
> - [ ] Daily quests cards

Store screenshots in: `docs/baseline-screenshots/` (gitignored for size)

---

## Migration Checkpoints

Use these counts to verify migration progress:

```bash
# Check Colors.* remaining
grep -r "Colors\." lib/ --include="*.dart" | wc -l
# Target: 0 (except debug files)

# Check Color(0x...) remaining
grep -r "Color(0x" lib/ --include="*.dart" | wc -l
# Target: Minimal (only truly unique colors)

# Check AppTheme.* usage (should increase)
grep -r "AppTheme\." lib/ --include="*.dart" | wc -l
# Target: 888+ (all colors via theme)
```
