/**
 * Puzzle Loading Utilities
 *
 * Shared utilities for loading puzzle data from the filesystem.
 * Used by Linked, Word Search, and other puzzle-based games.
 */

import { readFileSync } from 'fs';
import { join } from 'path';
import { query } from '@/lib/db/pool';
import { PoolClient } from 'pg';

// =============================================================================
// Types
// =============================================================================

export type PuzzleType = 'linked' | 'wordSearch';

export interface BranchConfig {
  activityType: string;  // Database activity_type value
  folder: string;        // Filesystem folder name
  branches: string[];    // Branch folder names in order
  defaultBranch: string; // Default branch if no progression exists
  orderFile: string;     // Name of puzzle order file (puzzle-order.json or quiz-order.json)
}

// =============================================================================
// Configuration
// =============================================================================

const PUZZLE_CONFIG: Record<PuzzleType, BranchConfig> = {
  linked: {
    activityType: 'linked',
    folder: 'linked',
    branches: ['casual', 'romantic', 'adult'],
    defaultBranch: 'casual',
    orderFile: 'puzzle-order.json',
  },
  wordSearch: {
    activityType: 'wordSearch',
    folder: 'word-search',
    branches: ['everyday', 'passionate', 'naughty'],
    defaultBranch: 'everyday',
    orderFile: 'puzzle-order.json',
  },
};

// =============================================================================
// Puzzle Loading
// =============================================================================

/**
 * Load puzzle data from the filesystem.
 *
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param puzzleId - The puzzle ID (e.g., 'puzzle_001')
 * @param branch - Optional branch name (defaults to first branch for puzzle type)
 * @returns Parsed puzzle data or null if not found
 *
 * @example
 * const puzzle = loadPuzzle('linked', 'puzzle_001', 'romantic');
 * if (!puzzle) {
 *   return NextResponse.json({ error: 'Puzzle not found' }, { status: 404 });
 * }
 */
export function loadPuzzle(
  puzzleType: PuzzleType,
  puzzleId: string,
  branch?: string
): any {
  try {
    const config = PUZZLE_CONFIG[puzzleType];
    const branchFolder = branch || config.defaultBranch;
    const puzzlePath = join(
      process.cwd(),
      'data',
      'puzzles',
      config.folder,
      branchFolder,
      `${puzzleId}.json`
    );
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load ${puzzleType} puzzle ${puzzleId}:`, error);
    return null;
  }
}

/**
 * Load puzzle order configuration for a branch.
 *
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param branch - Optional branch name (defaults to first branch for puzzle type)
 * @returns Array of puzzle IDs in order, or default fallback
 *
 * @example
 * const puzzleOrder = loadPuzzleOrder('wordSearch', 'everyday');
 * // Returns: ['ws_001', 'ws_002', ...]
 */
export function loadPuzzleOrder(
  puzzleType: PuzzleType,
  branch?: string
): string[] {
  try {
    const config = PUZZLE_CONFIG[puzzleType];
    const branchFolder = branch || config.defaultBranch;
    const orderPath = join(
      process.cwd(),
      'data',
      'puzzles',
      config.folder,
      branchFolder,
      config.orderFile
    );
    const orderData = readFileSync(orderPath, 'utf-8');
    const orderConfig = JSON.parse(orderData);
    return orderConfig.puzzles || [];
  } catch (error) {
    console.error(`Failed to load ${puzzleType} puzzle order for branch ${branch}:`, error);
    // Return default fallback
    return puzzleType === 'linked' ? ['puzzle_001'] : ['ws_001'];
  }
}

// =============================================================================
// Branch Management
// =============================================================================

/**
 * Get the branch folder name for a given branch index.
 *
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param branchIndex - Index from branch_progression table
 * @returns Branch folder name
 *
 * @example
 * getBranchFolderName('linked', 1);  // Returns 'romantic'
 * getBranchFolderName('wordSearch', 2);  // Returns 'naughty'
 */
export function getBranchFolderName(
  puzzleType: PuzzleType,
  branchIndex: number
): string {
  const config = PUZZLE_CONFIG[puzzleType];
  return config.branches[branchIndex % config.branches.length];
}

/**
 * Get current branch for a couple based on their progression.
 *
 * @param coupleId - The couple's ID
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param client - Optional database client (for use within transactions)
 * @returns Branch folder name
 *
 * @example
 * const branch = await getCurrentBranch(coupleId, 'linked');
 * const puzzle = loadPuzzle('linked', puzzleId, branch);
 */
export async function getCurrentBranch(
  coupleId: string,
  puzzleType: PuzzleType,
  client?: PoolClient
): Promise<string> {
  const config = PUZZLE_CONFIG[puzzleType];
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT current_branch FROM branch_progression
     WHERE couple_id = $1 AND activity_type = $2`,
    [coupleId, config.activityType]
  );

  if (result.rows.length === 0) {
    return config.defaultBranch;
  }

  const branchIndex = result.rows[0].current_branch;
  return getBranchFolderName(puzzleType, branchIndex);
}

