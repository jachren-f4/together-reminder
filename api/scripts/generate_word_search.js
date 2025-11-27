#!/usr/bin/env node
/**
 * Word Search Puzzle Generator
 *
 * Generates word search puzzles for the TogetherRemind app.
 * Each puzzle is a 10x10 grid with 12 hidden words.
 *
 * Usage:
 *   node scripts/generate_word_search.js [branch] [count]
 *
 * Examples:
 *   node scripts/generate_word_search.js everyday 20
 *   node scripts/generate_word_search.js passionate 20
 *   node scripts/generate_word_search.js naughty 20
 *   node scripts/generate_word_search.js all 20
 */

const fs = require('fs');
const path = require('path');

// Direction definitions
const DIRECTIONS = {
  'R': [0, 1],    // Right
  'L': [0, -1],   // Left
  'D': [1, 0],    // Down
  'U': [-1, 0],   // Up
  'DR': [1, 1],   // Down-Right (diagonal)
  'DL': [1, -1],  // Down-Left (diagonal)
  'UR': [-1, 1],  // Up-Right (diagonal)
  'UL': [-1, -1], // Up-Left (diagonal)
};

// Word lists for each branch/theme
const WORD_LISTS = {
  everyday: {
    theme: 'everyday',
    titlePrefix: 'Daily Love',
    words: [
      // Everyday relationship words (4-8 letters, 12 per puzzle needed)
      'LOVE', 'CARE', 'TRUST', 'LAUGH', 'SMILE', 'HEART', 'HAPPY', 'PEACE',
      'CALM', 'WARM', 'KIND', 'SWEET', 'DEAR', 'HOME', 'COZY', 'SAFE',
      'HUSH', 'SOFT', 'GENTLE', 'TENDER', 'CHERISH', 'ADORE', 'FOND', 'BLISS',
      'CUDDLE', 'SNUGGLE', 'COMFORT', 'SUPPORT', 'LISTEN', 'SHARE', 'BOND', 'UNITY',
      'PARTNER', 'SOULMATE', 'BESTIE', 'FRIEND', 'LOYAL', 'HONEST', 'RESPECT', 'VALUE',
      'GROW', 'BUILD', 'DREAM', 'HOPE', 'WISH', 'PLAN', 'FUTURE', 'FAMILY',
      'DINNER', 'MOVIE', 'WALK', 'TALK', 'CHAT', 'JOKE', 'PLAY', 'REST',
      'MORNING', 'EVENING', 'WEEKEND', 'HOLIDAY', 'TRIP', 'DATE', 'GIFT', 'SURPRISE',
      'HUG', 'HOLD', 'TOUCH', 'HAND', 'KISS', 'EMBRACE', 'TOGETHER', 'FOREVER',
      'COUPLE', 'PAIR', 'TEAM', 'DUO', 'MATCH', 'PERFECT', 'LUCKY', 'BLESSED',
      'GRATEFUL', 'THANKFUL', 'CONTENT', 'JOYFUL', 'CHEERFUL', 'MERRY', 'JOLLY', 'BRIGHT',
      'GIGGLE', 'GRIN', 'BEAM', 'WINK', 'NOD', 'WAVE', 'GREET',
    ],
  },
  passionate: {
    theme: 'passion',
    titlePrefix: 'Passionate',
    words: [
      // Romantic/passionate words (slightly more intense)
      'PASSION', 'ROMANCE', 'DESIRE', 'LONGING', 'CRAVING', 'YEARN', 'ADORE', 'WORSHIP',
      'FLAME', 'FIRE', 'SPARK', 'HEAT', 'BURN', 'GLOW', 'BLAZE', 'IGNITE',
      'ENCHANT', 'CAPTIVE', 'BEWITCH', 'CHARM', 'ALLURE', 'ATTRACT', 'MAGNETIC', 'PULL',
      'INTENSE', 'DEEP', 'STRONG', 'POWERFUL', 'FIERCE', 'WILD', 'FREE', 'BOLD',
      'THRILL', 'RUSH', 'PULSE', 'BEAT', 'RACE', 'FLUTTER', 'SKIP', 'POUND',
      'DREAM', 'FANTASY', 'WISH', 'IMAGINE', 'WONDER', 'MAGIC', 'SPELL', 'POTION',
      'MOON', 'STARS', 'NIGHT', 'EVENING', 'SUNSET', 'DAWN', 'TWILIGHT', 'DUSK',
      'DANCE', 'SWAY', 'TWIRL', 'SPIN', 'MOVE', 'FLOW', 'GLIDE', 'FLOAT',
      'WHISPER', 'MURMUR', 'SIGH', 'BREATH', 'GASP', 'MOAN', 'PURR', 'HUM',
      'SILK', 'SATIN', 'VELVET', 'LACE', 'SOFT', 'SMOOTH', 'TENDER', 'GENTLE',
      'EMBRACE', 'HOLD', 'CLASP', 'GRIP', 'SQUEEZE', 'PRESS', 'CLING', 'NESTLE',
      'EYES', 'LIPS', 'HANDS', 'SKIN', 'HAIR', 'NECK', 'CHEEK', 'FACE',
      'HEART', 'SOUL', 'SPIRIT', 'MIND', 'BODY', 'BEING', 'ESSENCE', 'CORE',
    ],
  },
  naughty: {
    theme: 'intimacy',
    titlePrefix: 'Intimate',
    words: [
      // Adult/intimate words (tasteful but suggestive)
      'PASSION', 'ROMANCE', 'SEDUCE', 'LIBIDO', 'AROUSE', 'TOUCH', 'LOVERS', 'NAKED',
      'TEASE', 'FEVER', 'MOAN', 'NECK', 'LUST', 'GRIND', 'HARD', 'WILD',
      'LIPS', 'DEEP', 'SPOT', 'KISS', 'BLISS', 'THRILL', 'PULSE', 'HEAT',
      'DESIRE', 'CRAVE', 'YEARN', 'WANT', 'NEED', 'HUNGER', 'THIRST', 'ACHE',
      'SKIN', 'BODY', 'FLESH', 'CURVE', 'SHAPE', 'FORM', 'FIGURE',
      'WHISPER', 'MURMUR', 'SIGH', 'BREATH', 'GASP', 'PANT', 'SHIVER', 'TREMBLE',
      'SILK', 'SATIN', 'LACE', 'SHEER', 'BARE', 'EXPOSED', 'REVEAL', 'UNVEIL',
      'ENTICE', 'TEMPT', 'ALLURE', 'BEWITCH', 'CAPTIVE', 'ENCHANT', 'SPELLBOUND',
      'FIRE', 'FLAME', 'BURN', 'BLAZE', 'IGNITE', 'SPARK', 'SMOLDER', 'SIZZLE',
      'EMBRACE', 'CLASP', 'GRIP', 'HOLD', 'SQUEEZE', 'PRESS', 'PULL', 'DRAW',
      'TENDER', 'GENTLE', 'SOFT', 'SMOOTH', 'SUPPLE', 'LITHE', 'NIMBLE', 'AGILE',
      'DREAM', 'FANTASY', 'IMAGINE', 'VISION', 'ILLUSION', 'MIRAGE', 'REVERIE', 'DAZE',
      'SECRET', 'HIDDEN', 'PRIVATE', 'INTIMATE', 'PERSONAL', 'SACRED', 'SPECIAL', 'PRECIOUS',
    ],
  },
};

