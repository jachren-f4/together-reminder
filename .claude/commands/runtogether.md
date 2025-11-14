---
description: Launch Alice (Android) and Bob (Chrome) for local couple testing
---

Kill any existing Flutter and Chrome processes, then launch both Alice (Android emulator) and Bob (Chrome) for testing coupled features like daily quests, poke system, etc.

Steps:
1. Kill all running Flutter processes (pkill -9 -f "flutter run")
2. Kill all Chrome processes started by Flutter (pkill -9 Chrome)
3. Wait 2 seconds for cleanup
4. Launch Alice on Android emulator (emulator-5554) in background
5. Wait 10 seconds for Alice to fully initialize and generate quests
6. Launch Bob on Chrome in background
7. Monitor both for startup completion

Both devices will have deterministic user IDs and will share the same couple ID for testing.

Note: The 10-second delay between Alice and Bob prevents race conditions where both devices try to generate quests simultaneously. Alice generates the quests first, saves them to Firebase, then Bob loads them.
