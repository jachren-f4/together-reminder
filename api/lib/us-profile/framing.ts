/**
 * Us Profile Framing
 *
 * Transforms raw profile data into human-readable insights and conversation starters.
 * Uses progressive reveal logic based on quiz completion count.
 */

import {
  UsProfileResult,
  DimensionScore,
  LoveLanguageScore,
  ConnectionTendencyScore,
  Discovery,
  PartnerPerceptionTrait,
  DIMENSIONS,
  LOVE_LANGUAGES,
  VALUE_CATEGORIES,
} from './calculator';

import {
  DiscoveryAppreciationsMap,
  rankDiscoveries,
  selectFeaturedAndOthers,
  getStakesLevel,
  getDiscoveryId,
  getContextualHeader,
  RankedDiscovery,
} from './relevance';

// =============================================================================
// Types
// =============================================================================

// Progressive reveal thresholds
export const REVEAL_THRESHOLDS = {
  FIRST_DISCOVERY: 1,        // After 1 quiz: first discovery + try this
  EARLY_DIMENSIONS: 3,       // After 3 quizzes: 1-2 dimension early readings
  MOST_DIMENSIONS: 7,        // After 7 quizzes: most dimensions unlocked
  FULL_PROFILE: 10,          // After 10+ quizzes: full profile
  MIN_DATA_POINTS: 2,        // Minimum answers for a dimension to show
} as const;

// Context for relevance-aware framing
export interface RelevanceContext {
  userId: string;
  user1Id: string;
  user2Id: string;
  user1Name: string;
  user2Name: string;
  appreciationsMap: DiscoveryAppreciationsMap;
  daysSinceLastActivity?: number;
  dimensionUnlocks?: Record<string, string>;  // Tracks when each dimension was first unlocked
}

// Framed dimension insight
export interface FramedDimension {
  id: string;
  label: string;
  user1Position: number;
  user2Position: number;
  user1Label: string;
  user2Label: string;
  user1Description: string;
  user2Description: string;
  similarity: 'same' | 'similar' | 'complementary' | 'different';
  conversationPrompt: string;
  isUnlocked: boolean;
  dataPoints: number;
  unlockedAt: string | null;  // ISO timestamp when dimension was first unlocked
}

// Framed love language insight
export interface FramedLoveLanguage {
  user1Primary: string | null;
  user1PrimaryLabel: string | null;
  user2Primary: string | null;
  user2PrimaryLabel: string | null;
  user1All: { language: string; label: string; count: number }[];
  user2All: { language: string; label: string; count: number }[];
  matchStatus: 'matching' | 'different';
  conversationPrompt: string;
  isUnlocked: boolean;
}

// Stakes level for discoveries
export type StakesLevel = 'high' | 'medium' | 'light';

// Appreciation state for discoveries
export interface DiscoveryAppreciation {
  userAppreciated: boolean;
  partnerAppreciated: boolean;
  partnerAppreciatedLabel: string | null;
  mutualAppreciation: boolean;
}

// Framed discovery
export interface FramedDiscovery {
  id: string;
  questionText: string;
  user1Answer: string;
  user2Answer: string;
  category: string | null;
  stakesLevel: StakesLevel;
  relevanceScore: number;
  conversationPrompt: string;
  tryThisAction: string | null;
  appreciation: DiscoveryAppreciation;
  // Conversation guide for high-stakes discoveries
  conversationGuide: {
    acknowledgment: string;
    steps: string[];
  } | null;
  timingBadge: { type: string; label: string } | null;
}

// Framed partner perception
export interface FramedPerception {
  userId: 'user1' | 'user2';
  traits: string[];
  frame: string;
}

// Conversation starter
export interface ConversationStarter {
  triggerType: 'dimension' | 'love_language' | 'value' | 'discovery';
  triggerData: Record<string, unknown>;
  promptText: string;
  contextText: string;
}

// Action stats for tracking engagement
export interface ActionStats {
  insightsActedOn: number;
  conversationsHad: number;
}

// Weekly focus insight
export interface WeeklyFocus {
  text: string;
  source: string;
}

// Value alignment
export interface ValueAlignment {
  id: string;
  name: string;
  status: 'aligned' | 'exploring' | 'important';
  alignment: number;  // 0-100
  insight: string;
  questions: number;
  isPriority: boolean;
}

// Upcoming insight for roadmap
export interface UpcomingInsight {
  id: string;
  title: string;
  unlockCondition: string;
  current: number;
  required: number;
}

