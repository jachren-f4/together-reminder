# Memory Flip: Turn-Based Supabase Migration Specification

**Date:** 2025-11-21
**Version:** 1.0
**Status:** Approved for Implementation

---

## Executive Summary

This specification details the migration of Memory Flip from real-time simultaneous gameplay to turn-based sequential gameplay, removing all Firebase Realtime Database dependencies and using Supabase PostgreSQL as the sole backend.

### Key Changes

1. **Turn-Based Gameplay**: Players take alternating turns (no simultaneous play)
2. **Supabase-Only Backend**: Complete removal of Firebase RTDB
3. **Individual Flip Allowances**: 6 flips every 5 hours per player
4. **Score Tracking**: Track who found each pair for competitive play
5. **Turn Timeout**: 5-hour auto-advance for inactive players
6. **Polling Updates**: Check for updates on screen load (like Daily Quests)

---

## Game Rules

### Turn Mechanics

```
Game Flow:
1. First player determined alphabetically by user ID
2. Current player flips 2 cards (uses 2 flips from allowance)
3. If match: Award points to player, continue current turn
4. If no match: Turn passes to partner
5. If player runs out of flips: Turn passes to partner
6. If turn timeout (5 hours): Auto-advance to partner
7. Game ends when all pairs matched OR both players out of flips
```

### Flip Allowance System

**Individual Hour-Based Recharge:**
- Each player gets 6 flips (3 attempts) initially
- After exhausting flips, 5-hour timer starts
- After 5 hours, flips refill to 6
- Timer is per-player, not shared

**Example Timeline:**
```
10:00 AM - Alice uses all 6 flips
10:00 AM - Alice's 5-hour timer starts
3:00 PM  - Alice gets 6 new flips
Meanwhile - Bob has his own separate allowance/timer
```

### Scoring System

**Per-Pair Tracking:**
- Each matched pair records who found it
- Final score shows: "Alice: 5 pairs, Bob: 3 pairs"
- Love Points awarded based on total pairs found

**No Bonus Turns:**
- Finding a match doesn't give extra turn
- Turn always passes after 2 cards flipped
- Simplifies game logic and prevents runaway turns

### Turn Timeout

**5-Hour Inactive Player Protection:**
- If current player doesn't take turn within 5 hours
- Turn automatically passes to partner
- Prevents game from being stuck indefinitely

---

## Technical Architecture

### Database Schema

#### Updated memory_puzzles Table

```sql
-- Add turn-based columns
ALTER TABLE memory_puzzles ADD COLUMN
  -- Turn state
  current_player_id UUID REFERENCES auth.users(id),
  turn_number INT DEFAULT 0,
  turn_started_at TIMESTAMPTZ,
  turn_expires_at TIMESTAMPTZ,

  -- Scoring
  player1_pairs INT DEFAULT 0,  -- Pairs found by player 1
  player2_pairs INT DEFAULT 0,  -- Pairs found by player 2

  -- Game state
  game_phase TEXT DEFAULT 'waiting',  -- 'waiting', 'active', 'completed'

  -- Updated allowances (stored per puzzle for consistency)
  player1_flips_remaining INT DEFAULT 6,
  player1_flips_reset_at TIMESTAMPTZ,
  player2_flips_remaining INT DEFAULT 6,
  player2_flips_reset_at TIMESTAMPTZ;

-- Add indexes for performance
CREATE INDEX idx_memory_puzzles_current_player
  ON memory_puzzles(couple_id, current_player_id);

CREATE INDEX idx_memory_puzzles_turn_expires
  ON memory_puzzles(turn_expires_at)
  WHERE game_phase = 'active';
```

#### New memory_moves Table (Audit Log)

