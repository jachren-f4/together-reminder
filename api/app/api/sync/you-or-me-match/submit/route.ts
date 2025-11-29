/**
 * You-or-Me Match Submit API Endpoint
 *
 * Handles incremental answer submission for You-or-Me game.
 * Each player answers one question at a time, alternating turns.
 * Awards LP when all questions are answered by both players.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { awardLP } from '@/lib/lp/award';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// LP reward for completing You-or-Me
const LP_REWARD = 30;

// Load quiz to get total questions
function loadQuiz(branch: string, quizId: string): any {
  try {
    const quizPath = join(process.cwd(), 'data', 'puzzles', 'you-or-me', branch, `${quizId}.json`);
    const quizData = readFileSync(quizPath, 'utf-8');
    return JSON.parse(quizData);
  } catch (error) {
    console.error(`Failed to load you-or-me quiz ${quizId} from ${branch}:`, error);
    return null;
  }
}

/**
 * POST /api/sync/you-or-me-match/submit
 *
 * Submit a single answer for You-or-Me game.
 *
 * Request body:
 * {
 *   matchId: "uuid",
 *   questionIndex: 3,
 *   answer: "you" | "me"
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const { matchId, questionIndex, answer } = body;

    if (!matchId || questionIndex === undefined || !answer) {
      return NextResponse.json(
        { error: 'Missing required fields: matchId, questionIndex, answer' },
        { status: 400 }
      );
    }

    if (!['you', 'me'].includes(answer)) {
      return NextResponse.json(
        { error: 'Invalid answer. Must be "you" or "me"' },
        { status: 400 }
      );
    }

    // Get couple info
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];
    const isPlayer1 = userId === user1_id;
    const partnerId = isPlayer1 ? user2_id : user1_id;

    // Get current match
    const matchResult = await query(
      `SELECT * FROM quiz_matches WHERE id = $1 AND couple_id = $2`,
      [matchId, coupleId]
    );

    if (matchResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found', code: 'NO_MATCH' },
        { status: 404 }
      );
    }

    const match = matchResult.rows[0];

    // Check match is still active
    if (match.status !== 'active') {
      return NextResponse.json(
        { error: 'Match already completed', code: 'ALREADY_COMPLETED' },
        { status: 400 }
      );
    }

    // Check it's the user's turn
    if (match.current_turn_user_id !== userId) {
      return NextResponse.json(
        { error: "Not your turn", code: 'NOT_YOUR_TURN' },
        { status: 400 }
      );
    }

    // Parse existing answers
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    // Add the answer
    const updatedPlayer1Answers = isPlayer1
      ? [...player1Answers, answer]
      : player1Answers;
    const updatedPlayer2Answers = isPlayer1
      ? player2Answers
      : [...player2Answers, answer];

    // Load quiz to get total questions
    const quiz = loadQuiz(match.branch, match.quiz_id);
    const totalQuestions = quiz?.questions?.length || 10;

    // Calculate scores (each player gets a point when answers match for same question)
    let player1Score = match.player1_score || 0;
    let player2Score = match.player2_score || 0;

    // Check if we can compare answers for this question
    const userAnswerCount = isPlayer1 ? updatedPlayer1Answers.length : updatedPlayer2Answers.length;
    const partnerAnswerCount = isPlayer1 ? updatedPlayer2Answers.length : updatedPlayer1Answers.length;

    // If both have answered the same question, check for match
    const minAnswers = Math.min(userAnswerCount, partnerAnswerCount);
    if (updatedPlayer1Answers.length === updatedPlayer2Answers.length) {
      const qIdx = updatedPlayer1Answers.length - 1;
      if (updatedPlayer1Answers[qIdx] === updatedPlayer2Answers[qIdx]) {
        // Answers match - both players "win" this round
        player1Score += 1;
        player2Score += 1;
      }
    }

    // Determine next turn and check completion
    const newTurnNumber = match.turn_number + 1;
    let isCompleted = false;
    let lpEarned = 0;

    // Check if game is complete (both players have answered all questions)
    if (updatedPlayer1Answers.length >= totalQuestions &&
        updatedPlayer2Answers.length >= totalQuestions) {
      isCompleted = true;
      lpEarned = LP_REWARD;
      await awardLP(coupleId, lpEarned, 'you_or_me_complete', matchId);
    }

    // Turn logic: Each player answers ALL questions before switching turns
    // - Keep current user's turn until they've answered all questions
    // - Then switch to partner (if partner hasn't finished yet)
    // Note: userAnswerCount and partnerAnswerCount already defined above (lines 168-169)

    let nextTurnUserId: string | null;
    if (userAnswerCount >= totalQuestions) {
      // I'm done - switch to partner (unless they're also done)
      nextTurnUserId = partnerAnswerCount >= totalQuestions ? null : partnerId;
    } else {
      // I still have questions - keep my turn
      nextTurnUserId = userId;
    }

    // Update match in database
    const updateResult = await query(
      `UPDATE quiz_matches
       SET player1_answers = $1,
           player2_answers = $2,
           player1_answer_count = $3,
           player2_answer_count = $4,
           player1_score = $5,
           player2_score = $6,
           current_turn_user_id = $7,
           turn_number = $8,
           status = $9,
           completed_at = $10
       WHERE id = $11
       RETURNING *`,
      [
        JSON.stringify(updatedPlayer1Answers),
        JSON.stringify(updatedPlayer2Answers),
        updatedPlayer1Answers.length,
        updatedPlayer2Answers.length,
        player1Score,
        player2Score,
        isCompleted ? null : nextTurnUserId,
        newTurnNumber,
        isCompleted ? 'completed' : 'active',
        isCompleted ? new Date().toISOString() : null,
        matchId,
      ]
    );

    const updatedMatch = updateResult.rows[0];

    return NextResponse.json({
      success: true,
      isCompleted,
      lpEarned,
      match: {
        id: updatedMatch.id,
        quizId: updatedMatch.quiz_id,
        status: updatedMatch.status,
        player1Answers: updatedPlayer1Answers,
        player2Answers: updatedPlayer2Answers,
        player1AnswerCount: updatedPlayer1Answers.length,
        player2AnswerCount: updatedPlayer2Answers.length,
        player1Score,
        player2Score,
        currentTurnUserId: updatedMatch.current_turn_user_id,
        turnNumber: updatedMatch.turn_number,
        completedAt: updatedMatch.completed_at,
      },
      gameState: {
        isMyTurn: nextTurnUserId === userId && !isCompleted,
        canPlay: nextTurnUserId === userId && !isCompleted,
        currentQuestion: userAnswerCount, // The next question index for this player
        myAnswerCount: userAnswerCount,
        partnerAnswerCount,
        myScore: isPlayer1 ? player1Score : player2Score,
        partnerScore: isPlayer1 ? player2Score : player1Score,
        isCompleted,
        totalQuestions,
      }
    });
  } catch (error) {
    console.error('Error submitting You-or-Me answer:', error);
    return NextResponse.json(
      { error: 'Failed to submit answer' },
      { status: 500 }
    );
  }
});