// Discovery section with relevance ranking
export interface DiscoverySection {
  featured: FramedDiscovery | null;
  others: FramedDiscovery[];
  totalCount: number;
  contextLabel: string;
}

// Complete framed profile
export interface FramedProfile {
  dimensions: FramedDimension[];
  loveLanguages: FramedLoveLanguage | null;
  discoveries: DiscoverySection;
  partnerPerceptions: FramedPerception[];
  conversationStarters: ConversationStarter[];
  actionStats: ActionStats;
  weeklyFocus: WeeklyFocus | null;
  values: ValueAlignment[];
  upcomingInsights: UpcomingInsight[];
  stats: {
    totalQuizzes: number;
    questionsExplored: number;
    totalDiscoveries: number;
    unlockedDimensions: number;
    nextUnlockAt: number | null;
  };
  progressiveReveal: {
    level: 'new' | 'early' | 'growing' | 'established';
    showDimensions: boolean;
    showLoveLanguages: boolean;
    showFullProfile: boolean;
    nextMilestone: string | null;
  };
}

// =============================================================================
// Main Framing Function
// =============================================================================

/**
 * Frame raw profile data into human-readable insights.
 *
 * Applies progressive reveal logic based on quiz completion count.
 * When relevanceContext is provided, applies relevance scoring to discoveries.
 */
export function frameProfile(
  profile: UsProfileResult,
  relevanceContext?: RelevanceContext
): FramedProfile {
  const { user1Insights, user2Insights, coupleInsights, totalQuizzesCompleted } = profile;

  // Determine progressive reveal level
  const revealLevel = getRevealLevel(totalQuizzesCompleted);
  const showDimensions = totalQuizzesCompleted >= REVEAL_THRESHOLDS.EARLY_DIMENSIONS;
  const showLoveLanguages = totalQuizzesCompleted >= REVEAL_THRESHOLDS.EARLY_DIMENSIONS;
  const showFullProfile = totalQuizzesCompleted >= REVEAL_THRESHOLDS.FULL_PROFILE;

  // Frame dimensions
  const dimensions = frameDimensions(
    user1Insights.dimensions,
    user2Insights.dimensions,
    totalQuizzesCompleted,
    relevanceContext?.dimensionUnlocks || {}
  );

  // Frame love languages
  const loveLanguages = showLoveLanguages
    ? frameLoveLanguages(user1Insights.loveLanguages, user2Insights.loveLanguages)
    : null;

  // Frame discoveries with relevance scoring
  const discoverySection = frameDiscoveriesWithRelevance(
    coupleInsights.discoveries,
    dimensions,
    relevanceContext
  );

  // Frame partner perceptions
  const partnerPerceptions = framePerceptions(
    user1Insights.partnerPerceptionTraits,
    user2Insights.partnerPerceptionTraits
  );

  // Generate conversation starters
  const conversationStarters = generateConversationStarters(profile, revealLevel);

  // Calculate stats
  const unlockedDimensions = dimensions.filter(d => d.isUnlocked).length;
  const nextUnlockAt = getNextUnlockThreshold(totalQuizzesCompleted);

  // Get action stats from profile data (seeded or tracked)
  const actionStats = getActionStats(profile);

  // Generate weekly focus based on profile data
  const weeklyFocus = generateWeeklyFocus(profile);

  // Frame values
  const values = frameValues(coupleInsights.valueAlignments ?? []);

  // Generate upcoming insights roadmap
  const upcomingInsights = generateUpcomingInsights(profile);

  return {
    dimensions,
    loveLanguages,
    discoveries: discoverySection,
    partnerPerceptions,
    conversationStarters,
    actionStats,
    weeklyFocus,
    values,
    upcomingInsights,
    stats: {
      totalQuizzes: totalQuizzesCompleted,
      questionsExplored: coupleInsights.questionsExplored,
      totalDiscoveries: coupleInsights.totalDiscoveries,
      unlockedDimensions,
      nextUnlockAt,
    },
    progressiveReveal: {
      level: revealLevel,
      showDimensions,
      showLoveLanguages,
      showFullProfile,
      nextMilestone: getNextMilestoneMessage(totalQuizzesCompleted),
    },
  };
}

// =============================================================================
// Framing Helpers
// =============================================================================

function getRevealLevel(quizCount: number): 'new' | 'early' | 'growing' | 'established' {
  if (quizCount < REVEAL_THRESHOLDS.EARLY_DIMENSIONS) return 'new';
  if (quizCount < REVEAL_THRESHOLDS.MOST_DIMENSIONS) return 'early';
  if (quizCount < REVEAL_THRESHOLDS.FULL_PROFILE) return 'growing';
  return 'established';
}

