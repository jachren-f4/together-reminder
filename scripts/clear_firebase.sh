#!/bin/bash

# Clear Firebase Realtime Database
# Removes all quest and session data for clean testing

echo "🧹 Clearing Firebase RTDB data..."
echo ""

cd /Users/joakimachren/Desktop/togetherremind

echo "Removing /daily_quests..."
firebase database:remove /daily_quests --force

echo "Removing /quiz_sessions..."
firebase database:remove /quiz_sessions --force

echo "Removing /lp_awards..."
firebase database:remove /lp_awards --force

echo "Removing /quiz_progression..."
firebase database:remove /quiz_progression --force

echo ""
echo "✅ Firebase RTDB cleared successfully!"
echo ""
echo "Note: This only clears Firebase. Local Hive storage on devices is NOT affected."
echo "To clear local storage, uninstall the Android app or use the in-app debug menu."