// =============================================================================
// Cooldown Management
// =============================================================================

/**
 * Check if cooldown is enabled via environment variable.
 * Defaults to true in production.
 */
export function isCooldownEnabled(): boolean {
  return process.env.PUZZLE_COOLDOWN_ENABLED !== 'false';
}

/**
 * Check if cooldown is active for a puzzle type.
 * Cooldown is active if the couple completed a puzzle today.
 *
 * @param coupleId - The couple's ID
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param clientLocalDate - Client's local date in YYYY-MM-DD format
 * @param client - Optional database client (for use within transactions)
 * @returns true if cooldown is active (should block new puzzle)
 *
 * @example
 * if (await isCooldownActive(coupleId, 'wordSearch', '2024-01-15')) {
 *   return NextResponse.json({
 *     success: false,
 *     code: 'COOLDOWN_ACTIVE',
 *     message: 'Next puzzle available tomorrow',
 *   });
 * }
 */
export async function isCooldownActive(
  coupleId: string,
  puzzleType: PuzzleType,
  clientLocalDate: string | null,
  client?: PoolClient
): Promise<boolean> {
  if (!isCooldownEnabled() || !clientLocalDate) {
    return false;
  }

  const tableName = puzzleType === 'linked' ? 'linked_matches' : 'word_search_matches';
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT completed_at FROM ${tableName}
     WHERE couple_id = $1 AND status = 'completed'
     ORDER BY completed_at DESC LIMIT 1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return false;
  }

  const completedAt = new Date(result.rows[0].completed_at);
  const completedDateStr = completedAt.toISOString().split('T')[0];

  return completedDateStr === clientLocalDate;
}

// =============================================================================
// Puzzle Discovery
// =============================================================================

/**
 * Get the next puzzle for a couple (either active match or first uncompleted).
 *
 * @param coupleId - The couple's ID
 * @param puzzleType - Type of puzzle ('linked' or 'wordSearch')
 * @param client - Optional database client (for use within transactions)
 * @returns Object with puzzleId, activeMatch (if exists), and branch
 *
 * @example
 * const { puzzleId, activeMatch, branch } = await getNextPuzzle(coupleId, 'linked');
 * if (!puzzleId) {
 *   return NextResponse.json({ error: 'All puzzles completed' }, { status: 404 });
 * }
 */
export async function getNextPuzzle(
  coupleId: string,
  puzzleType: PuzzleType,
  client?: PoolClient
): Promise<{ puzzleId: string | null; activeMatch: any | null; branch: string }> {
  const branch = await getCurrentBranch(coupleId, puzzleType, client);
  const puzzleOrder = loadPuzzleOrder(puzzleType, branch);
  const queryFn = client ? client.query.bind(client) : query;

  const tableName = puzzleType === 'linked' ? 'linked_matches' : 'word_search_matches';

  // Check for any active match first
  const activeResult = await queryFn(
    `SELECT * FROM ${tableName}
     WHERE couple_id = $1 AND status = 'active'
     ORDER BY created_at DESC LIMIT 1`,
    [coupleId]
  );

  if (activeResult.rows.length > 0) {
    return {
      puzzleId: activeResult.rows[0].puzzle_id,
      activeMatch: activeResult.rows[0],
      branch,
    };
  }

  // Get all completed puzzles for this couple
  const completedResult = await queryFn(
    `SELECT DISTINCT puzzle_id FROM ${tableName}
     WHERE couple_id = $1 AND status = 'completed'`,
    [coupleId]
  );

  const completedPuzzles = new Set(completedResult.rows.map(r => r.puzzle_id));

  // Find first uncompleted puzzle
  for (const puzzleId of puzzleOrder) {
    if (!completedPuzzles.has(puzzleId)) {
      return { puzzleId, activeMatch: null, branch };
    }
  }

  // All puzzles completed
  return { puzzleId: null, activeMatch: null, branch };
}

// =============================================================================
// Exports
// =============================================================================

export { PUZZLE_CONFIG };
