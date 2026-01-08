/**
 * Discovery Relevance Scoring
 *
 * Ranks discoveries by therapeutic value using:
 * - Stakes level (high/medium/light)
 * - Appreciation signals from partners
 * - Pattern detection (recurring themes)
 * - Recency
 *
 * See: docs/plans/DISCOVERY_RELEVANCE_SYSTEM.md
 */

import { Discovery } from './calculator';
import { FramedDimension } from './framing';
import { query } from '../db/pool';

// =============================================================================
// Types
// =============================================================================

export type StakesLevel = 'high' | 'medium' | 'light';

export interface AppreciationState {
  userAppreciated: boolean;
  partnerAppreciated: boolean;
}

export interface RankedDiscovery {
  discovery: Discovery;
  relevanceScore: number;
  stakesLevel: StakesLevel;
  appreciation: AppreciationState;
  createdAt: Date | null;
}

export interface DiscoveryAppreciationsMap {
  // Map of discoveryId -> { user1Appreciated: boolean, user2Appreciated: boolean }
  [discoveryId: string]: {
    user1Appreciated: boolean;
    user2Appreciated: boolean;
  };
}

// =============================================================================
// Stakes Categories
// =============================================================================

const HIGH_STAKES_CATEGORIES = new Set([
  'finances', 'financial_philosophy', 'financial',
  'family_planning', 'children', 'family',
  'intimacy', 'physical_affection', 'physical',
  'career', 'career_priorities', 'career_ambition',
  'living_location', 'relocation', 'location',
  'in_laws', 'extended_family',
  'religion', 'spirituality', 'faith',
  'life_goals', 'future_direction', 'future',
]);

const MEDIUM_STAKES_CATEGORIES = new Set([
  'communication', 'conflict', 'conflict_approach',
  'daily_routines', 'household', 'routines',
  'social', 'friendships', 'social_connection',
  'work_life_balance', 'stress', 'stress_processing',
  'emotional_support', 'trust', 'trust_openness',
  'support', 'appreciation',
]);

const LIGHT_STAKES_CATEGORIES = new Set([
  'food', 'dining', 'eating',
  'hobbies', 'leisure', 'recreation',
  'entertainment', 'media', 'movies',
  'travel', 'vacations', 'adventure',
  'aesthetics', 'preferences', 'style',
]);

// =============================================================================
// Scoring Constants
// =============================================================================

const STAKES_POINTS = {
  high: 50,
  medium: 25,
  light: 10,
} as const;

const APPRECIATION_POINTS = {
  neitherAppreciated: 0,
  iAppreciated: -15,      // I've engaged, show me other things
  partnerAppreciated: 30, // Partner found this meaningful, I should see it
  bothAppreciated: 0,     // Mutual signal complete, neutral priority
} as const;

const PATTERN_POINTS = {
  dimensionGap: 25,    // Links to dimension with difference > 0.5
  categoryCluster: 15, // 3+ discoveries in same category
} as const;

const RECENCY_POINTS = {
  fresh: 15,     // 0-3 days
  recent: 10,    // 4-7 days
  moderate: 5,   // 8-14 days
  older: 0,      // 15+ days
} as const;

// =============================================================================
// Database Functions
// =============================================================================

/**
 * Fetch all appreciations for a couple.
 */
export async function getDiscoveryAppreciations(
  coupleId: string,
  user1Id: string,
  user2Id: string
): Promise<DiscoveryAppreciationsMap> {
  const result = await query(
    `SELECT discovery_id, user_id
     FROM discovery_appreciations
     WHERE couple_id = $1`,
    [coupleId]
  );

  const map: DiscoveryAppreciationsMap = {};

  for (const row of result.rows) {
    if (!map[row.discovery_id]) {
      map[row.discovery_id] = { user1Appreciated: false, user2Appreciated: false };
    }
    if (row.user_id === user1Id) {
      map[row.discovery_id].user1Appreciated = true;
    } else if (row.user_id === user2Id) {
      map[row.discovery_id].user2Appreciated = true;
    }
  }

  return map;
}

/**
 * Toggle appreciation for a discovery.
 * Returns the new appreciated state.
 */