function getNextUnlockThreshold(current: number): number | null {
  const thresholds = [
    REVEAL_THRESHOLDS.FIRST_DISCOVERY,
    REVEAL_THRESHOLDS.EARLY_DIMENSIONS,
    REVEAL_THRESHOLDS.MOST_DIMENSIONS,
    REVEAL_THRESHOLDS.FULL_PROFILE,
  ];

  for (const threshold of thresholds) {
    if (current < threshold) return threshold;
  }
  return null;
}

function getNextMilestoneMessage(current: number): string | null {
  if (current < REVEAL_THRESHOLDS.FIRST_DISCOVERY) {
    return 'Complete your first quiz to discover something new about each other!';
  }
  if (current < REVEAL_THRESHOLDS.EARLY_DIMENSIONS) {
    return `${REVEAL_THRESHOLDS.EARLY_DIMENSIONS - current} more quizzes to unlock dimension insights`;
  }
  if (current < REVEAL_THRESHOLDS.MOST_DIMENSIONS) {
    return `${REVEAL_THRESHOLDS.MOST_DIMENSIONS - current} more quizzes to reveal more dimensions`;
  }
  if (current < REVEAL_THRESHOLDS.FULL_PROFILE) {
    return `${REVEAL_THRESHOLDS.FULL_PROFILE - current} more quizzes to complete your full profile`;
  }
  return null;
}

function frameDimensions(
  user1Dims: DimensionScore[],
  user2Dims: DimensionScore[],
  quizCount: number,
  dimensionUnlocks: Record<string, string> = {}
): FramedDimension[] {
  const result: FramedDimension[] = [];

  // Get all dimension IDs from both users
  const allDimIds = new Set([
    ...user1Dims.map(d => d.dimensionId),
    ...user2Dims.map(d => d.dimensionId),
  ]);

  for (const dimId of allDimIds) {
    const dimDef = DIMENSIONS[dimId];
    if (!dimDef) continue;

    const user1Score = user1Dims.find(d => d.dimensionId === dimId);
    const user2Score = user2Dims.find(d => d.dimensionId === dimId);

    const user1Position = user1Score?.position ?? 0;
    const user2Position = user2Score?.position ?? 0;
    const dataPoints = (user1Score?.totalAnswers ?? 0) + (user2Score?.totalAnswers ?? 0);

    // Determine if this dimension should be shown
    const isUnlocked = quizCount >= REVEAL_THRESHOLDS.EARLY_DIMENSIONS &&
                       dataPoints >= REVEAL_THRESHOLDS.MIN_DATA_POINTS;

    // Calculate similarity
    const diff = Math.abs(user1Position - user2Position);
    const similarity: 'same' | 'similar' | 'complementary' | 'different' =
      diff < 0.2 ? 'same' :
      diff < 0.5 ? 'similar' :
      diff < 0.8 ? 'complementary' : 'different';

    // Get labels based on position
    const user1Label = getPositionLabel(user1Position, dimDef);
    const user2Label = getPositionLabel(user2Position, dimDef);

    result.push({
      id: dimId,
      label: dimDef.label,
      user1Position,
      user2Position,
      user1Label,
      user2Label,
      user1Description: user1Position < 0 ? dimDef.leftDescription : dimDef.rightDescription,
      user2Description: user2Position < 0 ? dimDef.leftDescription : dimDef.rightDescription,
      similarity,
      conversationPrompt: getDimensionPrompt(dimDef, similarity),
      isUnlocked,
      dataPoints,
      unlockedAt: dimensionUnlocks[dimId] || null,
    });
  }

  // Sort by data points (most data first)
  return result.sort((a, b) => b.dataPoints - a.dataPoints);
}

function getPositionLabel(position: number, dim: { leftLabel: string; rightLabel: string }): string {
  if (position < -0.3) return dim.leftLabel;
  if (position > 0.3) return dim.rightLabel;
  return 'Balanced';
}

function getDimensionPrompt(dim: { label: string; leftLabel: string; rightLabel: string }, similarity: string): string {
  switch (similarity) {
    case 'same':
      return `You both approach ${dim.label.toLowerCase()} in a similar way. Talk about what this means for your daily life.`;
    case 'similar':
      return `You have similar styles for ${dim.label.toLowerCase()}. Where do you notice the small differences?`;
    case 'complementary':
      return `Your different approaches to ${dim.label.toLowerCase()} can balance each other. How can you support each other's needs?`;
    case 'different':
      return `You have different styles for ${dim.label.toLowerCase()}. Discuss what works best when you need to compromise.`;
    default:
      return `Discuss how you each approach ${dim.label.toLowerCase()}.`;
  }
}

