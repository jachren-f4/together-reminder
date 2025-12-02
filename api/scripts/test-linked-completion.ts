/**
 * Test script to verify Linked game completion awards LP correctly
 *
 * Usage: npx tsx scripts/test-linked-completion.ts
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { join } from 'path';

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const API_URL = 'http://localhost:3000';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Dev user IDs from config
const USER1_ID = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28'; // Android/TestiY
const USER2_ID = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a'; // Chrome/Jokke

async function main() {
  console.log('🎮 Testing Linked game completion LP award...\n');

  // 1. Get couple info
  const { data: couple } = await supabase
    .from('couples')
    .select('id, total_lp')
    .or(`user1_id.eq.${USER1_ID},user2_id.eq.${USER1_ID}`)
    .single();

  if (!couple) {
    console.error('❌ No couple found');
    process.exit(1);
  }

  console.log(`📊 Current LP: ${couple.total_lp}`);
  const startingLP = couple.total_lp;

  // 2. Delete any existing linked matches
  await supabase.from('linked_moves').delete().eq('match_id', couple.id);
  await supabase.from('linked_matches').delete().eq('couple_id', couple.id);
  console.log('🗑️  Cleared old linked matches');

  // 3. Load a puzzle to get its structure
  const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'linked', 'casual', 'puzzle_001.json');
  const puzzle = JSON.parse(readFileSync(puzzlePath, 'utf-8'));

  // Find all answer cells (not clue frame, not void)
  const answerCells: { index: number; letter: string }[] = [];
  for (let i = 0; i < puzzle.grid.length; i++) {
    const row = Math.floor(i / puzzle.size.cols);
    const col = i % puzzle.size.cols;
    if (row === 0 || col === 0) continue; // Skip clue frame
    if (puzzle.grid[i] === '.') continue; // Skip void cells
    answerCells.push({ index: i, letter: puzzle.grid[i].toUpperCase() });
  }

  console.log(`📝 Puzzle has ${answerCells.length} answer cells`);

  // 4. Create a new match with all but ONE cell already filled
  const boardState: Record<string, string> = {};
  for (let i = 0; i < answerCells.length - 1; i++) {
    boardState[answerCells[i].index.toString()] = answerCells[i].letter;
  }

  const lastCell = answerCells[answerCells.length - 1];
  console.log(`🎯 Last cell to complete: index=${lastCell.index}, letter=${lastCell.letter}`);

  const matchId = crypto.randomUUID();
  await supabase.from('linked_matches').insert({
    id: matchId,
    couple_id: couple.id,
    puzzle_id: 'puzzle_001',
    player1_id: USER1_ID,
    player2_id: USER2_ID,
    current_turn_user_id: USER1_ID,
    current_rack: [lastCell.letter], // Give them the exact letter needed
    board_state: boardState,
    locked_cell_count: answerCells.length - 1,
    total_answer_cells: answerCells.length,
    status: 'active',
    turn_number: 1,
    player1_score: 0,
    player2_score: 0,
  });

  console.log(`✅ Created match ${matchId} with ${answerCells.length - 1} cells pre-filled`);

  // 5. Submit the final letter via API
  console.log('\n🚀 Submitting final letter via API...');

  const response = await fetch(`${API_URL}/api/sync/linked/submit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': USER1_ID,
    },
    body: JSON.stringify({
      matchId,
      placements: [{ cellIndex: lastCell.index, letter: lastCell.letter }],
    }),
  });

  const result = await response.json();
  console.log('📨 API Response:', JSON.stringify(result, null, 2));

  if (!result.success) {
    console.error('❌ API call failed:', result.error);
    process.exit(1);
  }

  if (!result.gameComplete) {
    console.error('❌ Game did not complete as expected');
    process.exit(1);
  }

  console.log('✅ Game completed successfully!');

  // 6. Check if LP was awarded
  const { data: coupleAfter } = await supabase
    .from('couples')
    .select('total_lp')
    .eq('id', couple.id)
    .single();

  const lpAwarded = (coupleAfter?.total_lp || 0) - startingLP;
  console.log(`\n📊 LP before: ${startingLP}`);
  console.log(`📊 LP after: ${coupleAfter?.total_lp}`);
  console.log(`📊 LP awarded: ${lpAwarded}`);

  if (lpAwarded === 30) {
    console.log('\n✅ SUCCESS: Exactly 30 LP was awarded!');
  } else if (lpAwarded === 60) {
    console.log('\n❌ FAILURE: 60 LP was awarded (double-counting bug!)');
    process.exit(1);
  } else if (lpAwarded === 0) {
    console.log('\n❌ FAILURE: No LP was awarded!');
    process.exit(1);
  } else {
    console.log(`\n⚠️ UNEXPECTED: ${lpAwarded} LP was awarded`);
  }

  // Cleanup
  await supabase.from('linked_moves').delete().eq('match_id', matchId);
  await supabase.from('linked_matches').delete().eq('id', matchId);
  console.log('\n🧹 Cleaned up test match');
}

main().catch(console.error);
