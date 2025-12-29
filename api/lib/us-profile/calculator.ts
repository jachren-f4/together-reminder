/**
 * Us Profile Calculator
 *
 * Processes quiz answers to generate profile insights for both users.
 * Called on every quiz completion to recalculate full profile.
 *
 * Data Sources:
 * - quiz_matches table: All completed quizzes with player answers
 * - Quiz JSON files: Question metadata with dimension/language/value tags
 */

import { query } from '@/lib/db/pool';
import { loadQuizContent, QuizType, QuizQuestion } from '@/lib/quiz/loader';

// =============================================================================
// Types
// =============================================================================

// Dimension poles (e.g., stress_processing: internal vs external)
export type DimensionPole = 'left' | 'right';

// Dimension definitions
export interface Dimension {
  id: string;
  label: string;
  leftLabel: string;
  rightLabel: string;
  leftDescription: string;
  rightDescription: string;
}

// User dimension score (aggregate across all quizzes)
export interface DimensionScore {
  dimensionId: string;
  leftCount: number;
  rightCount: number;
  totalAnswers: number;
  position: number; // -1 (full left) to 1 (full right), 0 = center
}

// Love language counts
export interface LoveLanguageScore {
  language: string;
  count: number;
}

// Connection tendency score (1-5 scale)
export interface ConnectionTendencyScore {
  tendency: string;
  totalScore: number;
  answerCount: number;
  averageScore: number;
}

// Value alignment tracking
export interface ValueCount {
  valueId: string;
  count: number;
}

// Discovery: Different answers between partners
export interface Discovery {
  quizId: string;
  quizType: string;
  questionId: string;
  questionText: string;
  user1Answer: string;
  user2Answer: string;
  category?: string;
}

// Partner perception trait (from You or Me)
export interface PartnerPerceptionTrait {
  trait: string;
  perceivedBy: 'user1' | 'user2';
  questionText: string;
}

// Full user insights
export interface UserInsights {
  dimensions: DimensionScore[];
  loveLanguages: LoveLanguageScore[];
  connectionTendencies: ConnectionTendencyScore[];
  partnerPerceptionTraits: PartnerPerceptionTrait[];
}

// Full couple insights
export interface CoupleInsights {
  valueAlignments: ValueCount[];
  discoveries: Discovery[];
  questionsExplored: number;
  totalDiscoveries: number;
}

// Complete profile result
export interface UsProfileResult {
  user1Insights: UserInsights;
  user2Insights: UserInsights;
  coupleInsights: CoupleInsights;
  totalQuizzesCompleted: number;
}

// =============================================================================
// Dimension Definitions
// =============================================================================

export const DIMENSIONS: Record<string, Dimension> = {
  stress_processing: {
    id: 'stress_processing',
    label: 'How You Process Stress',
    leftLabel: 'Internal Processor',
    rightLabel: 'External Processor',
    leftDescription: 'Needs space to think things through before talking',
    rightDescription: 'Works through challenges by talking them out',
  },
  social_energy: {
    id: 'social_energy',
    label: 'Social Energy',
    leftLabel: 'Recharge Alone',
    rightLabel: 'Energized by People',
    leftDescription: 'Finds energy in quiet, alone time',
    rightDescription: 'Gets energized from social interactions',
  },
  planning_style: {
    id: 'planning_style',
    label: 'Planning Style',
    leftLabel: 'Spontaneous',
    rightLabel: 'Structured',
    leftDescription: 'Prefers flexibility and going with the flow',
    rightDescription: 'Likes having plans and knowing what to expect',
  },
  conflict_approach: {
    id: 'conflict_approach',
    label: 'Conflict Approach',
    leftLabel: 'Space First',
    rightLabel: 'Talk It Out',
    leftDescription: 'Needs time alone to process before discussing',
    rightDescription: 'Prefers to address issues right away',
  },
};

// Love language display names
export const LOVE_LANGUAGES: Record<string, string> = {
  words_of_affirmation: 'Words of Affirmation',
  acts_of_service: 'Acts of Service',
  receiving_gifts: 'Receiving Gifts',
  quality_time: 'Quality Time',
  physical_touch: 'Physical Touch',
};

// Connection tendencies
export const CONNECTION_TENDENCIES: Record<string, string> = {
  reassurance_needs: 'Reassurance Needs',
  closeness_comfort: 'Closeness Comfort',
  independence_preference: 'Independence',
};

// Value categories
export const VALUE_CATEGORIES: Record<string, string> = {
  work_life_balance: 'Work-Life Balance',
  honesty_trust: 'Honesty & Trust',
  adventure_growth: 'Adventure & Growth',
  family_traditions: 'Family & Traditions',
  financial_security: 'Financial Security',
  quality_time: 'Quality Time',
  physical_affection: 'Physical Affection',
  communication: 'Communication',
  independence: 'Independence',
  shared_goals: 'Shared Goals',
};