function frameLoveLanguages(
  user1Langs: LoveLanguageScore[],
  user2Langs: LoveLanguageScore[]
): FramedLoveLanguage {
  const user1Primary = user1Langs[0]?.language ?? null;
  const user2Primary = user2Langs[0]?.language ?? null;

  const matchStatus = user1Primary === user2Primary ? 'matching' : 'different';

  const conversationPrompt = matchStatus === 'matching'
    ? `You both value ${LOVE_LANGUAGES[user1Primary!] ?? 'the same things'}! Talk about specific ways you can show love in this way.`
    : `Your love languages are different. Discuss how you can speak each other's language.`;

  return {
    user1Primary,
    user1PrimaryLabel: user1Primary ? LOVE_LANGUAGES[user1Primary] : null,
    user2Primary,
    user2PrimaryLabel: user2Primary ? LOVE_LANGUAGES[user2Primary] : null,
    user1All: user1Langs.map(l => ({
      language: l.language,
      label: LOVE_LANGUAGES[l.language] ?? l.language,
      count: l.count,
    })),
    user2All: user2Langs.map(l => ({
      language: l.language,
      label: LOVE_LANGUAGES[l.language] ?? l.language,
      count: l.count,
    })),
    matchStatus,
    conversationPrompt,
    isUnlocked: user1Langs.length > 0 || user2Langs.length > 0,
  };
}

/**
 * Frame discoveries with relevance scoring.
 * Returns a DiscoverySection with featured + others.
 */
function frameDiscoveriesWithRelevance(
  discoveries: Discovery[],
  dimensions: FramedDimension[],
  relevanceContext?: RelevanceContext
): DiscoverySection {
  // If no relevance context, fall back to simple framing
  if (!relevanceContext) {
    const framedDiscoveries = discoveries.slice(-10).reverse().map((d, idx) =>
      frameDiscoverySimple(d, idx)
    );
    return {
      featured: framedDiscoveries[0] ?? null,
      others: framedDiscoveries.slice(1, 5),
      totalCount: discoveries.length,
      contextLabel: 'Worth Discussing',
    };
  }

  // Apply relevance scoring
  const ranked = rankDiscoveries(
    discoveries,
    dimensions,
    relevanceContext.appreciationsMap,
    relevanceContext.userId,
    relevanceContext.user1Id
  );

  // Select featured and others with category diversity
  const { featured, others } = selectFeaturedAndOthers(ranked, 4);

  // Frame the ranked discoveries
  const framedFeatured = featured
    ? frameRankedDiscovery(featured, relevanceContext)
    : null;

  const framedOthers = others.map(rd => frameRankedDiscovery(rd, relevanceContext));

  // Get contextual header
  const isUser1 = relevanceContext.userId === relevanceContext.user1Id;
  const partnerName = isUser1 ? relevanceContext.user2Name : relevanceContext.user1Name;
  const { label: contextLabel } = getContextualHeader(
    featured,
    discoveries.length,
    relevanceContext.daysSinceLastActivity ?? 0,
    partnerName
  );

  return {
    featured: framedFeatured,
    others: framedOthers,
    totalCount: discoveries.length,
    contextLabel,
  };
}

/**
 * Frame a simple discovery without relevance scoring (fallback).
 */
function frameDiscoverySimple(discovery: Discovery, idx: number): FramedDiscovery {
  const stakesLevel = getStakesLevel(discovery.category);
  return {
    id: getDiscoveryId(discovery),
    questionText: discovery.questionText,
    user1Answer: discovery.user1Answer,
    user2Answer: discovery.user2Answer,
    category: discovery.category ?? null,
    stakesLevel,
    relevanceScore: 0,
    conversationPrompt: generateDiscoveryPrompt(discovery),
    tryThisAction: generateTryThisAction(discovery),
    appreciation: {
      userAppreciated: false,
      partnerAppreciated: false,
      partnerAppreciatedLabel: null,
      mutualAppreciation: false,
    },
    conversationGuide: stakesLevel === 'high' ? generateConversationGuide(discovery) : null,
    timingBadge: getTimingBadge(stakesLevel),
  };
}

