/**
 * Word Search Puzzle Generator
 *
 * Generates word search puzzles for the casual and romantic branches.
 * Each puzzle is a 10x10 grid with 12 words.
 *
 * Usage: npx tsx scripts/generate_word_search_puzzles.ts
 */

import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

// =============================================================================
// Configuration
// =============================================================================

const GRID_SIZE = 10;
const WORDS_PER_PUZZLE = 12;
const PUZZLES_PER_BRANCH = 20;

// Direction vectors: [rowDelta, colDelta]
const DIRECTIONS: Record<string, [number, number]> = {
  'R': [0, 1],    // Right
  'L': [0, -1],   // Left
  'D': [1, 0],    // Down
  'U': [-1, 0],   // Up
  'DR': [1, 1],   // Diagonal down-right
  'DL': [1, -1],  // Diagonal down-left
  'UR': [-1, 1],  // Diagonal up-right
  'UL': [-1, -1], // Diagonal up-left
};

// =============================================================================
// Word Lists
// =============================================================================

const CASUAL_WORDS = [
  // Fun & leisure
  'LAUGH', 'SMILE', 'HAPPY', 'FUNNY', 'SILLY', 'GIGGLES', 'JOKES', 'PLAY',
  'MOVIE', 'GAMES', 'SNACKS', 'COFFEE', 'BRUNCH', 'PICNIC', 'PIZZA', 'TREATS',
  // Friendship & togetherness
  'FRIEND', 'BUDDY', 'PARTNER', 'TEAM', 'CREW', 'VIBES', 'CHILL', 'RELAX',
  'COZY', 'COMFY', 'EASY', 'SIMPLE', 'PEACE', 'CALM', 'SERENE', 'MELLOW',
  // Activities
  'WALK', 'HIKE', 'BIKE', 'SWIM', 'SURF', 'DANCE', 'SING', 'COOK',
  'BAKE', 'CRAFT', 'PAINT', 'DRAW', 'READ', 'WRITE', 'CHAT', 'TALK',
  // Positive feelings
  'WARM', 'BRIGHT', 'LIGHT', 'SUNNY', 'CHEERFUL', 'KIND', 'SWEET', 'GENTLE',
  'SOFT', 'NICE', 'GOOD', 'GREAT', 'AWESOME', 'COOL', 'NEAT', 'SWELL',
  // Home & comfort
  'HOME', 'COUCH', 'BLANKET', 'PILLOW', 'NAP', 'REST', 'SLEEP', 'DREAM',
  'LAZY', 'SLOW', 'QUIET', 'STILL', 'SAFE', 'SNUG', 'NEST', 'DEN',
  // Nature
  'BEACH', 'PARK', 'GARDEN', 'FOREST', 'RIVER', 'LAKE', 'SUNSET', 'STARS',
  'MOON', 'SKY', 'CLOUD', 'BREEZE', 'RAIN', 'SNOW', 'BLOOM', 'LEAF',
  // Food & drink
  'TEA', 'COCOA', 'WINE', 'CAKE', 'PIE', 'FRUIT', 'CANDY', 'CHIPS',
  // Misc casual
  'SELFIE', 'MEMES', 'BINGE', 'STREAM', 'PHONE', 'TEXT', 'EMOJI', 'CUTE',
];

