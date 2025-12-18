/**
 * LP Daily Reset Utilities
 *
 * Handles LP day calculation with configurable UTC offset for reset time.
 * Default: Reset at midnight UTC (LP_RESET_HOUR_UTC=0)
 *
 * Example: LP_RESET_HOUR_UTC=7 means LP day resets at 7:00 UTC
 * (which is midnight for UTC+7 timezone)
 */

/**
 * Get the configured reset hour in UTC (0-23)
 * Default: 0 (midnight UTC)
 */
export function getResetHourUTC(): number {
  const envValue = process.env.LP_RESET_HOUR_UTC;
  if (!envValue) return 0;

  const hour = parseInt(envValue, 10);
  if (isNaN(hour) || hour < 0 || hour > 23) {
    console.warn(`Invalid LP_RESET_HOUR_UTC value: ${envValue}, using default 0`);
    return 0;
  }
  return hour;
}

/**
 * Check if unlimited content is allowed after LP has been earned
 * Default: true (users can play more even after earning LP)
 */
export function isUnlimitedContentAllowed(): boolean {
  const envValue = process.env.LP_ALLOW_UNLIMITED_CONTENT;
  // Default to true if not set
  if (envValue === undefined || envValue === '') return true;
  return envValue.toLowerCase() === 'true';
}

/**
 * Calculate the LP day for a given timestamp
 *
 * The LP day is the date (YYYY-MM-DD) adjusted for the reset hour.
 * If reset hour is 7 UTC, then:
 * - 2024-01-15 06:59 UTC → LP day is 2024-01-14
 * - 2024-01-15 07:00 UTC → LP day is 2024-01-15
 *
 * @param timestamp - The timestamp to calculate LP day for (default: now)
 * @returns LP day as YYYY-MM-DD string
 */
export function getLpDay(timestamp: Date = new Date()): string {
  const resetHour = getResetHourUTC();

  // Create a copy to avoid mutating the input
  const adjusted = new Date(timestamp);

  // Subtract the reset hour offset to normalize to "LP midnight"
  adjusted.setUTCHours(adjusted.getUTCHours() - resetHour);

  // Return the date portion
  return adjusted.toISOString().split('T')[0];
}

/**
 * Get the next reset time as a Date object
 *
 * @param now - Current time (default: now)
 * @returns Date of next LP reset
 */
export function getNextResetTime(now: Date = new Date()): Date {
  const resetHour = getResetHourUTC();

  // Start with today at reset hour
  const nextReset = new Date(now);
  nextReset.setUTCHours(resetHour, 0, 0, 0);

  // If we've already passed today's reset, go to tomorrow
  if (now >= nextReset) {
    nextReset.setUTCDate(nextReset.getUTCDate() + 1);
  }

  return nextReset;
}

/**
 * Get milliseconds until the next LP reset
 *
 * @param now - Current time (default: now)
 * @returns Milliseconds until next reset
 */
export function getTimeUntilReset(now: Date = new Date()): number {
  const nextReset = getNextResetTime(now);
  return nextReset.getTime() - now.getTime();
}

/**
 * Format time until reset as human-readable string
 *
 * @param ms - Milliseconds until reset
 * @returns Formatted string like "5h 30m" or "45m"
 */
export function formatTimeUntilReset(ms: number): string {
  const hours = Math.floor(ms / (1000 * 60 * 60));
  const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

/**
 * Valid content types for LP grants
 */
export type LpContentType =
  | 'classic_quiz'
  | 'affirmation_quiz'
  | 'you_or_me'
  | 'linked'
  | 'word_search';

/**
 * Validate that a string is a valid LP content type
 */
export function isValidContentType(type: string): type is LpContentType {
  return [
    'classic_quiz',
    'affirmation_quiz',
    'you_or_me',
    'linked',
    'word_search',
  ].includes(type);
}
