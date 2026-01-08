/**
 * Us Profile Cache Management
 *
 * Handles reading/writing profile cache from Supabase.
 * Cache is updated on every quiz completion.
 */

import { query } from '@/lib/db/pool';
import { UsProfileResult, calculateUsProfile } from './calculator';
import { FramedProfile, frameProfile, ConversationStarter, RelevanceContext } from './framing';
import { getDiscoveryAppreciations } from './relevance';

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

  // Track newly unlocked dimensions
  await updateDimensionUnlocks(coupleId, profile);

  // Generate and store new conversation starters
  await updateConversationStarters(coupleId, profile);

  return profile;
}

/**
 * Track when dimensions are first unlocked (have data points).
 * Updates the dimension_unlocks JSONB column in couples table.
 */
async function updateDimensionUnlocks(coupleId: string, profile: UsProfileResult): Promise<void> {
  // Get current unlock timestamps
  const coupleResult = await query(
    `SELECT dimension_unlocks FROM couples WHERE id = $1`,
    [coupleId]
  );

  if (coupleResult.rows.length === 0) return;

  const existingUnlocks: Record<string, string> = coupleResult.rows[0].dimension_unlocks || {};

  // Find all dimensions that have data points in the profile
  const dimensionsWithData = new Set<string>();

  // Check user1 dimensions
  for (const dim of profile.user1Insights.dimensions) {
    if (dim.totalAnswers > 0) {
      dimensionsWithData.add(dim.dimensionId);
    }
  }

  // Check user2 dimensions
  for (const dim of profile.user2Insights.dimensions) {
    if (dim.totalAnswers > 0) {
      dimensionsWithData.add(dim.dimensionId);
    }
  }

  // Record timestamps for newly unlocked dimensions
  let hasNewUnlocks = false;
  const now = new Date().toISOString();

  for (const dimId of dimensionsWithData) {
    if (!existingUnlocks[dimId]) {
      existingUnlocks[dimId] = now;
      hasNewUnlocks = true;
    }
  }

  // Only update if there are new unlocks
  if (hasNewUnlocks) {
    await query(
      `UPDATE couples SET dimension_unlocks = $1 WHERE id = $2`,
      [JSON.stringify(existingUnlocks), coupleId]
    );
  }
}

/**
 * Get dimension unlock timestamps for a couple.
 */
export async function getDimensionUnlocks(coupleId: string): Promise<Record<string, string>> {
  const result = await query(
    `SELECT dimension_unlocks FROM couples WHERE id = $1`,
    [coupleId]
  );

  if (result.rows.length === 0) return {};
  return result.rows[0].dimension_unlocks || {};
}

/**
 * Get couple details including user IDs and names.
 */
async function getCoupleDetails(coupleId: string): Promise<{
  user1Id: string;
  user2Id: string;
  user1Name: string;
  user2Name: string;
} | null> {
  const result = await query(
    `SELECT c.user1_id, c.user2_id,
            COALESCE(u1.raw_user_meta_data->>'full_name', 'Partner 1') as user1_name,
            COALESCE(u2.raw_user_meta_data->>'full_name', 'Partner 2') as user2_name
     FROM couples c
     JOIN auth.users u1 ON c.user1_id = u1.id
     JOIN auth.users u2 ON c.user2_id = u2.id
     WHERE c.id = $1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    user1Id: row.user1_id,
    user2Id: row.user2_id,
    user1Name: row.user1_name || 'Partner 1',
    user2Name: row.user2_name || 'Partner 2',
  };
}

/**
 * Get framed profile for display.
 * Tries cache first, recalculates if stale or missing.
 *
 * @param coupleId - The couple's ID
 * @param userId - The requesting user's ID (for relevance personalization)
 */
export async function getFramedProfile(
  coupleId: string,
  userId?: string
): Promise<FramedProfile> {
  // First check cache
  let cachedProfile = await getCachedProfile(coupleId);

  // If no cache, calculate fresh
  if (!cachedProfile) {
    const profile = await recalculateAndCacheProfile(coupleId);

    // Build relevance context if userId provided
    const relevanceContext = userId
      ? await buildRelevanceContext(coupleId, userId)
      : undefined;

    return frameProfile(profile, relevanceContext);
  }

  // Reconstruct UsProfileResult from cache
  const profile: UsProfileResult = {
    user1Insights: cachedProfile.user1Insights as any,
    user2Insights: cachedProfile.user2Insights as any,
    coupleInsights: cachedProfile.coupleInsights as any,
    totalQuizzesCompleted: cachedProfile.totalQuizzesCompleted,
  };

  // Build relevance context if userId provided
  const relevanceContext = userId
    ? await buildRelevanceContext(coupleId, userId)
    : undefined;

  return frameProfile(profile, relevanceContext);
}

/**
 * Build relevance context for personalized discovery ranking.
 */
async function buildRelevanceContext(
  coupleId: string,
  userId: string
): Promise<RelevanceContext | undefined> {
  const coupleDetails = await getCoupleDetails(coupleId);
  if (!coupleDetails) {
    return undefined;
  }

  const { user1Id, user2Id, user1Name, user2Name } = coupleDetails;

  // Fetch appreciations
  const appreciationsMap = await getDiscoveryAppreciations(coupleId, user1Id, user2Id);

  // Fetch dimension unlock timestamps
  const dimensionUnlocks = await getDimensionUnlocks(coupleId);

  // TODO: Calculate days since last activity (for contextual headers)
  // For now, default to 0 (recent activity)
  const daysSinceLastActivity = 0;

  return {
    userId,
    user1Id,
    user2Id,
    user1Name,
    user2Name,
    appreciationsMap,
    daysSinceLastActivity,
    dimensionUnlocks,
  };
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