const ROMANTIC_WORDS = [
  // Love & affection
  'LOVE', 'HEART', 'ADORE', 'CHERISH', 'TREASURE', 'DEVOTED', 'BELOVED', 'DARLING',
  'HONEY', 'SWEET', 'DEAR', 'ANGEL', 'SOULMATE', 'CRUSH', 'SWOON', 'YEARN',
  // Romance
  'ROMANCE', 'ROSES', 'FLOWERS', 'PETALS', 'CANDLELIGHT', 'DINNER', 'WINE', 'CHAMPAGNE',
  'KISS', 'KISSES', 'HUG', 'EMBRACE', 'CUDDLE', 'SNUGGLE', 'CARESS', 'HOLD',
  // Dating
  'DATE', 'DANCE', 'WALTZ', 'SWAY', 'TWIRL', 'DINE', 'STROLL', 'GAZE',
  'FLIRT', 'WINK', 'BLUSH', 'CHARM', 'ALLURE', 'ATTRACT', 'CAPTIVATE', 'ENCHANT',
  // Feelings
  'PASSION', 'DESIRE', 'LONGING', 'DREAMING', 'HOPING', 'WISHING', 'TENDER', 'GENTLE',
  'WARM', 'CARING', 'LOVING', 'GIVING', 'SHARING', 'BONDING', 'CONNECTING', 'GROWING',
  // Commitment
  'FOREVER', 'ALWAYS', 'PROMISE', 'VOW', 'PLEDGE', 'TRUST', 'FAITH', 'LOYAL',
  'TRUE', 'FAITHFUL', 'DEVOTED', 'COMMITTED', 'UNITED', 'TOGETHER', 'PAIR', 'DUO',
  // Special moments
  'SUNSET', 'SUNRISE', 'MOONLIGHT', 'STARLIGHT', 'TWILIGHT', 'DAWN', 'DUSK', 'EVENING',
  'MAGIC', 'WONDER', 'BEAUTY', 'GRACE', 'BLISS', 'JOY', 'DELIGHT', 'HAPPY',
  // Symbols
  'RING', 'BAND', 'JEWEL', 'GEM', 'PEARL', 'DIAMOND', 'GIFT', 'PRESENT',
  'NOTE', 'LETTER', 'POEM', 'SONG', 'MELODY', 'HARMONY', 'RHYTHM', 'TUNE',
  // Nature romance
  'BEACH', 'SHORE', 'WAVE', 'OCEAN', 'BREEZE', 'GARDEN', 'BLOOM', 'SPRING',
];

// =============================================================================
// Grid Generation
// =============================================================================

type Grid = string[][];

function createEmptyGrid(): Grid {
  return Array(GRID_SIZE).fill(null).map(() => Array(GRID_SIZE).fill(''));
}

function canPlaceWord(grid: Grid, word: string, startRow: number, startCol: number, direction: string): boolean {
  const [dRow, dCol] = DIRECTIONS[direction];

  for (let i = 0; i < word.length; i++) {
    const row = startRow + i * dRow;
    const col = startCol + i * dCol;

    // Check bounds
    if (row < 0 || row >= GRID_SIZE || col < 0 || col >= GRID_SIZE) {
      return false;
    }

    // Check if cell is empty or has same letter (overlap allowed)
    const cell = grid[row][col];
    if (cell !== '' && cell !== word[i]) {
      return false;
    }
  }

  return true;
}

function placeWord(grid: Grid, word: string, startRow: number, startCol: number, direction: string): void {
  const [dRow, dCol] = DIRECTIONS[direction];

  for (let i = 0; i < word.length; i++) {
    const row = startRow + i * dRow;
    const col = startCol + i * dCol;
    grid[row][col] = word[i];
  }
}

function getStartIndex(row: number, col: number): number {
  return row * GRID_SIZE + col;
}

function tryPlaceWordRandomly(grid: Grid, word: string): { placed: boolean; position?: string } {
  const directionKeys = Object.keys(DIRECTIONS);
  const shuffledDirs = [...directionKeys].sort(() => Math.random() - 0.5);

  // Try each direction
  for (const direction of shuffledDirs) {
    const [dRow, dCol] = DIRECTIONS[direction];

    // Calculate valid starting positions for this direction
    const validPositions: [number, number][] = [];

    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        // Check if word would fit from this position
        const endRow = row + (word.length - 1) * dRow;
        const endCol = col + (word.length - 1) * dCol;

        if (endRow >= 0 && endRow < GRID_SIZE && endCol >= 0 && endCol < GRID_SIZE) {
          if (canPlaceWord(grid, word, row, col, direction)) {
            validPositions.push([row, col]);
          }
        }
      }
    }

    if (validPositions.length > 0) {
      // Pick a random valid position
      const [row, col] = validPositions[Math.floor(Math.random() * validPositions.length)];
      placeWord(grid, word, row, col, direction);
      return { placed: true, position: `${getStartIndex(row, col)},${direction}` };
    }
  }

  return { placed: false };
}

function fillEmptyCells(grid: Grid): void {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      if (grid[row][col] === '') {
        grid[row][col] = alphabet[Math.floor(Math.random() * alphabet.length)];
      }
    }
  }
}

function gridToString(grid: Grid): string {
  return grid.map(row => row.join('')).join('');
}

// =============================================================================
// Puzzle Generation
// =============================================================================

