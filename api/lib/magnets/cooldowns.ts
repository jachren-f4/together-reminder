/**
 * Cooldown Service for Magnet Collection System
 *
 * Rules:
 * - Each activity type has SEPARATE cooldown
 * - 2 plays per activity type, then 8-hour cooldown
 * - Cooldown resets when timer expires
 *
 * Activity types: classic_quiz, affirmation_quiz, you_or_me, linked, wordsearch
 */

import { query } from '../db/pool';

export type ActivityType =
  | 'classic_quiz'
  | 'affirmation_quiz'
  | 'you_or_me'
  | 'linked'
  | 'wordsearch';

export const BATCH_SIZE = 2;  // 2 plays before cooldown
export const COOLDOWN_HOURS = 8;

export interface CooldownEntry {
  batch_count: number;
  cooldown_until: string | null;  // ISO timestamp
}

export interface CooldownsMap {
  [key: string]: CooldownEntry;
}

export interface CooldownStatus {
  canPlay: boolean;
  remainingInBatch: number;  // 0, 1, or 2
  cooldownEndsAt: Date | null;
  cooldownRemainingMs: number | null;
}

/**
 * Get cooldown status for a specific activity type
 */
export async function getCooldownStatus(
  coupleId: string,
  activityType: ActivityType
): Promise<CooldownStatus> {
  const result = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const cooldowns: CooldownsMap = result.rows[0].cooldowns || {};
  const entry = cooldowns[activityType];

  // No entry = fresh state, can play
  if (!entry) {
    return {
      canPlay: true,
      remainingInBatch: BATCH_SIZE,
      cooldownEndsAt: null,
      cooldownRemainingMs: null,
    };
  }

  const now = new Date();

  // Check if there's an active cooldown
  if (entry.cooldown_until) {
    const cooldownEnd = new Date(entry.cooldown_until);

    if (cooldownEnd > now) {
      // Still on cooldown
      return {
        canPlay: false,
        remainingInBatch: 0,
        cooldownEndsAt: cooldownEnd,
        cooldownRemainingMs: cooldownEnd.getTime() - now.getTime(),
      };
    }

    // Cooldown expired - reset and allow play
    return {
      canPlay: true,
      remainingInBatch: BATCH_SIZE,
      cooldownEndsAt: null,
      cooldownRemainingMs: null,
    };
  }

  // No cooldown, check batch count
  const remaining = BATCH_SIZE - entry.batch_count;
  return {
    canPlay: remaining > 0,
    remainingInBatch: Math.max(0, remaining),
    cooldownEndsAt: null,
    cooldownRemainingMs: null,
  };
}

/**
 * Record a play and potentially start cooldown
 * Call this AFTER a game is completed (results reviewed)
 */
export async function recordActivityPlay(
  coupleId: string,
  activityType: ActivityType
): Promise<{
  cooldownStarted: boolean;
  cooldownEndsAt: Date | null;
  remainingInBatch: number;
}> {
  // Get current cooldowns
  const result = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const cooldowns: CooldownsMap = result.rows[0].cooldowns || {};
  const now = new Date();

  // Get or create entry for this activity
  let entry = cooldowns[activityType];

  // Check if cooldown expired - if so, reset
  if (entry?.cooldown_until) {
    const cooldownEnd = new Date(entry.cooldown_until);
    if (cooldownEnd <= now) {
      // Cooldown expired, reset
      entry = { batch_count: 0, cooldown_until: null };
    }
  }

  if (!entry) {
    entry = { batch_count: 0, cooldown_until: null };
  }

  // Increment batch count
  entry.batch_count += 1;

  let cooldownStarted = false;
  let cooldownEndsAt: Date | null = null;

  // Check if we've hit the batch limit
  if (entry.batch_count >= BATCH_SIZE) {
    cooldownStarted = true;
    cooldownEndsAt = new Date(now.getTime() + COOLDOWN_HOURS * 60 * 60 * 1000);
    entry.cooldown_until = cooldownEndsAt.toISOString();
  }

  // Update cooldowns in database
  cooldowns[activityType] = entry;

  await query(
    'UPDATE couples SET cooldowns = $1, updated_at = NOW() WHERE id = $2',
    [JSON.stringify(cooldowns), coupleId]
  );

  const remainingInBatch = cooldownStarted ? 0 : BATCH_SIZE - entry.batch_count;

  return {
    cooldownStarted,
    cooldownEndsAt,
    remainingInBatch,
  };
}

/**
 * Get cooldown status for ALL activity types
 */
export async function getAllCooldownStatuses(
  coupleId: string
): Promise<Record<ActivityType, CooldownStatus>> {
  const activityTypes: ActivityType[] = [
    'classic_quiz',
    'affirmation_quiz',
    'you_or_me',
    'linked',
    'wordsearch',
  ];

  const result = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const cooldowns: CooldownsMap = result.rows[0].cooldowns || {};
  const now = new Date();

  const statuses: Record<string, CooldownStatus> = {};

  for (const activityType of activityTypes) {
    const entry = cooldowns[activityType];

    if (!entry) {
      statuses[activityType] = {
        canPlay: true,
        remainingInBatch: BATCH_SIZE,
        cooldownEndsAt: null,
        cooldownRemainingMs: null,
      };
      continue;
    }

    if (entry.cooldown_until) {
      const cooldownEnd = new Date(entry.cooldown_until);

      if (cooldownEnd > now) {
        statuses[activityType] = {
          canPlay: false,
          remainingInBatch: 0,
          cooldownEndsAt: cooldownEnd,
          cooldownRemainingMs: cooldownEnd.getTime() - now.getTime(),
        };
        continue;
      }

      // Cooldown expired
      statuses[activityType] = {
        canPlay: true,
        remainingInBatch: BATCH_SIZE,
        cooldownEndsAt: null,
        cooldownRemainingMs: null,
      };
      continue;
    }

    const remaining = BATCH_SIZE - entry.batch_count;
    statuses[activityType] = {
      canPlay: remaining > 0,
      remainingInBatch: Math.max(0, remaining),
      cooldownEndsAt: null,
      cooldownRemainingMs: null,
    };
  }

  return statuses as Record<ActivityType, CooldownStatus>;
}

/**
 * Reset cooldown for a specific activity (admin/testing use)
 */
export async function resetCooldown(
  coupleId: string,
  activityType: ActivityType
): Promise<void> {
  const result = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const cooldowns: CooldownsMap = result.rows[0].cooldowns || {};
  delete cooldowns[activityType];

  await query(
    'UPDATE couples SET cooldowns = $1, updated_at = NOW() WHERE id = $2',
    [JSON.stringify(cooldowns), coupleId]
  );
}

/**
 * Reset ALL cooldowns for a couple (admin/testing use)
 */
export async function resetAllCooldowns(coupleId: string): Promise<void> {
  await query(
    "UPDATE couples SET cooldowns = '{}', updated_at = NOW() WHERE id = $1",
    [coupleId]
  );
}