// Grid class for puzzle generation
class WordSearchGrid {
  constructor(size = 10) {
    this.size = size;
    this.grid = Array(size).fill(null).map(() => Array(size).fill(''));
    this.placedWords = new Map(); // word -> "startIndex,direction"
  }

  // Shuffle array in place
  shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  // Try to place a word in the grid
  placeWord(word) {
    const directions = Object.keys(DIRECTIONS);
    this.shuffle(directions);

    for (const dir of directions) {
      const positions = this.getValidPositions(word, dir);
      this.shuffle(positions);

      for (const [row, col] of positions) {
        if (this.canPlaceWord(word, row, col, dir)) {
          this.doPlaceWord(word, row, col, dir);
          return true;
        }
      }
    }
    return false;
  }

  // Get all valid starting positions for a word in a direction
  getValidPositions(word, dir) {
    const [dr, dc] = DIRECTIONS[dir];
    const len = word.length;
    const positions = [];

    for (let r = 0; r < this.size; r++) {
      for (let c = 0; c < this.size; c++) {
        const endR = r + dr * (len - 1);
        const endC = c + dc * (len - 1);
        if (endR >= 0 && endR < this.size && endC >= 0 && endC < this.size) {
          positions.push([r, c]);
        }
      }
    }
    return positions;
  }

  // Check if word can be placed at position
  canPlaceWord(word, row, col, dir) {
    const [dr, dc] = DIRECTIONS[dir];

    for (let i = 0; i < word.length; i++) {
      const r = row + dr * i;
      const c = col + dc * i;
      const existing = this.grid[r][c];
      if (existing !== '' && existing !== word[i]) {
        return false;
      }
    }
    return true;
  }

  // Actually place the word in the grid
  doPlaceWord(word, row, col, dir) {
    const [dr, dc] = DIRECTIONS[dir];

    for (let i = 0; i < word.length; i++) {
      const r = row + dr * i;
      const c = col + dc * i;
      this.grid[r][c] = word[i];
    }

    // Store position as "startIndex,direction"
    const startIndex = row * this.size + col;
    this.placedWords.set(word, `${startIndex},${dir}`);
  }