/**
 * Frame a ranked discovery with full relevance data.
 */
function frameRankedDiscovery(
  ranked: RankedDiscovery,
  context: RelevanceContext
): FramedDiscovery {
  const discovery = ranked.discovery;
  const isUser1 = context.userId === context.user1Id;
  const partnerName = isUser1 ? context.user2Name : context.user1Name;

  return {
    id: getDiscoveryId(discovery),
    questionText: discovery.questionText,
    user1Answer: discovery.user1Answer,
    user2Answer: discovery.user2Answer,
    category: discovery.category ?? null,
    stakesLevel: ranked.stakesLevel,
    relevanceScore: ranked.relevanceScore,
    conversationPrompt: generateDiscoveryPrompt(discovery),
    tryThisAction: generateTryThisAction(discovery),
    appreciation: {
      userAppreciated: ranked.appreciation.userAppreciated,
      partnerAppreciated: ranked.appreciation.partnerAppreciated,
      partnerAppreciatedLabel: ranked.appreciation.partnerAppreciated
        ? `${partnerName} appreciates this insight`
        : null,
      mutualAppreciation: ranked.appreciation.userAppreciated && ranked.appreciation.partnerAppreciated,
    },
    conversationGuide: ranked.stakesLevel === 'high' ? generateConversationGuide(discovery) : null,
    timingBadge: getTimingBadge(ranked.stakesLevel),
  };
}

/**
 * Generate conversation guide for high-stakes discoveries.
 */
function generateConversationGuide(discovery: Discovery): { acknowledgment: string; steps: string[] } {
  return {
    acknowledgment: "This is a significant topic. There's no quick answer, and that's okay.",
    steps: [
      'Find a relaxed time (not during stress)',
      'Start with curiosity: "I\'d love to understand your perspective"',
      'Share your feelings without pressure to decide',
      "It's okay to revisit this multiple times",
    ],
  };
}

/**
 * Get timing badge based on stakes level.
 */
function getTimingBadge(stakesLevel: StakesLevel): { type: string; label: string } {
  switch (stakesLevel) {
    case 'high':
      return { type: 'dedicated', label: 'Set aside 20-30 minutes' };
    case 'medium':
      return { type: 'relaxed', label: 'Best for a quiet evening' };
    case 'light':
      return { type: 'quick', label: 'Quick check-in' };
  }
}

function generateDiscoveryPrompt(discovery: Discovery): string {
  const category = discovery.category?.toLowerCase() ?? '';

  // Category-specific prompts that add insight beyond the answers
  const categoryPrompts: Record<string, string[]> = {
    // High-stakes categories
    finances: [
      "Different approaches to money can complement each other — or create tension. Worth exploring.",
      "Money habits often come from how we grew up. Understanding that context helps.",
      "Financial decisions work best when you understand each other's priorities.",
    ],
    family_planning: [
      "You're in different places on this. Understanding where each of you is coming from can help.",
      "There's no rush to align perfectly — but staying curious about each other's feelings matters.",
      "This is one of those topics that benefits from revisiting over time.",
    ],
    intimacy: [
      "Physical connection means different things to different people. This is worth exploring gently.",
      "Understanding each other's needs here can deepen your connection.",
      "These differences often reflect different ways of feeling close.",
    ],
    career: [
      "Balancing ambition and togetherness is an ongoing conversation for most couples.",
      "Career priorities shift over time. What matters is staying in sync.",
      "Understanding what drives each of you professionally helps you support each other.",
    ],
    living_location: [
      "Where you live shapes so much of daily life. This deserves unhurried conversation.",
      "Location preferences often tie to deeper values about lifestyle and family.",
    ],

    // Medium-stakes categories
    communication: [
      "Knowing how you each process conflict can prevent misunderstandings.",
      "Communication styles often differ — the key is learning each other's patterns.",
      "These differences can actually strengthen how you communicate, once understood.",
    ],
    conflict: [
      "How you handle disagreements shapes your relationship more than the disagreements themselves.",
      "Different conflict styles aren't right or wrong — they just need understanding.",
    ],
    emotional_support: [
      "People feel supported in different ways. This insight can help you show up for each other.",
      "Understanding what support looks like to your partner prevents missed connections.",
    ],
    stress: [
      "Stress responses are deeply personal. Knowing yours helps you help each other.",
      "When you understand how your partner processes stress, you can be there in the way they need.",
    ],

    // Light categories
    food: [
      "Food preferences can be fun to navigate together — lots of room for compromise here.",
      "Different tastes can lead to discovering new things together.",
    ],
    lifestyle: [
      "Day-to-day preferences shape your rhythm as a couple. Good to know where you land.",
      "These lifestyle differences are usually easy to work with once you're aware of them.",
    ],
    social: [
      "Social energy levels often differ. Finding your balance keeps both of you happy.",
      "Introverts and extroverts can thrive together with a little awareness.",
    ],
    entertainment: [
      "Different tastes in fun can actually expand what you do together.",
      "These preferences are easy to accommodate once you know them.",
    ],
    travel: [
      "Travel styles reveal a lot about how you like to spend time. Worth discussing before your next trip.",
      "Planning adventures is easier when you know what recharges each of you.",
    ],
  };

  // Simple hash of discovery ID for deterministic prompt selection
  const hash = (discovery.questionId ?? discovery.quizId ?? '').split('')
    .reduce((acc, char) => acc + char.charCodeAt(0), 0);

  // Find matching category prompts
  for (const [cat, prompts] of Object.entries(categoryPrompts)) {
    if (category.includes(cat) || cat.includes(category)) {
      // Pick a deterministic prompt based on discovery ID
      return prompts[hash % prompts.length];
    }
  }

  // Generic fallback prompts (still better than repeating the answers)
  const fallbackPrompts = [
    "Understanding where this difference comes from can bring you closer.",
    "Differences like this often reflect your unique backgrounds and experiences.",
    "These perspectives aren't right or wrong — they're just different. Worth exploring.",
    "Curiosity about each other's viewpoint goes a long way here.",
    "This kind of difference is common and totally workable with awareness.",
  ];

  return fallbackPrompts[hash % fallbackPrompts.length];
}

