/**
 * Magnet Collection Calculator
 *
 * Calculates magnet unlocks based on LP (Love Points).
 * Magnets are NOT stored in database - they're computed from couples.total_lp.
 *
 * LP Requirements per magnet:
 * - Magnets 1-3: 600 LP each
 * - Magnets 4-6: 700 LP each
 * - Magnets 7-9: 800 LP each
 * - Magnets 10-12: 900 LP each
 * - Magnets 13-15: 1000 LP each
 * - Magnets 16-18: 1100 LP each
 * - Magnets 19-21: 1200 LP each
 * - Magnets 22-24: 1300 LP each
 * - Magnets 25-27: 1400 LP each
 * - Magnets 28-30: 1500 LP each
 */

export const TOTAL_MAGNETS = 30;

/**
 * Get LP requirement for a specific magnet (1-indexed)
 */
export function getLPRequirement(magnetNumber: number): number {
  if (magnetNumber < 1 || magnetNumber > TOTAL_MAGNETS) {
    throw new Error(`Invalid magnet number: ${magnetNumber}. Must be 1-${TOTAL_MAGNETS}`);
  }

  // Tier = which group of 3 (0-indexed): 0 for 1-3, 1 for 4-6, etc.
  const tier = Math.floor((magnetNumber - 1) / 3);

  // Base LP is 600, increases by 100 every 3 magnets
  return 600 + (tier * 100);
}

/**
 * Get cumulative LP needed to unlock a specific magnet
 */
export function getCumulativeLPForMagnet(magnetNumber: number): number {
  let total = 0;
  for (let i = 1; i <= magnetNumber; i++) {
    total += getLPRequirement(i);
  }
  return total;
}

/**
 * Get number of magnets unlocked for a given LP amount
 */
export function getUnlockedMagnetCount(totalLp: number): number {
  let cumulativeLp = 0;
  let magnetsUnlocked = 0;

  for (let i = 1; i <= TOTAL_MAGNETS; i++) {
    cumulativeLp += getLPRequirement(i);
    if (totalLp >= cumulativeLp) {
      magnetsUnlocked = i;
    } else {
      break;
    }
  }

  return magnetsUnlocked;
}

/**
 * Get progress info toward next magnet
 */
export interface MagnetProgress {
  unlockedCount: number;
  nextMagnetId: number | null;  // null if all 30 unlocked
  currentLp: number;
  lpForNextMagnet: number;      // LP needed for next magnet (not cumulative)
  lpProgressToNext: number;      // LP progress toward next magnet
  progressPercent: number;       // 0-100
  totalMagnets: number;
  allUnlocked: boolean;
}

export function getMagnetProgress(totalLp: number): MagnetProgress {
  const unlockedCount = getUnlockedMagnetCount(totalLp);
  const allUnlocked = unlockedCount >= TOTAL_MAGNETS;

  if (allUnlocked) {
    return {
      unlockedCount,
      nextMagnetId: null,
      currentLp: totalLp,
      lpForNextMagnet: 0,
      lpProgressToNext: 0,
      progressPercent: 100,
      totalMagnets: TOTAL_MAGNETS,
      allUnlocked: true,
    };
  }

  const nextMagnetId = unlockedCount + 1;
  const lpForNextMagnet = getLPRequirement(nextMagnetId);
  const cumulativeForCurrent = unlockedCount > 0 ? getCumulativeLPForMagnet(unlockedCount) : 0;
  const lpProgressToNext = totalLp - cumulativeForCurrent;
  const progressPercent = Math.min(100, Math.floor((lpProgressToNext / lpForNextMagnet) * 100));

  return {
    unlockedCount,
    nextMagnetId,
    currentLp: totalLp,
    lpForNextMagnet,
    lpProgressToNext,
    progressPercent,
    totalMagnets: TOTAL_MAGNETS,
    allUnlocked: false,
  };
}

/**
 * Detect if an LP change results in a new magnet unlock
 * Returns the newly unlocked magnet ID, or null if no unlock
 */
export function detectUnlock(oldLp: number, newLp: number): number | null {
  const magnetsBefore = getUnlockedMagnetCount(oldLp);
  const magnetsAfter = getUnlockedMagnetCount(newLp);

  if (magnetsAfter > magnetsBefore) {
    // Return the first newly unlocked magnet
    return magnetsBefore + 1;
  }

  return null;
}

/**
 * Get all magnets that would be unlocked by an LP change
 * Returns array of magnet IDs (for bulk unlock scenarios)
 */
export function detectAllUnlocks(oldLp: number, newLp: number): number[] {
  const magnetsBefore = getUnlockedMagnetCount(oldLp);
  const magnetsAfter = getUnlockedMagnetCount(newLp);

  const newMagnets: number[] = [];
  for (let i = magnetsBefore + 1; i <= magnetsAfter; i++) {
    newMagnets.push(i);
  }

  return newMagnets;
}

// Pre-computed thresholds for quick lookup
export const MAGNET_THRESHOLDS = Array.from({ length: TOTAL_MAGNETS }, (_, i) =>
  getCumulativeLPForMagnet(i + 1)
);

// For reference: [600, 1200, 1800, 2500, 3200, 3900, 4700, 5500, 6300, 7200, ...]