```sql
CREATE TABLE memory_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  puzzle_id UUID REFERENCES memory_puzzles(id) ON DELETE CASCADE,
  player_id UUID REFERENCES auth.users(id),

  -- Move details
  card1_id VARCHAR NOT NULL,
  card2_id VARCHAR NOT NULL,
  card1_position INT NOT NULL,
  card2_position INT NOT NULL,
  match_found BOOLEAN NOT NULL,
  pair_id VARCHAR,  -- If match found

  -- Metadata
  turn_number INT NOT NULL,
  flips_remaining_after INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate moves
  UNIQUE(puzzle_id, turn_number)
);

CREATE INDEX idx_memory_moves_puzzle
  ON memory_moves(puzzle_id, created_at DESC);
```

### RLS Policies

```sql
-- View policy: Both players can see puzzle
CREATE POLICY memory_puzzle_view ON memory_puzzles
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Update policy: Only current player during their turn
CREATE POLICY memory_puzzle_turn_update ON memory_puzzles
  FOR UPDATE USING (
    current_player_id = auth.uid()
    AND game_phase = 'active'
    AND (turn_expires_at IS NULL OR turn_expires_at > NOW())
  );

-- Insert policy: Either player can create
CREATE POLICY memory_puzzle_create ON memory_puzzles
  FOR INSERT WITH CHECK (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Moves: Only current player can insert
CREATE POLICY memory_moves_insert ON memory_moves
  FOR INSERT WITH CHECK (
    player_id = auth.uid() AND
    puzzle_id IN (
      SELECT id FROM memory_puzzles
      WHERE current_player_id = auth.uid()
        AND game_phase = 'active'
    )
  );

-- Moves: Both players can view
CREATE POLICY memory_moves_view ON memory_moves
  FOR SELECT USING (
    puzzle_id IN (
      SELECT mp.id FROM memory_puzzles mp
      JOIN couples c ON mp.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );
```

---

## API Endpoints

### POST /api/sync/memory-flip/move

**Submit a turn (flip 2 cards)**

Request:
```json
{
  "puzzleId": "puzzle_2025-11-21",
  "card1Id": "card-uuid-1",
  "card2Id": "card-uuid-2"
}
```

Response (Success):
```json
{
  "success": true,
  "matchFound": false,
  "turnAdvanced": true,
  "nextPlayerId": "user-uuid-2",
  "puzzle": {
    "id": "puzzle_2025-11-21",
    "currentPlayerId": "user-uuid-2",
    "turnNumber": 5,
    "player1Pairs": 2,
    "player2Pairs": 1,
    "cards": [...]
  },
  "playerFlipsRemaining": 4,
  "partnerFlipsRemaining": 6
}
```

Response (Error - Not Your Turn):
```json
{
  "success": false,
  "error": "NOT_YOUR_TURN",
  "currentPlayerId": "user-uuid-2",
  "turnExpiresAt": "2025-11-21T15:00:00Z"
}
```

**Validation Logic:**
1. Verify puzzle exists and is active
2. Verify current player matches auth user
3. Verify turn hasn't expired
4. Verify player has >= 2 flips remaining
5. Verify both cards are valid and not already matched
6. Process move and check for match
7. Update puzzle state and advance turn if needed
8. Record move in memory_moves table
9. Return updated puzzle state

### GET /api/sync/memory-flip/:puzzleId

**Get current puzzle state**

Response:
```json
{
  "puzzle": {
    "id": "puzzle_2025-11-21",
    "createdAt": "2025-11-21T10:00:00Z",
    "expiresAt": "2025-11-28T10:00:00Z",
    "currentPlayerId": "user-uuid-1",
    "turnNumber": 4,
    "turnStartedAt": "2025-11-21T14:30:00Z",
    "turnExpiresAt": "2025-11-21T19:30:00Z",
    "gamePhase": "active",
    "totalPairs": 8,
    "matchedPairs": 3,
    "player1Pairs": 2,
    "player2Pairs": 1,
    "cards": [...],
    "player1FlipsRemaining": 4,
    "player1FlipsResetAt": null,
    "player2FlipsRemaining": 2,
    "player2FlipsResetAt": "2025-11-21T18:00:00Z"
  },
  "moves": [
    {
      "turnNumber": 1,
      "playerId": "user-uuid-1",
      "matchFound": true,
      "pairId": "pair-1",
      "createdAt": "2025-11-21T10:05:00Z"
    },
    ...
  ],
  "isMyTurn": true,
  "canPlay": true,  // Has flips and is current turn
  "myFlipsRemaining": 4,
  "timeUntilFlipReset": null
}
```