export async function toggleAppreciation(
  coupleId: string,
  discoveryId: string,
  userId: string
): Promise<boolean> {
  // Check if already appreciated
  const existing = await query(
    `SELECT id FROM discovery_appreciations
     WHERE couple_id = $1 AND discovery_id = $2 AND user_id = $3`,
    [coupleId, discoveryId, userId]
  );

  if (existing.rows.length > 0) {
    // Remove appreciation
    await query(
      `DELETE FROM discovery_appreciations
       WHERE couple_id = $1 AND discovery_id = $2 AND user_id = $3`,
      [coupleId, discoveryId, userId]
    );
    return false;
  } else {
    // Add appreciation
    await query(
      `INSERT INTO discovery_appreciations (couple_id, discovery_id, user_id)
       VALUES ($1, $2, $3)`,
      [coupleId, discoveryId, userId]
    );
    return true;
  }
}

// =============================================================================
// Scoring Functions
// =============================================================================

/**
 * Get stakes level for a discovery based on category.
 */
export function getStakesLevel(category: string | undefined, explicitLevel?: StakesLevel): StakesLevel {
  // Explicit level takes precedence
  if (explicitLevel) return explicitLevel;

  if (!category) return 'light';

  const normalizedCategory = category.toLowerCase().replace(/[^a-z_]/g, '');

  if (HIGH_STAKES_CATEGORIES.has(normalizedCategory)) return 'high';
  if (MEDIUM_STAKES_CATEGORIES.has(normalizedCategory)) return 'medium';
  if (LIGHT_STAKES_CATEGORIES.has(normalizedCategory)) return 'light';

  // Check for partial matches
  for (const cat of HIGH_STAKES_CATEGORIES) {
    if (normalizedCategory.includes(cat) || cat.includes(normalizedCategory)) return 'high';
  }
  for (const cat of MEDIUM_STAKES_CATEGORIES) {
    if (normalizedCategory.includes(cat) || cat.includes(normalizedCategory)) return 'medium';
  }

  return 'light';
}

/**
 * Calculate stakes points.
 */
function getStakesPoints(stakesLevel: StakesLevel): number {
  return STAKES_POINTS[stakesLevel];
}

/**
 * Calculate appreciation points for a user.
 */
function getAppreciationPoints(
  appreciation: { user1Appreciated: boolean; user2Appreciated: boolean } | undefined,
  isUser1: boolean
): number {
  if (!appreciation) return APPRECIATION_POINTS.neitherAppreciated;

  const iAppreciated = isUser1 ? appreciation.user1Appreciated : appreciation.user2Appreciated;
  const partnerAppreciated = isUser1 ? appreciation.user2Appreciated : appreciation.user1Appreciated;

  if (iAppreciated && partnerAppreciated) return APPRECIATION_POINTS.bothAppreciated;
  if (iAppreciated) return APPRECIATION_POINTS.iAppreciated;
  if (partnerAppreciated) return APPRECIATION_POINTS.partnerAppreciated;
  return APPRECIATION_POINTS.neitherAppreciated;
}

/**
 * Calculate pattern points based on dimension differences and category clustering.
 */
function getPatternPoints(
  discovery: Discovery,
  dimensions: FramedDimension[],
  categoryCount: Map<string, number>
): number {
  let points = 0;

  // Check if category links to a dimension with significant difference
  const category = discovery.category?.toLowerCase() ?? '';
  for (const dim of dimensions) {
    const diff = Math.abs(dim.user1Position - dim.user2Position);
    if (diff > 0.5) {
      // Check if discovery category relates to this dimension
      const dimId = dim.id.toLowerCase();
      if (category.includes(dimId) || dimId.includes(category)) {
        points += PATTERN_POINTS.dimensionGap;
        break;
      }
    }
  }

  // Check for category clustering (3+ discoveries in same category)
  const count = categoryCount.get(category) ?? 0;
  if (count >= 3) {
    points += PATTERN_POINTS.categoryCluster;
  }

  return points;
}

/**
 * Calculate recency points.
 */
function getRecencyPoints(createdAt: Date | null): number {
  if (!createdAt) return RECENCY_POINTS.older;

  const now = new Date();
  const daysDiff = Math.floor((now.getTime() - createdAt.getTime()) / (1000 * 60 * 60 * 24));

  if (daysDiff <= 3) return RECENCY_POINTS.fresh;
  if (daysDiff <= 7) return RECENCY_POINTS.recent;
  if (daysDiff <= 14) return RECENCY_POINTS.moderate;
  return RECENCY_POINTS.older;
}

/**
 * Generate a unique discovery ID.
 */
export function getDiscoveryId(discovery: Discovery): string {
  return `${discovery.quizId}_${discovery.questionId}`;
}

// =============================================================================
// Main Ranking Function
// =============================================================================

