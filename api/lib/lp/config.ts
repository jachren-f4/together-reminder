/**
 * Love Points (LP) Configuration
 *
 * Central location for all LP reward values.
 * All game completion routes should import from here.
 */

// Base LP rewards for completing activities
export const LP_REWARDS = {
  // Quiz activities (30 LP each)
  QUIZ_CLASSIC: 30,
  QUIZ_AFFIRMATION: 30,
  QUIZ_WOULD_YOU_RATHER: 30,  // Base LP before alignment bonus

  // Turn-based games (30 LP each)
  YOU_OR_ME: 30,
  LINKED: 30,
  WORD_SEARCH: 30,

  // Steps Together (variable)
  STEPS_CLAIM: 15,  // Base value; actual amount may vary
} as const;

// Bonus LP values
export const LP_BONUSES = {
  // Would You Rather alignment bonus per match
  WYR_ALIGNMENT_PER_MATCH: 5,
} as const;

// Scoring constants
export const SCORING = {
  // Linked game
  LINKED_POINTS_PER_LETTER: 10,

  // Word Search game
  WORD_SEARCH_POINTS_PER_LETTER: 10,
} as const;

// Type exports for use in route handlers
export type LPRewardType = keyof typeof LP_REWARDS;
export type LPBonusType = keyof typeof LP_BONUSES;