### POST /api/sync/memory-flip/timeout-check

**Check and advance timed-out turns (called by cron or on-demand)**

Response:
```json
{
  "timedOutPuzzles": 3,
  "advanced": ["puzzle-1", "puzzle-2", "puzzle-3"]
}
```

---

## Flutter Implementation

### Service Layer Changes

#### Remove memory_flip_sync_service.dart

This file is completely removed as it handles Firebase RTDB sync.

#### Updated memory_flip_service.dart

```dart
class MemoryFlipService {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();

  // Hour-based flip allowance
  static const int _flipsPerRecharge = 6;
  static const Duration _rechargeDuration = Duration(hours: 5);

  /// Get or generate puzzle for today
  Future<MemoryPuzzle> getCurrentPuzzle() async {
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final puzzleId = 'puzzle_$dateKey';

    // Try to load from API
    try {
      final response = await _api.get('/api/sync/memory-flip/$puzzleId');
      if (response.success && response.data['puzzle'] != null) {
        final puzzle = MemoryPuzzle.fromJson(response.data['puzzle']);
        await _storage.saveMemoryPuzzle(puzzle);
        return puzzle;
      }
    } catch (e) {
      // Fall through to generate
    }

    // Generate new puzzle
    final puzzle = await generateDailyPuzzle(puzzleId: puzzleId);

    // Save to Supabase
    await _api.post('/api/sync/memory-flip', body: puzzle.toJson());

    return puzzle;
  }

  /// Submit a move (flip 2 cards)
  Future<MoveResult> submitMove(
    String puzzleId,
    String card1Id,
    String card2Id,
  ) async {
    final response = await _api.post(
      '/api/sync/memory-flip/move',
      body: {
        'puzzleId': puzzleId,
        'card1Id': card1Id,
        'card2Id': card2Id,
      },
    );

    if (!response.success) {
      throw Exception(response.data['error'] ?? 'Move failed');
    }

    // Update local storage with new puzzle state
    final updatedPuzzle = MemoryPuzzle.fromJson(response.data['puzzle']);
    await _storage.updateMemoryPuzzle(updatedPuzzle);

    return MoveResult(
      matchFound: response.data['matchFound'],
      turnAdvanced: response.data['turnAdvanced'],
      playerFlipsRemaining: response.data['playerFlipsRemaining'],
    );
  }

  /// Check if it's my turn
  Future<bool> isMyTurn(String puzzleId) async {
    final response = await _api.get('/api/sync/memory-flip/$puzzleId');
    final userId = _storage.getUser()?.id;
    return response.data['puzzle']['currentPlayerId'] == userId;
  }

  /// Get time until flip reset (5 hours)
  Duration? getTimeUntilReset(DateTime? resetAt) {
    if (resetAt == null) return null;
    final now = DateTime.now();
    if (resetAt.isBefore(now)) return Duration.zero;
    return resetAt.difference(now);
  }
}
```

### UI Layer Changes

#### Updated memory_flip_game_screen.dart