  // Fill empty cells with random letters
  fillEmpty() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (let r = 0; r < this.size; r++) {
      for (let c = 0; c < this.size; c++) {
        if (this.grid[r][c] === '') {
          this.grid[r][c] = letters[Math.floor(Math.random() * letters.length)];
        }
      }
    }
  }

  // Get grid as single string
  getGridString() {
    return this.grid.flat().join('');
  }

  // Get placed words as object
  getPlacedWords() {
    return Object.fromEntries(this.placedWords);
  }
}

// Generate a single puzzle
function generatePuzzle(puzzleId, title, theme, wordPool) {
  const WORDS_PER_PUZZLE = 12;
  const MAX_ATTEMPTS = 50;

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const grid = new WordSearchGrid(10);
    const shuffledWords = [...wordPool].sort(() => Math.random() - 0.5);
    const placedWords = [];

    for (const word of shuffledWords) {
      if (placedWords.length >= WORDS_PER_PUZZLE) break;
      if (word.length < 3 || word.length > 8) continue;

      if (grid.placeWord(word)) {
        placedWords.push(word);
      }
    }

    if (placedWords.length === WORDS_PER_PUZZLE) {
      grid.fillEmpty();

      return {
        puzzle: {
          puzzleId,
          title,
          theme,
          size: { rows: 10, cols: 10 },
          grid: grid.getGridString(),
          words: grid.getPlacedWords(),
        },
        usedWords: placedWords,
      };
    }
  }

  return null;
}

// Convert number to Roman numeral
function romanNumeral(num) {
  const numerals = [
    [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'],
    [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']
  ];

  let result = '';
  for (const [value, symbol] of numerals) {
    while (num >= value) {
      result += symbol;
      num -= value;
    }
  }
  return result;
}

// Generate multiple puzzles for a branch
function generateBranchPuzzles(branch, count) {
  const config = WORD_LISTS[branch];
  if (!config) {
    console.error(`Unknown branch: ${branch}`);
    return;
  }

  const outputDir = path.join(__dirname, '..', 'data', 'puzzles', 'word-search', branch);

  // Create directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Clear existing puzzles
  const existingFiles = fs.readdirSync(outputDir).filter(f => f.endsWith('.json'));
  for (const file of existingFiles) {
    fs.unlinkSync(path.join(outputDir, file));
  }

  const puzzleIds = [];
  let availableWords = [...config.words];

  console.log(`\nGenerating ${count} puzzles for branch: ${branch}`);
  console.log(`Theme: ${config.theme}, Available words: ${availableWords.length}`);

  for (let i = 1; i <= count; i++) {
    const puzzleId = `ws_${String(i).padStart(3, '0')}`;
    const title = `${config.titlePrefix} ${romanNumeral(i)}`;

    // Replenish word pool if running low
    if (availableWords.length < 24) {
      availableWords = [...config.words];
    }

    const result = generatePuzzle(puzzleId, title, config.theme, availableWords);

    if (result) {
      // Remove used words from pool to encourage variety
      availableWords = availableWords.filter(w => !result.usedWords.includes(w));

      const filePath = path.join(outputDir, `${puzzleId}.json`);
      fs.writeFileSync(filePath, JSON.stringify(result.puzzle, null, 2));
      puzzleIds.push(puzzleId);
      console.log(`  ✓ Generated ${puzzleId}: "${title}" (${Object.keys(result.puzzle.words).length} words)`);
    } else {
      console.error(`  ✗ Failed to generate puzzle ${i}`);
    }
  }

  // Write puzzle-order.json
  const orderPath = path.join(outputDir, 'puzzle-order.json');
  fs.writeFileSync(orderPath, JSON.stringify({ puzzles: puzzleIds }, null, 2));
  console.log(`\n  ✓ Created puzzle-order.json with ${puzzleIds.length} puzzles`);
}

// Main
function main() {
  const args = process.argv.slice(2);
  const branch = args[0] || 'all';
  const count = parseInt(args[1]) || 20;

  console.log('='.repeat(60));
  console.log('Word Search Puzzle Generator');
  console.log('='.repeat(60));

  if (branch === 'all') {
    for (const b of ['everyday', 'passionate', 'naughty']) {
      generateBranchPuzzles(b, count);
    }
  } else if (WORD_LISTS[branch]) {
    generateBranchPuzzles(branch, count);
  } else {
    console.error(`Unknown branch: ${branch}`);
    console.error(`Valid branches: everyday, passionate, naughty, all`);
    process.exit(1);
  }

  console.log('\n' + '='.repeat(60));
  console.log('Generation complete!');
  console.log('='.repeat(60));
}

main();
