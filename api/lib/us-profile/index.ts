/**
 * Us Profile Module
 *
 * Public API for Us Profile feature.
 */

// Calculator - raw profile data
export {
  calculateUsProfile,
  DIMENSIONS,
  LOVE_LANGUAGES,
  CONNECTION_TENDENCIES,
  VALUE_CATEGORIES,
  type UsProfileResult,
  type DimensionScore,
  type LoveLanguageScore,
  type ConnectionTendencyScore,
  type Discovery,
  type PartnerPerceptionTrait,
  type UserInsights,
  type CoupleInsights,
} from './calculator';

// Framing - human-readable insights
export {
  frameProfile,
  REVEAL_THRESHOLDS,
  type FramedProfile,
  type FramedDimension,
  type FramedLoveLanguage,
  type FramedDiscovery,
  type FramedPerception,
  type ConversationStarter,
  type DiscoverySection,
  type DiscoveryAppreciation,
  type RelevanceContext,
  type StakesLevel,
} from './framing';

// Relevance - discovery ranking and appreciations
export {
  rankDiscoveries,
  selectFeaturedAndOthers,
  getStakesLevel,
  getDiscoveryId,
  getContextualHeader,
  getDiscoveryAppreciations,
  toggleAppreciation,
  type RankedDiscovery,
  type DiscoveryAppreciationsMap,
  type AppreciationState,
  type ContextualHeader,
} from './relevance';

// Cache - storage management
export {
  getCachedProfile,
  updateCache,
  recalculateAndCacheProfile,
  getFramedProfile,
  getActiveConversationStarters,
  dismissConversationStarter,
  markStarterDiscussed,
  getDimensionUnlocks,
  type CachedProfile,
} from './cache';