// =============================================================================
// Main Calculator
// =============================================================================

/**
 * Calculate complete Us Profile for a couple.
 *
 * Loads all completed quizzes, processes each answer against question metadata,
 * and aggregates into dimension scores, love languages, values, and discoveries.
 */
export async function calculateUsProfile(coupleId: string): Promise<UsProfileResult> {
  // Load all completed quiz matches for this couple
  const matchResult = await query(
    `SELECT id, quiz_id, quiz_type, branch, player1_answers, player2_answers,
            player1_id, player2_id, completed_at
     FROM quiz_matches
     WHERE couple_id = $1 AND status = 'completed'
     ORDER BY completed_at ASC`,
    [coupleId]
  );

  const matches = matchResult.rows;
  const totalQuizzesCompleted = matches.length;

  // Initialize aggregators
  const user1: UserAggregator = createAggregator();
  const user2: UserAggregator = createAggregator();
  const coupleAgg: CoupleAggregator = {
    values: new Map(),
    discoveries: [],
    questionsExplored: 0,
  };

  // Process each completed quiz
  for (const match of matches) {
    const quizType = match.quiz_type as QuizType;
    const quizId = match.quiz_id;
    const branch = match.branch;

    // Load quiz content with metadata
    const quiz = loadQuizContent(quizType, quizId, branch);
    if (!quiz) {
      console.warn(`Could not load quiz ${quizType}/${branch}/${quizId}`);
      continue;
    }

    const player1Answers: number[] = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers: number[] = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    // Process each question
    for (let i = 0; i < quiz.questions.length; i++) {
      const question = quiz.questions[i] as QuestionWithMetadata;
      const user1Answer = player1Answers[i];
      const user2Answer = player2Answers[i];

      // Skip if either didn't answer
      if (user1Answer === undefined || user2Answer === undefined) continue;

      coupleAgg.questionsExplored++;

      // Process dimension metadata
      if (question.metadata?.dimension) {
        const dim = question.metadata.dimension;
        const poleMapping = question.metadata.poleMapping || [];

        const user1Pole = poleMapping[user1Answer] as DimensionPole | null;
        const user2Pole = poleMapping[user2Answer] as DimensionPole | null;

        if (user1Pole) addDimensionVote(user1.dimensions, dim, user1Pole);
        if (user2Pole) addDimensionVote(user2.dimensions, dim, user2Pole);
      }

      // Process love language metadata
      if (question.metadata?.loveLanguage && question.metadata?.languageMapping) {
        const langMapping = question.metadata.languageMapping;
        const user1Lang = langMapping[user1Answer];
        const user2Lang = langMapping[user2Answer];

        if (user1Lang) incrementCount(user1.loveLanguages, user1Lang);
        if (user2Lang) incrementCount(user2.loveLanguages, user2Lang);
      }

      // Process connection tendency metadata
      if (question.metadata?.connectionTendency && question.metadata?.scoreMapping) {
        const tendency = question.metadata.connectionTendency;
        const scoreMapping = question.metadata.scoreMapping;

        addTendencyScore(user1.connectionTendencies, tendency, scoreMapping[user1Answer]);
        addTendencyScore(user2.connectionTendencies, tendency, scoreMapping[user2Answer]);
      }

      // Process value category metadata
      if (question.metadata?.valueCategory) {
        const value = question.metadata.valueCategory;
        // If both answered the same, it's aligned value
        if (user1Answer === user2Answer) {
          incrementMapCount(coupleAgg.values, value);
        }
      }

      // Process partner perception traits (You or Me)
      if (question.metadata?.traitLabel) {
        // In You or Me: 0 = partner, 1 = self
        // If user1 picked 0 (partner), they perceive user2 has this trait
        // If user2 picked 0 (partner), they perceive user1 has this trait
        const trait = question.metadata.traitLabel;
        const questionText = getQuestionText(question, quizType);

        if (user1Answer === 0) {
          // User1 said "You" (partner) for this trait
          user2.partnerPerceptionTraits.push({
            trait,
            perceivedBy: 'user1',
            questionText,
          });
        }
        if (user2Answer === 0) {
          // User2 said "You" (partner) for this trait
          user1.partnerPerceptionTraits.push({
            trait,
            perceivedBy: 'user2',
            questionText,
          });
        }
      }

      // Detect discoveries (different answers)
      if (user1Answer !== user2Answer) {
        const discovery: Discovery = {
          quizId,
          quizType,
          questionId: question.id,
          questionText: getQuestionText(question, quizType),
          user1Answer: getAnswerText(question, user1Answer, quizType),
          user2Answer: getAnswerText(question, user2Answer, quizType),
          category: question.category,
        };
        coupleAgg.discoveries.push(discovery);
      }
    }
  }

  // Build final result
  return {
    user1Insights: buildUserInsights(user1),
    user2Insights: buildUserInsights(user2),
    coupleInsights: {
      valueAlignments: mapToValueCounts(coupleAgg.values),
      discoveries: coupleAgg.discoveries,
      questionsExplored: coupleAgg.questionsExplored,
      totalDiscoveries: coupleAgg.discoveries.length,
    },
    totalQuizzesCompleted,
  };
}

