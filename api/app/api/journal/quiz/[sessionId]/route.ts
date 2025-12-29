/**
 * Journal Quiz Details API Endpoint
 *
 * GET /api/journal/quiz/[matchId]
 *
 * Returns detailed question-by-question answers for a quiz match.
 * Used in the journal detail bottom sheet to show answer comparison.
 *
 * Note: Parameter is still named 'sessionId' for backwards compatibility,
 * but it now refers to a quiz_matches.id (not legacy quiz_sessions.id).
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';
import {
  loadQuizContent,
  getQuestionText,
  getAnswerText,
  QuizType,
} from '@/lib/quiz/loader';

export const dynamic = 'force-dynamic';

interface QuizAnswerDetail {
  questionIndex: number;
  questionText: string;
  userAnswerIndex: number;
  userAnswerText: string;
  partnerAnswerIndex: number;
  partnerAnswerText: string;
  isAligned: boolean;
}

interface QuizDetails {
  matchId: string;
  quizType: string;
  branch: string;
  quizId: string;
  quizTitle: string;
  completedAt: string;
  answers: QuizAnswerDetail[];
  alignedCount: number;
  differentCount: number;
  matchPercentage: number | null;
}

/**
 * GET /api/journal/quiz/[sessionId]
 *
 * Returns detailed answers for a specific quiz match
 * (sessionId param refers to quiz_matches.id)
 */
export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string, context?: any) => {
  try {
    const resolvedParams = context?.params ? (await context.params) : null;
    const matchId = resolvedParams?.sessionId; // Still named sessionId for URL compatibility

    if (!matchId) {
      return NextResponse.json(
        { error: 'Match ID required' },
        { status: 400 }
      );
    }

    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'Couple not found' },
        { status: 404 }
      );
    }

    const { coupleId, isPlayer1, user1Id, user2Id } = couple;

    // Get user names for You or Me answer display
    const usersResult = await query(
      `SELECT id, raw_user_meta_data->>'full_name' as name FROM auth.users WHERE id IN ($1, $2)`,
      [user1Id, user2Id]
    );
    const userMap = new Map(usersResult.rows.map(u => [u.id, u.name || 'User']));
    const userName = userMap.get(userId) || 'You';
    const partnerId = isPlayer1 ? user2Id : user1Id;
    const partnerName = userMap.get(partnerId) || 'Partner';

    // Get quiz match from quiz_matches table
    const matchResult = await query(
      `SELECT
        id, quiz_type, branch, quiz_id, status, completed_at,
        player1_answers, player2_answers, match_percentage,
        player1_id, player2_id
       FROM quiz_matches
       WHERE id = $1 AND couple_id = $2`,
      [matchId, coupleId]
    );

    if (matchResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found' },
        { status: 404 }
      );
    }

    const match = matchResult.rows[0];

    if (match.status !== 'completed') {
      return NextResponse.json(
        { error: 'Match not completed' },
        { status: 400 }
      );
    }

    // Load quiz content from file
    const quizType = match.quiz_type as QuizType;
    const quizContent = loadQuizContent(quizType, match.quiz_id, match.branch);

    if (!quizContent) {
      return NextResponse.json(
        { error: 'Quiz content not found' },
        { status: 404 }
      );
    }

    // Parse answers from JSONB columns
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    // Determine which player is the current user
    const userAnswers = isPlayer1 ? player1Answers : player2Answers;
    const partnerAnswers = isPlayer1 ? player2Answers : player1Answers;

    // Build answer details with text
    const answers: QuizAnswerDetail[] = [];
    let alignedCount = 0;
    let differentCount = 0;

    const maxLength = Math.max(userAnswers.length, partnerAnswers.length, quizContent.questions.length);
    for (let i = 0; i < maxLength; i++) {
      const question = quizContent.questions[i];
      const userAnswerIndex = userAnswers[i] ?? -1;
      const partnerAnswerIndex = partnerAnswers[i] ?? -1;

      // For You or Me, alignment is determined differently
      // Each user's answer is from their perspective (0 = partner, 1 = self)
      // They align if both picked the same person
      let isAligned: boolean;
      if (quizType === 'you_or_me') {
        // In You or Me with relative encoding:
        // User picks 0 (partner) or 1 (self)
        // Partner picks 0 (their partner = user) or 1 (self = partner)
        // They align if they agree on who (e.g., both say "user" or both say "partner")
        // user=0 means "partner", partner=0 means "user" (opposite perspectives)
        // So: user=0 + partner=1 = both picked partner
        //     user=1 + partner=0 = both picked user
        // They differ: user=0 + partner=0 or user=1 + partner=1
        isAligned = userAnswerIndex !== partnerAnswerIndex &&
                    userAnswerIndex !== -1 && partnerAnswerIndex !== -1;
      } else {
        isAligned = userAnswerIndex === partnerAnswerIndex && userAnswerIndex !== -1;
      }

      if (isAligned) {
        alignedCount++;
      } else if (userAnswerIndex !== -1 && partnerAnswerIndex !== -1) {
        differentCount++;
      }

      // Get question text
      const questionText = question
        ? getQuestionText(question, quizType)
        : `Question ${i + 1}`;

      // Get answer text - for You or Me, show actual person names
      let userAnswerText: string;
      let partnerAnswerText: string;

      if (quizType === 'you_or_me') {
        // For You or Me, interpret relative encoding for each player
        // User's perspective: 0 = partner, 1 = self (me)
        // Show the actual name they picked
        userAnswerText = userAnswerIndex === 0 ? partnerName :
                         userAnswerIndex === 1 ? userName : 'No answer';
        // Partner's perspective: 0 = their partner (= user), 1 = self (= partner)
        partnerAnswerText = partnerAnswerIndex === 0 ? userName :
                            partnerAnswerIndex === 1 ? partnerName : 'No answer';
      } else if (question) {
        userAnswerText = getAnswerText(question, userAnswerIndex, quizType);
        partnerAnswerText = getAnswerText(question, partnerAnswerIndex, quizType);
      } else {
        userAnswerText = userAnswerIndex >= 0 ? `Option ${userAnswerIndex + 1}` : 'No answer';
        partnerAnswerText = partnerAnswerIndex >= 0 ? `Option ${partnerAnswerIndex + 1}` : 'No answer';
      }

      answers.push({
        questionIndex: i,
        questionText,
        userAnswerIndex,
        userAnswerText,
        partnerAnswerIndex,
        partnerAnswerText,
        isAligned,
      });
    }

    const details: QuizDetails = {
      matchId: match.id,
      quizType: match.quiz_type,
      branch: match.branch,
      quizId: match.quiz_id,
      quizTitle: quizContent.title,
      completedAt: match.completed_at,
      answers,
      alignedCount,
      differentCount,
      matchPercentage: match.match_percentage,
    };

    return NextResponse.json({
      success: true,
      details,
    });
  } catch (error) {
    console.error('Error fetching quiz details:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});