function generateTryThisAction(discovery: Discovery): string | null {
  // Generate an action suggestion based on the category
  const category = discovery.category?.toLowerCase() ?? '';

  if (category.includes('food') || category.includes('eat')) {
    return 'Try a new restaurant together this week';
  }
  if (category.includes('social') || category.includes('people')) {
    return 'Plan one social activity and one quiet night this week';
  }
  if (category.includes('stress') || category.includes('support')) {
    return 'Ask your partner how they want to be supported next time they feel stressed';
  }
  if (category.includes('leisure') || category.includes('weekend')) {
    return 'Let your partner plan your next day off together';
  }

  // Default action
  return 'Have a 10-minute conversation about this difference tonight';
}

function framePerceptions(
  user1Traits: PartnerPerceptionTrait[] | undefined,
  user2Traits: PartnerPerceptionTrait[] | undefined
): FramedPerception[] {
  const result: FramedPerception[] = [];

  // Handle missing traits gracefully
  if (!user1Traits && !user2Traits) {
    return result;
  }

  // Traits that user2 perceives about user1
  const user1Perceived = (user1Traits ?? [])
    .filter(t => t.perceivedBy === 'user2')
    .map(t => t.trait);

  // Traits that user1 perceives about user2
  const user2Perceived = (user2Traits ?? [])
    .filter(t => t.perceivedBy === 'user1')
    .map(t => t.trait);

  if (user1Perceived.length > 0) {
    result.push({
      userId: 'user1',
      traits: user1Perceived,
      frame: `Your partner sees you as: ${formatTraitList(user1Perceived)}`,
    });
  }

  if (user2Perceived.length > 0) {
    result.push({
      userId: 'user2',
      traits: user2Perceived,
      frame: `Your partner sees you as: ${formatTraitList(user2Perceived)}`,
    });
  }

  return result;
}

function formatTraitList(traits: string[]): string {
  if (traits.length === 0) return '';
  if (traits.length === 1) return `the ${traits[0]}`;
  if (traits.length === 2) return `the ${traits[0]} and ${traits[1]}`;
  const last = traits[traits.length - 1];
  const rest = traits.slice(0, -1);
  return `the ${rest.join(', ')}, and ${last}`;
}

// =============================================================================
// Conversation Starters
// =============================================================================

