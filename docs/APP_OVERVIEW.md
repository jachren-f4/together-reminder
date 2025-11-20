# TogetherRemind - App Overview

## What It Does

TogetherRemind is a **couples connection app** that helps partners stay connected through daily activities, quizzes, and gentle reminders. Partners pair their devices and engage in fun relationship-building activities together, earning Love Points along the way.

---

## Core Features

| Feature | Description |
|---------|-------------|
| **Device Pairing** | Connect two devices via QR code or remote pairing code |
| **Daily Quests** | 3 daily activities synced between partners |
| **Love Points (LP)** | Reward system for completing activities together |
| **Pokes** | Send playful nudges to your partner |
| **Reminders** | Send custom reminders to your partner |

---

## Screen Reference

### Onboarding & Auth
| Screen | Purpose |
|--------|---------|
| `onboarding_screen` | First-time user introduction |
| `auth_screen` | Phone number authentication |
| `otp_verification_screen` | OTP code entry |
| `pairing_screen` | QR code + remote code pairing |

### Main Navigation
| Screen | Purpose |
|--------|---------|
| `new_home_screen` | Main dashboard with daily quests, LP counter, greeting |
| `home_screen` | Legacy home screen |
| `inbox_screen` | Received pokes and reminders |
| `profile_screen` | User profile and stats |
| `settings_screen` | App settings and preferences |
| `activity_hub_screen` | Browse all available activities |
| `activities_screen` | Activity selection grid |

### Quiz Activities
| Screen | Purpose |
|--------|---------|
| `quiz_intro_screen` | Classic quiz introduction |
| `quiz_question_screen` | Answer quiz questions |
| `quiz_waiting_screen` | Wait for partner to complete |
| `quiz_results_screen` | Compare answers with partner |

### Affirmation Quizzes
| Screen | Purpose |
|--------|---------|
| `affirmation_intro_screen` | Affirmation quiz introduction |
| `affirmation_results_screen` | 5-point scale results visualization |

### Speed Round
| Screen | Purpose |
|--------|---------|
| `speed_round_intro_screen` | Timed quiz introduction |
| `speed_round_screen` | Fast-paced question answering |
| `speed_round_results_screen` | Speed round results |

### You or Me
| Screen | Purpose |
|--------|---------|
| `you_or_me_intro_screen` | "You or Me" game introduction |
| `you_or_me_game_screen` | Choose who fits the description |
| `you_or_me_waiting_screen` | Wait for partner |
| `you_or_me_results_screen` | Compare choices |

### Would You Rather
| Screen | Purpose |
|--------|---------|
| `would_you_rather_intro_screen` | Game introduction |
| `would_you_rather_screen` | Choose between two options |
| `would_you_rather_results_screen` | See partner's choices |

### Word Ladder
| Screen | Purpose |
|--------|---------|
| `word_ladder_hub_screen` | Word ladder game hub |
| `word_ladder_game_screen` | Guess words changing one letter |
| `word_ladder_completion_screen` | Completion celebration |

### Memory Flip
| Screen | Purpose |
|--------|---------|
| `memory_flip_game_screen` | 4x4 card matching game |

### Daily Pulse
| Screen | Purpose |
|--------|---------|
| `daily_pulse_screen` | Daily mood/feeling check-in |
| `daily_pulse_results_screen` | Compare daily moods |

### Shared Components
| Screen | Purpose |
|--------|---------|
| `unified_waiting_screen` | Generic waiting for partner |
| `unified_results_screen` | Generic results display |
| `send_reminder_screen` | Compose and send reminders |

### Debug
| Screen | Purpose |
|--------|---------|
| `data_validation_screen` | Debug data validation tools |

---

## User Flow

```
Onboarding → Auth → Pairing → Home Screen
                                    ↓
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
              Daily Quests      Activities       Inbox
                    ↓               ↓               ↓
              Complete Quest   Play Games    View Pokes
                    ↓               ↓
              Earn Love Points  Results Screen
```

---

## Activity Types

1. **Classic Quiz** - Answer relationship questions, compare with partner
2. **Affirmation Quiz** - Rate statements on 5-point scale
3. **Speed Round** - Timed rapid-fire questions
4. **You or Me** - Who does this describe better?
5. **Would You Rather** - Choose between scenarios
6. **Word Ladder** - Word puzzle game
7. **Memory Flip** - Card matching game
8. **Daily Pulse** - Daily check-in

---

**Total Screens:** 37
