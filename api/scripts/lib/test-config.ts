/**
 * Shared Test Configuration
 *
 * Single source of truth for test user IDs, API URLs, and game-specific constants.
 * Used by all game test helpers (quiz, linked, word-search, etc.)
 */

// Core test configuration - shared across all game tests
export const TEST_CONFIG = {
  // Test users (from DevConfig - matches real database)
  testUserId: 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28', // TestiY (user1_id)
  partnerUserId: 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a', // Jokke (user2_id)
  coupleId: '11111111-1111-1111-1111-111111111111',

  // API configuration
  apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
};

// Quiz-specific configuration
export const QUIZ_CONFIG = {
  lpRewardOnCompletion: 30,
};

// Linked game-specific configuration
export const LINKED_CONFIG = {
  pointsPerLetter: 10,
  lpRewardOnCompletion: 30,
};

// Word Search-specific configuration
export const WORD_SEARCH_CONFIG = {
  lpRewardOnCompletion: 30,
};
