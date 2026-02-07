/**
 * Linked game configuration constants.
 *
 * These constants define Linked game behavior that needs to be
 * consistent between Flutter client and API server.
 *
 * IMPORTANT: Keep in sync with app/lib/config/linked_constants.dart
 */
export const LINKED_CONFIG = {
  /** Number of letters in the rack (5, 6, or 7) */
  RACK_SIZE: 5,

  /** Number of hints at the start of the game */
  STARTING_HINTS: 2,
} as const;