function generateConversationStarters(
  profile: UsProfileResult,
  level: 'new' | 'early' | 'growing' | 'established'
): ConversationStarter[] {
  const starters: ConversationStarter[] = [];

  // Always prioritize discoveries for "new" users
  if (level === 'new' && profile.coupleInsights.discoveries.length > 0) {
    const discovery = profile.coupleInsights.discoveries[0];
    starters.push({
      triggerType: 'discovery',
      triggerData: { questionText: discovery.questionText, user1Answer: discovery.user1Answer, user2Answer: discovery.user2Answer },
      promptText: 'You discovered something new!',
      contextText: `You answered differently about "${discovery.questionText}". What made you choose "${discovery.user1Answer}"?`,
    });
  }

  // Add dimension-based starters for more established profiles
  if (level !== 'new') {
    const framedDims = frameDimensions(
      profile.user1Insights.dimensions,
      profile.user2Insights.dimensions,
      profile.totalQuizzesCompleted
    );

    // Find complementary or different dimensions for starters
    const interestingDims = framedDims
      .filter(d => d.isUnlocked && (d.similarity === 'complementary' || d.similarity === 'different'))
      .slice(0, 2);

    for (const dim of interestingDims) {
      starters.push({
        triggerType: 'dimension',
        triggerData: { dimensionId: dim.id, user1Position: dim.user1Position, user2Position: dim.user2Position },
        promptText: `${dim.label}: You have different styles`,
        contextText: dim.conversationPrompt,
      });
    }
  }

  // Add love language starter if available
  if (profile.user1Insights.loveLanguages.length > 0 && profile.user2Insights.loveLanguages.length > 0) {
    const u1Primary = profile.user1Insights.loveLanguages[0].language;
    const u2Primary = profile.user2Insights.loveLanguages[0].language;

    if (u1Primary !== u2Primary) {
      starters.push({
        triggerType: 'love_language',
        triggerData: { user1Primary: u1Primary, user2Primary: u2Primary },
        promptText: 'Your love languages are different',
        contextText: `You value ${LOVE_LANGUAGES[u1Primary]} while your partner values ${LOVE_LANGUAGES[u2Primary]}. How can you show love in their language this week?`,
      });
    }
  }

  // Add value alignment starter if we have matching values
  if ((profile.coupleInsights.valueAlignments?.length ?? 0) > 0) {
    const topValue = profile.coupleInsights.valueAlignments[0];
    const valueLabel = VALUE_CATEGORIES[topValue.valueId] ?? topValue.valueId;
    starters.push({
      triggerType: 'value',
      triggerData: { valueId: topValue.valueId, count: topValue.count },
      promptText: `You both value: ${valueLabel}`,
      contextText: `You've shown ${topValue.count} times that ${valueLabel.toLowerCase()} is important to both of you. How does this show up in your daily life?`,
    });
  }

  return starters.slice(0, 3); // Return top 3 starters
}

// =============================================================================
// New Framing Functions for variant-9/10 mockups
// =============================================================================

/**
 * Get action stats from profile data or return defaults.
 * Action stats can be seeded in coupleInsights.actionStats for testing
 * or will be tracked via database in production.
 */
function getActionStats(profile: UsProfileResult): ActionStats {
  // Check if action stats were provided in couple insights (for testing/seeding)
  const coupleInsights = profile.coupleInsights as any;
  if (coupleInsights?.actionStats) {
    return {
      insightsActedOn: coupleInsights.actionStats.insightsActedOn ?? 0,
      conversationsHad: coupleInsights.actionStats.conversationsHad ?? 0,
    };
  }

  // Default for new profiles
  return {
    insightsActedOn: 0,
    conversationsHad: 0,
  };
}

/**
 * Generate weekly focus based on profile insights
 */
function generateWeeklyFocus(profile: UsProfileResult): WeeklyFocus | null {
  // Look for interesting differences to create actionable focus
  const discoveries = profile.coupleInsights.discoveries;
  const dimensions = [
    ...profile.user1Insights.dimensions,
    ...profile.user2Insights.dimensions,
  ];

  // Find complementary dimension for focus
  const dimWithDiff = dimensions.find(d => {
    const u1 = profile.user1Insights.dimensions.find(x => x.dimensionId === d.dimensionId);
    const u2 = profile.user2Insights.dimensions.find(x => x.dimensionId === d.dimensionId);
    if (!u1 || !u2) return false;
    return Math.abs(u1.position - u2.position) > 0.5;
  });

  if (dimWithDiff) {
    const dimDef = DIMENSIONS[dimWithDiff.dimensionId];
    if (dimDef) {
      const focusTexts: Record<string, string> = {
        stress_processing: 'When your partner seems stressed, try saying "I\'m here when you\'re ready" instead of asking what\'s wrong.',
        planning_style: 'Try asking "what would make tomorrow feel successful?" before bed tonight.',
        social_energy: 'Plan one social activity and one quiet night together this week.',
        conflict_style: 'When you disagree, try saying "I want to understand your perspective" first.',
        space_needs: 'Create intentional alone time for each other without guilt.',
        support_style: 'Ask your partner: "When you\'re having a hard day, do you want me to listen, help fix it, or distract you?"',
      };

      return {
        text: focusTexts[dimWithDiff.dimensionId] ?? `This week, explore how you each approach ${dimDef.label.toLowerCase()}.`,
        source: `Based on your ${dimDef.label.toLowerCase()} difference`,
      };
    }
  }

  // Fall back to discovery-based focus
  if (discoveries.length > 0) {
    const discovery = discoveries[0];
    return {
      text: generateTryThisAction(discovery) ?? 'Have a 10-minute conversation about your different perspectives tonight.',
      source: `From your recent discovery`,
    };
  }

  return null;
}

