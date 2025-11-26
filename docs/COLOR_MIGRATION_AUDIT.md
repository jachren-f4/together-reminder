# Color Migration Audit

Generated: Wed Nov 26 08:27:04 EET 2025

---

## Summary

| Type | Count |
|------|-------|
| `Colors.*` references | 737 |
| `Color(0x...)` hex values | 189 |
| `Color.fromRGBO/ARGB` calls | 4 |
| **Total** | 930 |

---

## Files with `Colors.*` References (by count)

| File | Count |
|------|-------|
| `screens/would_you_rather_results_screen.dart` | 53 |
| `widgets/linked_card.dart` | 32 |
| `widgets/debug/tabs/actions_tab.dart` | 32 |
| `screens/linked_game_screen.dart` | 32 |
| `widgets/quest_card.dart` | 26 |
| `screens/would_you_rather_screen.dart` | 26 |
| `screens/daily_pulse_results_screen.dart` | 25 |
| `screens/new_home_screen.dart` | 24 |
| `screens/daily_pulse_screen.dart` | 24 |
| `screens/speed_round_results_screen.dart` | 22 |
| `widgets/debug/tabs/sessions_tab.dart` | 20 |
| `screens/would_you_rather_intro_screen.dart` | 19 |
| `screens/word_ladder_game_screen.dart` | 19 |
| `screens/speed_round_intro_screen.dart` | 19 |
| `screens/linked_completion_screen.dart` | 18 |
| `widgets/debug/tabs/quests_tab.dart` | 17 |
| `widgets/debug/tabs/lp_sync_tab.dart` | 17 |
| `screens/activities_screen.dart` | 17 |
| `widgets/linked/answer_cell.dart` | 16 |
| `screens/word_ladder_completion_screen.dart` | 15 |
| `screens/memory_flip_game_screen.dart` | 15 |
| `screens/speed_round_screen.dart` | 14 |
| `screens/otp_verification_screen.dart` | 14 |
| `widgets/daily_quests_widget.dart` | 12 |
| `widgets/results_content/classic_quiz_results_content.dart` | 10 |
| `screens/quiz_results_screen.dart` | 10 |
| `screens/pairing_screen.dart` | 10 |
| `widgets/daily_pulse_widget.dart` | 9 |
| `screens/you_or_me_results_screen.dart` | 9 |
| `screens/auth_screen.dart` | 9 |
| `widgets/results_content/you_or_me_results_content.dart` | 8 |
| `widgets/linked/rack_tile.dart` | 8 |
| `widgets/debug/debug_menu.dart` | 8 |
| `screens/word_ladder_hub_screen.dart` | 8 |
| `widgets/poke_bottom_sheet.dart` | 7 |
| `screens/you_or_me_waiting_screen.dart` | 6 |
| `screens/you_or_me_intro_screen.dart` | 6 |
| `screens/you_or_me_game_screen.dart` | 6 |
| `screens/unified_results_screen.dart` | 6 |
| `widgets/results_content/affirmation_results_content.dart` | 5 |
| `widgets/linked/score_row.dart` | 5 |
| `widgets/linked/completion_badge.dart` | 5 |
| `widgets/debug_quest_dialog.dart` | 5 |
| `widgets/debug/tabs/overview_tab.dart` | 5 |
| `screens/settings_screen.dart` | 5 |
| `screens/affirmation_results_screen.dart` | 5 |
| `widgets/poke_response_dialog.dart` | 4 |
| `widgets/linked/progress_ring.dart` | 4 |
| `widgets/linked/clue_cell.dart` | 4 |
| `widgets/debug/components/debug_copy_button.dart` | 4 |
| `widgets/linked/partner_badge.dart` | 3 |
| `widgets/five_point_scale.dart` | 3 |
| `widgets/debug/components/debug_status_indicator.dart` | 3 |
| `services/poke_animation_service.dart` | 3 |
| `widgets/linked/countdown_timer.dart` | 2 |
| `widgets/foreground_notification_banner.dart` | 2 |
| `widgets/debug/components/debug_section_card.dart` | 2 |
| `services/clipboard_service.dart` | 2 |
| `screens/send_reminder_screen.dart` | 2 |
| `screens/quiz_waiting_screen.dart` | 2 |
| `screens/inbox_screen.dart` | 2 |
| `screens/debug/data_validation_screen.dart` | 2 |
| `screens/affirmation_intro_screen.dart` | 2 |
| `screens/activity_hub_screen.dart` | 2 |
| `widgets/quest_carousel.dart` | 1 |
| `widgets/match_reveal_dialog.dart` | 1 |
| `widgets/linked/void_cell.dart` | 1 |
| `theme/app_theme.dart` | 1 |
| `screens/unified_waiting_screen.dart` | 1 |
| `screens/quiz_question_screen.dart` | 1 |

---

