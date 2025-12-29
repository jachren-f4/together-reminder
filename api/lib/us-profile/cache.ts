/**
 * Us Profile Cache Management
 *
 * Handles reading/writing profile cache from Supabase.
 * Cache is updated on every quiz completion.
 */

import { query } from '@/lib/db/pool';
import { UsProfileResult, calculateUsProfile } from './calculator';
import { FramedProfile, frameProfile, ConversationStarter } from './framing';

// =============================================================================
// Types
// =============================================================================

export interface CachedProfile {
  coupleId: string;
  user1Insights: unknown;
  user2Insights: unknown;
  coupleInsights: unknown;
  totalQuizzesCompleted: number;
  updatedAt: string;
}

// =============================================================================
// Cache Read/Write
// =============================================================================

/**
 * Get cached profile for a couple.
 * Returns null if no cache exists.
 */
export async function getCachedProfile(coupleId: string): Promise<CachedProfile | null> {
  const result = await query(
    `SELECT couple_id, user1_insights, user2_insights, couple_insights,
            total_quizzes_completed, updated_at
     FROM us_profile_cache
     WHERE couple_id = $1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    coupleId: row.couple_id,
    user1Insights: row.user1_insights,
    user2Insights: row.user2_insights,
    coupleInsights: row.couple_insights,
    totalQuizzesCompleted: row.total_quizzes_completed,
    updatedAt: row.updated_at,
  };
}

/**
 * Update profile cache for a couple.
 * Creates new entry if none exists (UPSERT).
 */
export async function updateCache(coupleId: string, profile: UsProfileResult): Promise<void> {
  await query(
    `INSERT INTO us_profile_cache (
      couple_id, user1_insights, user2_insights, couple_insights,
      total_quizzes_completed, updated_at
    ) VALUES ($1, $2, $3, $4, $5, NOW())
    ON CONFLICT (couple_id) DO UPDATE SET
      user1_insights = $2,
      user2_insights = $3,
      couple_insights = $4,
      total_quizzes_completed = $5,
      updated_at = NOW()`,
    [
      coupleId,
      JSON.stringify(profile.user1Insights),
      JSON.stringify(profile.user2Insights),
      JSON.stringify(profile.coupleInsights),
      profile.totalQuizzesCompleted,
    ]
  );
}

/**
 * Full recalculation: loads all quiz data, calculates profile, updates cache.
 * Called after every quiz completion.
 */
export async function recalculateAndCacheProfile(coupleId: string): Promise<UsProfileResult> {
  // Calculate fresh profile from all quiz data
  const profile = await calculateUsProfile(coupleId);

  // Update cache
  await updateCache(coupleId, profile);

  // Generate and store new conversation starters
  await updateConversationStarters(coupleId, profile);

  return profile;
}

/**
 * Get framed profile for display.
 * Tries cache first, recalculates if stale or missing.
 */
export async function getFramedProfile(coupleId: string): Promise<FramedProfile> {
  // First check cache
  let cachedProfile = await getCachedProfile(coupleId);

  // If no cache, calculate fresh
  if (!cachedProfile) {
    const profile = await recalculateAndCacheProfile(coupleId);
    return frameProfile(profile);
  }

  // Reconstruct UsProfileResult from cache
  const profile: UsProfileResult = {
    user1Insights: cachedProfile.user1Insights as any,
    user2Insights: cachedProfile.user2Insights as any,
    coupleInsights: cachedProfile.coupleInsights as any,
    totalQuizzesCompleted: cachedProfile.totalQuizzesCompleted,
  };

  return frameProfile(profile);
}

// =============================================================================
// Conversation Starters
// =============================================================================

/**
 * Update conversation starters based on profile.
 * Removes old starters and creates new ones.
 */
async function updateConversationStarters(coupleId: string, profile: UsProfileResult): Promise<void> {
  const framed = frameProfile(profile);
  const starters = framed.conversationStarters;

  // Delete old starters that haven't been interacted with
  await query(
    `DELETE FROM conversation_starters
     WHERE couple_id = $1 AND dismissed = FALSE AND discussed = FALSE`,
    [coupleId]
  );

  // Insert new starters
  for (const starter of starters) {
    await query(
      `INSERT INTO conversation_starters (couple_id, trigger_type, data)
       VALUES ($1, $2, $3)`,
      [
        coupleId,
        starter.triggerType,
        JSON.stringify({
          triggerData: starter.triggerData,
          promptText: starter.promptText,
          contextText: starter.contextText,
        }),
      ]
    );
  }
}

/**
 * Get active conversation starters for a couple.
 */
export async function getActiveConversationStarters(coupleId: string): Promise<ConversationStarter[]> {
  const result = await query(
    `SELECT trigger_type, data
     FROM conversation_starters
     WHERE couple_id = $1 AND dismissed = FALSE
     ORDER BY created_at DESC
     LIMIT 5`,
    [coupleId]
  );

  return result.rows.map(row => ({
    triggerType: row.trigger_type,
    ...row.data,
  }));
}

/**
 * Mark a conversation starter as dismissed.
 */
export async function dismissConversationStarter(starterId: string): Promise<void> {
  await query(
    `UPDATE conversation_starters SET dismissed = TRUE WHERE id = $1`,
    [starterId]
  );
}

/**
 * Mark a conversation starter as discussed.
 */
export async function markStarterDiscussed(starterId: string): Promise<void> {
  await query(
    `UPDATE conversation_starters SET discussed = TRUE WHERE id = $1`,
    [starterId]
  );
}