/**
 * Frame value alignments into displayable format
 */
function frameValues(valueAlignments: { valueId: string; count: number }[]): ValueAlignment[] {
  return valueAlignments.slice(0, 4).map((va, idx) => {
    const valueLabel = VALUE_CATEGORIES[va.valueId] ?? va.valueId;
    const alignment = Math.min(100, va.count * 20); // More questions = higher alignment

    // Determine status based on alignment
    let status: 'aligned' | 'exploring' | 'important';
    if (alignment >= 80) {
      status = 'aligned';
    } else if (alignment >= 40) {
      status = 'exploring';
    } else {
      status = 'important';
    }

    // Generate insight text
    const insights: Record<string, string> = {
      financial_philosophy: 'You share similar views on saving vs spending',
      family_priority: 'Family time is a shared priority',
      trust_openness: 'You value open communication',
      adventure: 'You both enjoy trying new experiences',
      career_ambition: 'Career growth matters to both of you',
      social_connection: 'Social relationships are important to you both',
      personal_growth: 'You both prioritize self-improvement',
    };

    return {
      id: va.valueId,
      name: valueLabel,
      status,
      alignment,
      insight: insights[va.valueId] ?? `Based on ${va.count} aligned answers`,
      questions: va.count,
      isPriority: idx === 0, // First value is priority
    };
  });
}

/**
 * Generate upcoming insights for the "What's Coming" roadmap
 */
function generateUpcomingInsights(profile: UsProfileResult): UpcomingInsight[] {
  const insights: UpcomingInsight[] = [];
  const quizCount = profile.totalQuizzesCompleted;
  const questionCount = profile.coupleInsights.questionsExplored;

  // Dimension insights
  if (quizCount < REVEAL_THRESHOLDS.EARLY_DIMENSIONS) {
    insights.push({
      id: 'dimensions',
      title: 'How You Navigate Together',
      unlockCondition: `After ${REVEAL_THRESHOLDS.EARLY_DIMENSIONS - quizCount} more quizzes`,
      current: quizCount,
      required: REVEAL_THRESHOLDS.EARLY_DIMENSIONS,
    });
  }

  // Check specific dimensions that need more data
  const dimDataPoints = new Map<string, number>();
  for (const d of profile.user1Insights.dimensions) {
    dimDataPoints.set(d.dimensionId, (dimDataPoints.get(d.dimensionId) ?? 0) + d.totalAnswers);
  }
  for (const d of profile.user2Insights.dimensions) {
    dimDataPoints.set(d.dimensionId, (dimDataPoints.get(d.dimensionId) ?? 0) + d.totalAnswers);
  }

  // Find dimensions that are close to unlocking
  for (const [dimId, points] of dimDataPoints) {
    if (points > 0 && points < REVEAL_THRESHOLDS.MIN_DATA_POINTS * 2) {
      const dimDef = DIMENSIONS[dimId];
      if (dimDef) {
        insights.push({
          id: dimId,
          title: dimDef.label,
          unlockCondition: `After ${REVEAL_THRESHOLDS.MIN_DATA_POINTS * 2 - points} more questions`,
          current: points,
          required: REVEAL_THRESHOLDS.MIN_DATA_POINTS * 2,
        });
      }
    }
  }

  // Love languages
  const llCount = profile.user1Insights.loveLanguages.reduce((sum, l) => sum + l.count, 0) +
                  profile.user2Insights.loveLanguages.reduce((sum, l) => sum + l.count, 0);
  if (llCount < 6) {
    insights.push({
      id: 'love_languages',
      title: 'Love Languages',
      unlockCondition: `After ${6 - llCount} more love language questions`,
      current: llCount,
      required: 6,
    });
  }

  return insights.slice(0, 4); // Return top 4
}