## Files with `Color(0x...)` References (by count)

| File | Count |
|------|-------|
| `config/brand/brand_registry.dart` | 46 |
| `screens/linked_game_screen.dart` | 37 |
| `screens/you_or_me_game_screen.dart` | 18 |
| `screens/you_or_me_results_screen.dart` | 16 |
| `widgets/results_content/you_or_me_results_content.dart` | 12 |
| `widgets/quest_card.dart` | 7 |
| `screens/you_or_me_waiting_screen.dart` | 7 |
| `screens/profile_screen.dart` | 7 |
| `widgets/linked/answer_cell.dart` | 6 |
| `screens/pairing_screen.dart` | 6 |
| `screens/activity_hub_screen.dart` | 5 |
| `models/arena.dart` | 5 |
| `widgets/linked/void_cell.dart` | 3 |
| `widgets/linked/rack_tile.dart` | 3 |
| `widgets/linked/clue_cell.dart` | 3 |
| `screens/new_home_screen.dart` | 2 |
| `widgets/quest_carousel.dart` | 1 |
| `widgets/linked/partner_badge.dart` | 1 |
| `widgets/debug/debug_menu.dart` | 1 |
| `widgets/daily_quests_widget.dart` | 1 |
| `widgets/daily_pulse_widget.dart` | 1 |
| `screens/daily_pulse_screen.dart` | 1 |

---

## High Priority Files (>10 references)

These files should be migrated first:

- [ ] `screens/would_you_rather_results_screen.dart` (53 refs)
- [ ] `widgets/linked_card.dart` (32 refs)
- [ ] `widgets/debug/tabs/actions_tab.dart` (32 refs)
- [ ] `screens/linked_game_screen.dart` (32 refs)
- [ ] `widgets/quest_card.dart` (26 refs)
- [ ] `screens/would_you_rather_screen.dart` (26 refs)
- [ ] `screens/daily_pulse_results_screen.dart` (25 refs)
- [ ] `screens/new_home_screen.dart` (24 refs)
- [ ] `screens/daily_pulse_screen.dart` (24 refs)
- [ ] `screens/speed_round_results_screen.dart` (22 refs)
- [ ] `widgets/debug/tabs/sessions_tab.dart` (20 refs)
- [ ] `screens/would_you_rather_intro_screen.dart` (19 refs)
- [ ] `screens/word_ladder_game_screen.dart` (19 refs)
- [ ] `screens/speed_round_intro_screen.dart` (19 refs)
- [ ] `screens/linked_completion_screen.dart` (18 refs)
- [ ] `widgets/debug/tabs/quests_tab.dart` (17 refs)
- [ ] `widgets/debug/tabs/lp_sync_tab.dart` (17 refs)
- [ ] `screens/activities_screen.dart` (17 refs)
- [ ] `widgets/linked/answer_cell.dart` (16 refs)
- [ ] `screens/word_ladder_completion_screen.dart` (15 refs)
- [ ] `screens/memory_flip_game_screen.dart` (15 refs)
- [ ] `screens/speed_round_screen.dart` (14 refs)
- [ ] `screens/otp_verification_screen.dart` (14 refs)
- [ ] `widgets/daily_quests_widget.dart` (12 refs)

---

## Exclusions (Debug/Test files)

These files can be migrated later or left as-is:

- `widgets/debug/tabs/overview_tab.dart` (5 refs)
- `widgets/debug/tabs/actions_tab.dart` (32 refs)
- `widgets/debug/tabs/lp_sync_tab.dart` (17 refs)
- `widgets/debug/tabs/sessions_tab.dart` (20 refs)
- `widgets/debug/tabs/quests_tab.dart` (17 refs)
- `widgets/debug/components/debug_status_indicator.dart` (3 refs)
- `widgets/debug/components/debug_copy_button.dart` (4 refs)
- `widgets/debug/components/debug_section_card.dart` (2 refs)
- `widgets/debug/debug_menu.dart` (8 refs)

---

## Migration Guide

Replace hardcoded colors with semantic colors from BrandLoader:

```dart
// Before
color: Colors.black
color: Color(0xFF1A1A1A)

// After
color: BrandLoader().colors.textPrimary
color: AppTheme.textPrimary
```

### Color Mapping Reference

| Old | New |
|-----|-----|
| `Colors.black` | `BrandLoader().colors.textPrimary` |
| `Colors.white` | `BrandLoader().colors.surface` or `.textOnPrimary` |
| `Colors.grey` | `BrandLoader().colors.textSecondary` |
| `Colors.red` | `BrandLoader().colors.error` |
| `Colors.green` | `BrandLoader().colors.success` |
| `Colors.orange` | `BrandLoader().colors.warning` |
| `Colors.blue` | `BrandLoader().colors.info` |
| `Colors.transparent` | Keep as-is (universal) |
