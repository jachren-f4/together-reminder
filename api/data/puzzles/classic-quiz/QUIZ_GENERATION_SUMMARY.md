# Classic Quiz Branches - Content Summary

## Overview
All Classic Quiz JSON files across five branches have been updated to the 4+1 choice model.

## 4+1 Choice Model
Each question now has:
- **4 distinct choices** stored in JSON
- **1 "It varies" option** hardcoded in the UI (not stored in JSON)

This reduces cognitive load while still giving users flexibility when no single answer fits.

## Branch Structure

### ATTACHMENT Branch (20 quizzes)
**Theme: Security, trust, independence vs togetherness, conflict patterns**

Files: `attachment/quiz_001.json` through `attachment/quiz_020.json`

Topics covered:
- Security needs and what makes us feel safe
- Reassurance patterns and comfort-seeking
- Independence vs togetherness balance
- Conflict response patterns (pursue/withdraw)
- Trust building and attachment growth
- Vulnerability and emotional safety

### CONNECTION Branch (20 quizzes)
**Theme: Emotional intimacy, communication styles, quality time**

Files: `connection/quiz_001.json` through `connection/quiz_020.json`

Topics covered:
- Love languages (giving and receiving)
- Emotional needs and support styles
- Communication preferences
- Intimacy and physical affection
- Daily connection rituals
- Conflict and repair patterns

### LIGHTHEARTED Branch (20 quizzes)
**Theme: Fun, lifestyle preferences, everyday compatibility**

Files: `lighthearted/quiz_001.json` through `lighthearted/quiz_020.json`

Topics covered:
- Daily preferences and support styles
- Appreciation and gratitude
- Everyday moments and routines
- Dreams and goals
- Communication styles
- Support and encouragement
- Fun and play
- Food and dining
- Social life
- Relaxation and unwinding
- Pet peeves and quirks
- Relationship story

### GROWTH Branch (20 quizzes)
**Theme: Personal development, goals, challenges, future vision**

Files: `growth/quiz_001.json` through `growth/quiz_020.json`

Topics covered:
- Personal goals and aspirations
- Relationship growth
- Overcoming challenges
- Future vision and dreams
- Supporting each other's growth
- Change and adaptation
- Life transitions
- Shared goals and values
- Self-awareness and reflection
- Learning and curiosity
- Habits and routines
- Feedback and improvement
- Mindset and attitude
- Balance and priorities
- Strengths and growth areas
- Growth milestones

### PLAYFUL Branch (20 quizzes)
**Theme: Social dynamics, adventure, decision-making, lifestyle preferences**

Files: `playful/quiz_001.json` through `playful/quiz_020.json`

Topics covered:
- Social energy and friend dynamics
- Risk and adventure preferences
- Decision making styles
- Spontaneity vs planning
- Traditions and rituals
- Daily routines and habits
- Communication preferences
- Fun and leisure activities

## Quiz Structure
Each quiz contains:
- 5 questions
- 4 choices per question (stored in JSON)
- UI adds 5th "It varies" option
- Optional therapeutic metadata with:
  - `rationale`: Why this question matters
  - `framework`: Psychological framework (gottman, attachment_theory, love_languages, etc.)
  - `whenDifferent`: Guidance when partners answer differently
  - `whenSame`: Guidance when partners answer the same
  - `journalPrompt`: Reflection question for deeper exploration
- Optional `dimension` and `poleMapping` for personality profiling

## Status
- ATTACHMENT: 20/20 quizzes complete
- CONNECTION: 20/20 quizzes complete
- LIGHTHEARTED: 20/20 quizzes complete
- GROWTH: 20/20 quizzes complete
- PLAYFUL: 20/20 quizzes complete

Total: 100 quizzes, 500 questions, all with 4 choices + UI "It varies" option

## Last Updated
January 2026 - Updated all branches to 4+1 model