// =============================================================================
// Internal Types and Helpers
// =============================================================================

interface QuestionWithMetadata extends QuizQuestion {
  metadata?: {
    dimension?: string;
    poleMapping?: (DimensionPole | null)[];
    loveLanguage?: boolean;
    languageMapping?: (string | null)[];
    connectionTendency?: string;
    scoreMapping?: number[];
    valueCategory?: string;
    traitLabel?: string;
  };
}

interface UserAggregator {
  dimensions: Map<string, { left: number; right: number }>;
  loveLanguages: Map<string, number>;
  connectionTendencies: Map<string, { total: number; count: number }>;
  partnerPerceptionTraits: PartnerPerceptionTrait[];
}

interface CoupleAggregator {
  values: Map<string, number>;
  discoveries: Discovery[];
  questionsExplored: number;
}

function createAggregator(): UserAggregator {
  return {
    dimensions: new Map(),
    loveLanguages: new Map(),
    connectionTendencies: new Map(),
    partnerPerceptionTraits: [],
  };
}

function addDimensionVote(
  dims: Map<string, { left: number; right: number }>,
  dimensionId: string,
  pole: DimensionPole
): void {
  if (!dims.has(dimensionId)) {
    dims.set(dimensionId, { left: 0, right: 0 });
  }
  const current = dims.get(dimensionId)!;
  if (pole === 'left') current.left++;
  else if (pole === 'right') current.right++;
}

function addTendencyScore(
  tendencies: Map<string, { total: number; count: number }>,
  tendency: string,
  score: number | undefined
): void {
  if (score === undefined) return;
  if (!tendencies.has(tendency)) {
    tendencies.set(tendency, { total: 0, count: 0 });
  }
  const current = tendencies.get(tendency)!;
  current.total += score;
  current.count++;
}

function incrementCount(map: Map<string, number>, key: string): void {
  map.set(key, (map.get(key) || 0) + 1);
}

function incrementMapCount(map: Map<string, number>, key: string): void {
  map.set(key, (map.get(key) || 0) + 1);
}

function mapToValueCounts(map: Map<string, number>): ValueCount[] {
  return Array.from(map.entries())
    .map(([valueId, count]) => ({ valueId, count }))
    .sort((a, b) => b.count - a.count);
}

function buildUserInsights(agg: UserAggregator): UserInsights {
  // Build dimension scores
  const dimensions: DimensionScore[] = [];
  for (const [dimId, counts] of agg.dimensions.entries()) {
    const total = counts.left + counts.right;
    if (total === 0) continue;

    // Position: -1 (all left) to 1 (all right)
    const position = (counts.right - counts.left) / total;

    dimensions.push({
      dimensionId: dimId,
      leftCount: counts.left,
      rightCount: counts.right,
      totalAnswers: total,
      position,
    });
  }

  // Build love language scores
  const loveLanguages: LoveLanguageScore[] = Array.from(agg.loveLanguages.entries())
    .map(([language, count]) => ({ language, count }))
    .sort((a, b) => b.count - a.count);

  // Build connection tendency scores
  const connectionTendencies: ConnectionTendencyScore[] = [];
  for (const [tendency, data] of agg.connectionTendencies.entries()) {
    if (data.count === 0) continue;
    connectionTendencies.push({
      tendency,
      totalScore: data.total,
      answerCount: data.count,
      averageScore: data.total / data.count,
    });
  }

  return {
    dimensions,
    loveLanguages,
    connectionTendencies,
    partnerPerceptionTraits: agg.partnerPerceptionTraits,
  };
}

function getQuestionText(question: QuestionWithMetadata, quizType: QuizType): string {
  if (quizType === 'you_or_me') {
    const prompt = question.prompt || 'Who is more';
    const content = question.content || '';
    return `${prompt} ${content}`.trim();
  }
  return question.text || '';
}

function getAnswerText(
  question: QuestionWithMetadata,
  answerIndex: number,
  quizType: QuizType
): string {
  if (answerIndex < 0) return 'No answer';

  if (quizType === 'you_or_me') {
    return answerIndex === 0 ? 'Partner' : 'Self';
  }

  if (quizType === 'affirmation') {
    const labels = question.scaleLabels || [
      'Strongly Disagree',
      'Disagree',
      'Neutral',
      'Agree',
      'Strongly Agree',
    ];
    return labels[answerIndex] || `Option ${answerIndex + 1}`;
  }

  const choices = question.choices || [];
  return choices[answerIndex] || `Option ${answerIndex + 1}`;
}
