/**
 * Quiz Loading Utilities
 *
 * Shared utilities for loading quiz content from the filesystem.
 * Used by Classic, Affirmation, and You or Me quiz types.
 */

import { readFileSync } from 'fs';
import { join } from 'path';

// =============================================================================
// Types
// =============================================================================

export type QuizType = 'classic' | 'affirmation' | 'you_or_me';

export interface QuizQuestion {
  id: string;
  text?: string;           // Classic/Affirmation question text
  prompt?: string;         // You or Me prompt (e.g., "Who is more")
  content?: string;        // You or Me content (e.g., "Likely to...")
  choices?: string[];      // Classic quiz choices
  scaleLabels?: string[];  // Affirmation scale labels
  category?: string;
}

export interface QuizContent {
  quizId: string;
  title: string;
  branch: string;
  description?: string;
  questions: QuizQuestion[];
}

// =============================================================================
// Configuration
// =============================================================================

const QUIZ_FOLDER_MAP: Record<QuizType, string> = {
  classic: 'classic-quiz',
  affirmation: 'affirmation',
  you_or_me: 'you-or-me',
};

/**
 * The text shown for the 5th "fallback" option in classic quizzes.
 * This option is always added to classic quiz questions client-side.
 * Must be kept in sync with Flutter's kClassicQuizFallbackOptionText.
 */
export const CLASSIC_QUIZ_FALLBACK_OPTION_TEXT = "It depends / Something else";
export const CLASSIC_QUIZ_FALLBACK_OPTION_INDEX = 4;

// =============================================================================
// Quiz Loading
// =============================================================================

/**
 * Load quiz content from the filesystem.
 *
 * @param quizType - Type of quiz ('classic', 'affirmation', 'you_or_me')
 * @param quizId - The quiz ID (e.g., 'quiz_001', 'affirmation_001')
 * @param branch - Branch folder name (e.g., 'lighthearted', 'connection')
 * @returns Parsed quiz content or null if not found
 *
 * @example
 * const quiz = loadQuizContent('classic', 'quiz_001', 'lighthearted');
 * const quiz = loadQuizContent('affirmation', 'affirmation_001', 'connection');
 * const quiz = loadQuizContent('you_or_me', 'quiz_001', 'playful');
 */
export function loadQuizContent(
  quizType: QuizType,
  quizId: string,
  branch: string
): QuizContent | null {
  try {
    const folder = QUIZ_FOLDER_MAP[quizType];
    if (!folder) {
      console.error(`Unknown quiz type: ${quizType}`);
      return null;
    }

    const quizPath = join(
      process.cwd(),
      'data',
      'puzzles',
      folder,
      branch,
      `${quizId}.json`
    );

    const quizData = readFileSync(quizPath, 'utf-8');
    return JSON.parse(quizData);
  } catch (error) {
    console.error(`Failed to load ${quizType} quiz ${quizId} from branch ${branch}:`, error);
    return null;
  }
}

/**
 * Get the question text for a quiz question.
 * Handles different question formats across quiz types.
 */
export function getQuestionText(question: QuizQuestion, quizType: QuizType): string {
  if (quizType === 'you_or_me') {
    // You or Me combines prompt + content
    const prompt = question.prompt || 'Who is more';
    const content = question.content || '';
    return `${prompt} ${content}`.trim();
  }
  return question.text || '';
}

/**
 * Get the answer text for a given answer index.
 * Handles different answer formats across quiz types.
 */
export function getAnswerText(
  question: QuizQuestion,
  answerIndex: number,
  quizType: QuizType,
  userName?: string,
  partnerName?: string
): string {
  if (answerIndex < 0) {
    return 'No answer';
  }

  if (quizType === 'you_or_me') {
    // You or Me answers are 0 = partner, 1 = self (relative encoding)
    // But for display, we need to show who they picked
    // Note: The answer is from the perspective of the answerer
    // 0 = "You" (meaning partner), 1 = "Me" (meaning self)
    return answerIndex === 0 ? (partnerName || 'Partner') : (userName || 'Me');
  }

  if (quizType === 'affirmation') {
    // Affirmation uses scaleLabels (1-5 scale)
    const labels = question.scaleLabels || [
      'Strongly Disagree',
      'Disagree',
      'Neutral',
      'Agree',
      'Strongly Agree',
    ];
    return labels[answerIndex] || `Option ${answerIndex + 1}`;
  }

  // Classic quiz uses choices array
  const choices = question.choices || [];
  if (answerIndex < choices.length) {
    return choices[answerIndex];
  }
  // Handle the hardcoded 5th fallback option
  if (answerIndex === CLASSIC_QUIZ_FALLBACK_OPTION_INDEX) {
    return CLASSIC_QUIZ_FALLBACK_OPTION_TEXT;
  }
  return `Option ${answerIndex + 1}`;
}