function selectWordsForPuzzle(wordList: string[], count: number): string[] {
  // Filter to words that fit in grid (max length = GRID_SIZE)
  const validWords = wordList.filter(w => w.length <= GRID_SIZE && w.length >= 3);

  // Shuffle and select
  const shuffled = [...validWords].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count * 2); // Get extra in case some don't fit
}

function generatePuzzle(wordList: string[], puzzleId: string, title: string, theme: string): any {
  let attempts = 0;
  const maxAttempts = 50;

  while (attempts < maxAttempts) {
    attempts++;
    const grid = createEmptyGrid();
    const words: Record<string, string> = {};
    const candidates = selectWordsForPuzzle(wordList, WORDS_PER_PUZZLE);

    for (const word of candidates) {
      if (Object.keys(words).length >= WORDS_PER_PUZZLE) break;

      const result = tryPlaceWordRandomly(grid, word);
      if (result.placed && result.position) {
        words[word] = result.position;
      }
    }

    if (Object.keys(words).length >= WORDS_PER_PUZZLE) {
      fillEmptyCells(grid);

      return {
        puzzleId,
        title,
        theme,
        size: { rows: GRID_SIZE, cols: GRID_SIZE },
        grid: gridToString(grid),
        words,
      };
    }
  }

  throw new Error(`Failed to generate puzzle ${puzzleId} after ${maxAttempts} attempts`);
}

function generateBranch(
  branchName: string,
  wordList: string[],
  titlePrefix: string,
  theme: string
): void {
  const branchDir = join(process.cwd(), 'data', 'puzzles', 'word-search', branchName);

  // Create directory if it doesn't exist
  if (!existsSync(branchDir)) {
    mkdirSync(branchDir, { recursive: true });
    console.log(`Created directory: ${branchDir}`);
  }

  const puzzleOrder: string[] = [];

  for (let i = 1; i <= PUZZLES_PER_BRANCH; i++) {
    const puzzleId = `ws_${String(i).padStart(3, '0')}`;
    const romanNumeral = toRomanNumeral(i);
    const title = `${titlePrefix} ${romanNumeral}`;

    console.log(`Generating ${branchName}/${puzzleId}...`);

    const puzzle = generatePuzzle(wordList, puzzleId, title, theme);

    const puzzlePath = join(branchDir, `${puzzleId}.json`);
    writeFileSync(puzzlePath, JSON.stringify(puzzle, null, 2));

    puzzleOrder.push(puzzleId);
  }

  // Write puzzle order file
  const orderPath = join(branchDir, 'puzzle-order.json');
  writeFileSync(orderPath, JSON.stringify({ puzzles: puzzleOrder }, null, 2));

  console.log(`✓ Generated ${PUZZLES_PER_BRANCH} puzzles for ${branchName}`);
}

function toRomanNumeral(num: number): string {
  const romanNumerals: [number, string][] = [
    [20, 'XX'],
    [19, 'XIX'],
    [18, 'XVIII'],
    [17, 'XVII'],
    [16, 'XVI'],
    [15, 'XV'],
    [14, 'XIV'],
    [13, 'XIII'],
    [12, 'XII'],
    [11, 'XI'],
    [10, 'X'],
    [9, 'IX'],
    [8, 'VIII'],
    [7, 'VII'],
    [6, 'VI'],
    [5, 'V'],
    [4, 'IV'],
    [3, 'III'],
    [2, 'II'],
    [1, 'I'],
  ];

  for (const [value, numeral] of romanNumerals) {
    if (num >= value) return numeral;
  }
  return 'I';
}

// =============================================================================
// Main
// =============================================================================

async function main() {
  console.log('Word Search Puzzle Generator');
  console.log('============================\n');

  // Generate casual branch
  console.log('Generating CASUAL branch...');
  generateBranch('casual', CASUAL_WORDS, 'Casual', 'casual');
  console.log('');

  // Generate romantic branch
  console.log('Generating ROMANTIC branch...');
  generateBranch('romantic', ROMANTIC_WORDS, 'Romantic', 'romantic');
  console.log('');

  console.log('✓ All puzzles generated successfully!');
  console.log('\nNext steps:');
  console.log('1. Update api/lib/puzzle/loader.ts to add new branches');
  console.log('2. Test puzzles by starting a word search game');
}

main().catch(console.error);
