#!/bin/bash
# User Configuration for Daily Quest Testing
# Contains test user IDs, API URL, and couple configuration

# API Configuration
API_URL="${API_URL:-http://localhost:3000}"

# Test Users (from DevConfig)
# IMPORTANT: Chrome/Web user goes FIRST, Android user goes SECOND
# This matches the typical testing flow where Jokke (Chrome) creates the quiz
# and TestiY (Android) responds with predictions

# Jokke = Chrome/Web user - Goes FIRST (creates quiz, answers about himself)
JOKKE_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"

# TestiY = Android user - Goes SECOND (predicts Jokke's answers)
TESTIY_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"

# Couple ID for Jokke & TestiY
COUPLE_ID="11111111-1111-1111-1111-111111111111"

# Today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)

# Branch for daily quests
BRANCH="classic"