```dart
class _MemoryFlipGameScreenState extends State<MemoryFlipGameScreen> {
  final MemoryFlipService _service = MemoryFlipService();
  final StorageService _storage = StorageService();

  MemoryPuzzle? _puzzle;
  bool _isMyTurn = false;
  int _myFlipsRemaining = 0;
  DateTime? _flipsResetAt;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Currently selected cards for this turn
  String? _selectedCard1Id;
  String? _selectedCard2Id;

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when screen regains focus (polling pattern)
    _loadGameState();
  }

  Future<void> _loadGameState() async {
    setState(() => _isLoading = true);

    try {
      final puzzle = await _service.getCurrentPuzzle();
      final userId = _storage.getUser()?.id;

      // Get full game state from API
      final response = await ApiClient().get(
        '/api/sync/memory-flip/${puzzle.id}'
      );

      setState(() {
        _puzzle = puzzle;
        _isMyTurn = response.data['isMyTurn'];
        _myFlipsRemaining = response.data['myFlipsRemaining'];
        _flipsResetAt = response.data['timeUntilFlipReset'] != null
          ? DateTime.now().add(
              Duration(seconds: response.data['timeUntilFlipReset'])
            )
          : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  Future<void> _onCardTap(MemoryCard card) async {
    // Check if it's player's turn
    if (!_isMyTurn) {
      _showNotYourTurnDialog();
      return;
    }

    // Check if player has flips
    if (_myFlipsRemaining < 2) {
      _showNoFlipsDialog();
      return;
    }

    // Prevent interaction while processing
    if (_isProcessing) return;

    // Can't select already matched cards
    if (card.isMatched) return;

    // Select first or second card
    if (_selectedCard1Id == null) {
      setState(() {
        _selectedCard1Id = card.id;
      });
    } else if (_selectedCard2Id == null && card.id != _selectedCard1Id) {
      setState(() {
        _selectedCard2Id = card.id;
      });

      // Submit move after second card selected
      await _submitMove();
    }
  }

  Future<void> _submitMove() async {
    if (_selectedCard1Id == null || _selectedCard2Id == null) return;

    setState(() => _isProcessing = true);

    // Show both cards for a moment
    await Future.delayed(Duration(milliseconds: 1000));

    try {
      final result = await _service.submitMove(
        _puzzle!.id,
        _selectedCard1Id!,
        _selectedCard2Id!,
      );

      if (result.matchFound) {
        // Show match celebration
        _showMatchDialog();
      }

      // Clear selection
      setState(() {
        _selectedCard1Id = null;
        _selectedCard2Id = null;
        _isProcessing = false;
      });

      // Reload game state (updates turn, scores, etc.)
      await _loadGameState();

    } catch (e) {
      setState(() {
        _selectedCard1Id = null;
        _selectedCard2Id = null;
        _isProcessing = false;
      });

      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Memory Flip'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadGameState,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_puzzle == null) {
      return Center(child: Text('Error loading puzzle'));
    }

    return Column(
      children: [
        _buildTurnIndicator(),
        _buildScoreBoard(),
        _buildFlipAllowance(),
        Expanded(child: _buildGameGrid()),
      ],
    );
  }

  Widget _buildTurnIndicator() {
    final color = _isMyTurn ? Colors.green : Colors.orange;
    final text = _isMyTurn
      ? "Your Turn"
      : "Waiting for ${_getPartnerName()}";

    return Container(
      padding: EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isMyTurn ? Icons.play_arrow : Icons.hourglass_empty,
            color: color,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    final myPairs = _getMyPairs();
    final partnerPairs = _getPartnerPairs();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildScoreCard("You", myPairs, Colors.blue),
          Text("vs", style: TextStyle(fontSize: 20)),
          _buildScoreCard(_getPartnerName(), partnerPairs, Colors.red),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _puzzle!.cards.length,
      itemBuilder: (context, index) {
        final card = _puzzle!.cards[index];
        final isSelected = card.id == _selectedCard1Id ||
                          card.id == _selectedCard2Id;
        final canInteract = _isMyTurn &&
                           _myFlipsRemaining >= 2 &&
                           !_isProcessing;

        return GestureDetector(
          onTap: canInteract ? () => _onCardTap(card) : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _getCardColor(card, isSelected),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Center(
              child: _getCardContent(card, isSelected),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Migration Path

### Phase 1: Database Setup (Day 1)
1. ✅ Create and run Supabase migration
2. ✅ Update RLS policies
3. ✅ Test database constraints

### Phase 2: API Implementation (Day 2-3)
1. ✅ Implement move validation endpoint
2. ✅ Implement puzzle state endpoint
3. ✅ Add timeout checker
4. ✅ Test API with Postman/curl

### Phase 3: Flutter Service Layer (Day 4)
1. ✅ Remove Firebase sync service
2. ✅ Update MemoryFlipService
3. ✅ Update models for turn state
4. ✅ Test service methods

### Phase 4: Flutter UI Layer (Day 5-6)
1. ✅ Update game screen for turn-based play
2. ✅ Add turn indicators
3. ✅ Add score tracking UI
4. ✅ Implement polling on focus
5. ✅ Test gameplay flow

### Phase 5: Cleanup (Day 7)
1. ✅ Remove Firebase RTDB rules
2. ✅ Remove Firebase imports
3. ✅ Update documentation
4. ✅ Final testing

---

## Testing Checklist

### Functional Tests
- [ ] Player can only move on their turn
- [ ] Turn advances after each move
- [ ] Matches are tracked to correct player
- [ ] Flip allowance decrements correctly
- [ ] 5-hour recharge timer works
- [ ] 5-hour turn timeout works
- [ ] Game completes when all pairs matched
- [ ] Game completes when both players out of flips

### Edge Cases
- [ ] Player tries to move when not their turn
- [ ] Player with 0 flips tries to play
- [ ] Turn timeout while player viewing game
- [ ] Both players exhaust flips before completion
- [ ] Network error during move submission
- [ ] Screen refresh during opponent's turn

### Performance Tests
- [ ] Puzzle loads quickly (<500ms)
- [ ] Move submission responsive (<1s)
- [ ] No unnecessary API calls
- [ ] Polling doesn't drain battery

---

## Rollback Plan

If issues arise during migration:

1. **Keep Firebase RTDB code in separate branch**
2. **Feature flag for turn-based mode**
3. **Database: Keep Firebase data intact**
4. **Quick revert: Git revert and redeploy**

---

## Success Metrics

### Technical
- Zero Firebase RTDB calls
- API response time <500ms
- 99% uptime

### User Experience
- Clear turn indicators
- Smooth turn transitions
- No lost moves
- Fair gameplay

---

## FAQ

**Q: Why 5 hours for flip recharge?**
A: Balances engagement without being too restrictive. Players can play 2-3 times per day.

**Q: Why no bonus turns for matches?**
A: Simplifies logic and prevents one player dominating if they get lucky.

**Q: What if both players run out of flips?**
A: Game ends, shows final scores. Encourages strategic play.

**Q: Can we add spectator mode?**
A: Future enhancement - not in initial scope.

---

## Appendix: Code Snippets

### Example Turn Validation (TypeScript)

```typescript
async function validateTurn(
  puzzleId: string,
  playerId: string,
  card1Id: string,
  card2Id: string
): Promise<ValidationResult> {

  // Get puzzle state
  const puzzle = await getPuzzle(puzzleId);

  // Check game is active
  if (puzzle.gamePhase !== 'active') {
    return { valid: false, error: 'GAME_NOT_ACTIVE' };
  }

  // Check it's player's turn
  if (puzzle.currentPlayerId !== playerId) {
    return { valid: false, error: 'NOT_YOUR_TURN' };
  }

  // Check turn hasn't expired
  if (puzzle.turnExpiresAt && puzzle.turnExpiresAt < new Date()) {
    await advanceTurn(puzzleId);
    return { valid: false, error: 'TURN_EXPIRED' };
  }

  // Check player has flips
  const flipsRemaining = getPlayerFlips(puzzle, playerId);
  if (flipsRemaining < 2) {
    return { valid: false, error: 'INSUFFICIENT_FLIPS' };
  }

  // Check cards are valid and not matched
  const card1 = puzzle.cards.find(c => c.id === card1Id);
  const card2 = puzzle.cards.find(c => c.id === card2Id);

  if (!card1 || !card2) {
    return { valid: false, error: 'INVALID_CARDS' };
  }

  if (card1.status === 'matched' || card2.status === 'matched') {
    return { valid: false, error: 'CARD_ALREADY_MATCHED' };
  }

  return { valid: true };
}
```

---

**Last Updated:** 2025-11-21
**Author:** Claude Code (AI Assistant)
**Reviewed By:** [Pending]