/**
 * Rank discoveries by relevance score.
 *
 * @param discoveries - Raw discoveries from profile
 * @param dimensions - Framed dimensions for pattern detection
 * @param appreciationsMap - Map of discovery ID to appreciation state
 * @param userId - Current user's ID
 * @param user1Id - User1's ID (to determine if current user is user1)
 * @param createdAtMap - Optional map of discovery ID to creation date
 */
export function rankDiscoveries(
  discoveries: Discovery[],
  dimensions: FramedDimension[],
  appreciationsMap: DiscoveryAppreciationsMap,
  userId: string,
  user1Id: string,
  createdAtMap?: Map<string, Date>
): RankedDiscovery[] {
  const isUser1 = userId === user1Id;

  // Build category count for clustering detection
  const categoryCount = new Map<string, number>();
  for (const d of discoveries) {
    const cat = d.category?.toLowerCase() ?? 'unknown';
    categoryCount.set(cat, (categoryCount.get(cat) ?? 0) + 1);
  }

  // Score each discovery
  const ranked: RankedDiscovery[] = discoveries.map(discovery => {
    const discoveryId = getDiscoveryId(discovery);
    const stakesLevel = getStakesLevel(discovery.category);
    const appreciation = appreciationsMap[discoveryId];
    const createdAt = createdAtMap?.get(discoveryId) ?? null;

    const stakesPoints = getStakesPoints(stakesLevel);
    const appreciationPoints = getAppreciationPoints(appreciation, isUser1);
    const patternPoints = getPatternPoints(discovery, dimensions, categoryCount);
    const recencyPoints = getRecencyPoints(createdAt);

    const relevanceScore = stakesPoints + appreciationPoints + patternPoints + recencyPoints;

    return {
      discovery,
      relevanceScore,
      stakesLevel,
      appreciation: {
        userAppreciated: isUser1
          ? (appreciation?.user1Appreciated ?? false)
          : (appreciation?.user2Appreciated ?? false),
        partnerAppreciated: isUser1
          ? (appreciation?.user2Appreciated ?? false)
          : (appreciation?.user1Appreciated ?? false),
      },
      createdAt,
    };
  });

  // Sort by relevance score (highest first)
  ranked.sort((a, b) => b.relevanceScore - a.relevanceScore);

  return ranked;
}

/**
 * Select featured discovery and others with category diversity.
 */
export function selectFeaturedAndOthers(
  rankedDiscoveries: RankedDiscovery[],
  othersCount: number = 4
): { featured: RankedDiscovery | null; others: RankedDiscovery[] } {
  if (rankedDiscoveries.length === 0) {
    return { featured: null, others: [] };
  }

  // Featured is highest scored
  const featured = rankedDiscoveries[0];

  // For others, prefer category diversity
  const others: RankedDiscovery[] = [];
  const usedCategories = new Set<string>();
  usedCategories.add(featured.discovery.category?.toLowerCase() ?? 'unknown');

  // First pass: different categories
  for (const rd of rankedDiscoveries.slice(1)) {
    if (others.length >= othersCount) break;

    const cat = rd.discovery.category?.toLowerCase() ?? 'unknown';
    if (!usedCategories.has(cat)) {
      others.push(rd);
      usedCategories.add(cat);
    }
  }

  // Second pass: fill remaining slots with highest scored
  for (const rd of rankedDiscoveries.slice(1)) {
    if (others.length >= othersCount) break;
    if (!others.includes(rd)) {
      others.push(rd);
    }
  }

  return { featured, others };
}

// =============================================================================
// Contextual Headers
// =============================================================================

export type ContextualHeader =
  | 'partner_appreciated'
  | 'worth_discussing'
  | 'pick_up_where_left_off'
  | 'in_sync'
  | 'first_insights';

/**
 * Get contextual header based on state.
 */
export function getContextualHeader(
  featured: RankedDiscovery | null,
  totalDiscoveries: number,
  daysSinceLastActivity: number,
  partnerName: string
): { type: ContextualHeader; label: string } {
  // Very few discoveries
  if (totalDiscoveries <= 3) {
    return { type: 'first_insights', label: 'Your First Insights' };
  }

  // Returning after 2+ weeks
  if (daysSinceLastActivity >= 14) {
    return { type: 'pick_up_where_left_off', label: 'Pick Up Where You Left Off' };
  }

  // Partner appreciated a high-stakes discovery
  if (featured?.appreciation.partnerAppreciated && featured.stakesLevel === 'high') {
    return {
      type: 'partner_appreciated',
      label: `${partnerName} Appreciates This Insight`,
    };
  }

  // Default
  return { type: 'worth_discussing', label: 'Worth Discussing' };
}
