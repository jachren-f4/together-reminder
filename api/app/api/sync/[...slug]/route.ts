/**
 * Consolidated Sync Routes - Catch-all handler
 *
 * Handles all /api/sync/* routes except:
 * - /api/sync/game/* (handled by separate catch-all)
 * - /api/sync/linked/* (handled by separate catch-all)
 * - /api/sync/word-search/* (handled by separate catch-all)
 * - /api/sync/quiz/* (handled by game catch-all)
 * - /api/sync/you-or-me/* (handled by game catch-all)
 *
 * Routes handled:
 * - /api/sync/daily-quests (GET/POST/PATCH)
 * - /api/sync/daily-quests/completion (POST)
 * - /api/sync/love-points (GET/POST)
 * - /api/sync/steps (GET/POST)
 * - /api/sync/quest-status (GET)
 * - /api/sync/quiz-sessions (GET/POST)
 * - /api/sync/couple-preferences (GET/POST)
 * - /api/sync/couple-stats (GET)
 * - /api/sync/branch-progression (GET/POST)
 * - /api/sync/reminders (POST)
 * - /api/sync/push-token (GET/POST)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { getCoupleId } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';
import { awardLP, getUserLP } from '@/lib/lp/award';

export const dynamic = 'force-dynamic';

// ============================================================================
// MAIN ROUTE HANDLERS
// ============================================================================

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const path = slug?.join('/') || '';

  switch (path) {
    case 'daily-quests':
      return withAuthOrDevBypass(handleDailyQuestsGET)(req);
    case 'love-points':
      return withAuthOrDevBypass(handleLovePointsGET)(req);
    case 'steps':
      return withAuthOrDevBypass(handleStepsGET)(req);
    case 'quest-status':
      return withAuthOrDevBypass(handleQuestStatusGET)(req);
    case 'quiz-sessions':
      return withAuthOrDevBypass(handleQuizSessionsGET)(req);
    case 'couple-preferences':
      return withAuthOrDevBypass(handleCouplePreferencesGET)(req);
    case 'couple-stats':
      return withAuthOrDevBypass(handleCoupleStatsGET)(req);
    case 'branch-progression':
      return withAuthOrDevBypass(handleBranchProgressionGET)(req);
    case 'push-token':
      return withAuthOrDevBypass(handlePushTokenGET)(req);
    default:
      return NextResponse.json({ error: `Unknown sync route: ${path}` }, { status: 404 });
  }
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const path = slug?.join('/') || '';

  switch (path) {
    case 'daily-quests':
      return withAuthOrDevBypass(handleDailyQuestsPOST)(req);
    case 'daily-quests/completion':
      return withAuthOrDevBypass(handleDailyQuestsCompletionPOST)(req);
    case 'love-points':
      return withAuthOrDevBypass(handleLovePointsPOST)(req);
    case 'steps':
      return withAuthOrDevBypass(handleStepsPOST)(req);
    case 'quiz-sessions':
      return withAuthOrDevBypass(handleQuizSessionsPOST)(req);
    case 'couple-preferences':
      return withAuthOrDevBypass(handleCouplePreferencesPOST)(req);
    case 'branch-progression':
      return withAuthOrDevBypass(handleBranchProgressionPOST)(req);
    case 'reminders':
      return withAuthOrDevBypass(handleRemindersPOST)(req);
    case 'push-token':
      return withAuthOrDevBypass(handlePushTokenPOST)(req);
    default:
      return NextResponse.json({ error: `Unknown sync route: ${path}` }, { status: 404 });
  }
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const path = slug?.join('/') || '';

  switch (path) {
    case 'daily-quests':
      return withAuthOrDevBypass(handleDailyQuestsPATCH)(req);
    default:
      return NextResponse.json({ error: `Unknown sync route: ${path}` }, { status: 404 });
  }
}

// ============================================================================
// DAILY QUESTS HANDLERS
// ============================================================================

async function handleDailyQuestsGET(req: NextRequest, userId: string) {
  try {
    const { searchParams } = new URL(req.url);
    const date = searchParams.get('date');

    if (!date) {
      return NextResponse.json({ error: 'Missing date parameter' }, { status: 400 });
    }

    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const questsResult = await query(
      `SELECT * FROM daily_quests
       WHERE couple_id = $1 AND date = $2
       ORDER BY sort_order ASC`,
      [coupleId, date]
    );

    return NextResponse.json({ quests: questsResult.rows });
  } catch (error) {
    console.error('Error fetching quests:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleDailyQuestsPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { quests, dateKey } = body;

    if (!quests || !Array.isArray(quests) || !dateKey) {
      return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
    }

    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    await withTransaction(async (client) => {
      for (const quest of quests) {
        await client.query(
          `INSERT INTO daily_quests (
             id, couple_id, date, quest_type, content_id, sort_order, is_side_quest, metadata, expires_at
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (couple_id, date, quest_type, sort_order)
           DO NOTHING`,
          [
            quest.id,
            coupleId,
            dateKey,
            quest.questType,
            quest.contentId,
            quest.sortOrder,
            quest.isSideQuest,
            JSON.stringify({
              formatType: quest.formatType,
              quizName: quest.quizName
            }),
            new Date(dateKey + 'T23:59:59Z').toISOString()
          ]
        );
      }
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing quests:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleDailyQuestsPATCH(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { questId, contentId } = body;

    if (!questId || !contentId) {
      return NextResponse.json({ error: 'Missing questId or contentId' }, { status: 400 });
    }

    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const result = await query(
      `UPDATE daily_quests
       SET content_id = $1
       WHERE id = $2 AND couple_id = $3
       RETURNING *`,
      [contentId, questId, coupleId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'Quest not found' }, { status: 404 });
    }

    console.log(`Updated quest ${questId} content_id to ${contentId}`);
    return NextResponse.json({ success: true, quest: result.rows[0] });
  } catch (error) {
    console.error('Error updating quest content_id:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleDailyQuestsCompletionPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { quest_id, timestamp } = body;

    if (!quest_id) {
      return NextResponse.json({ error: 'Missing quest_id' }, { status: 400 });
    }

    await query(
      `INSERT INTO quest_completions (quest_id, user_id, completed_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (quest_id, user_id) DO NOTHING`,
      [quest_id, userId, timestamp || new Date().toISOString()]
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing quest completion:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// ============================================================================
// LOVE POINTS HANDLERS
// ============================================================================

async function handleLovePointsGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }
    const coupleId = coupleResult.rows[0].id;

    const total = await getUserLP(userId);

    const transactionsResult = await query(
      `SELECT * FROM love_point_awards
       WHERE couple_id = $1
       ORDER BY created_at DESC
       LIMIT 10`,
      [coupleId]
    );

    return NextResponse.json({
      total,
      transactions: transactionsResult.rows
    });
  } catch (error) {
    console.error('Error fetching love points:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleLovePointsPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { amount, reason, relatedId, multiplier } = body;

    if (!amount || !reason) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }
    const coupleId = coupleResult.rows[0].id;

    const actualAmount = amount * (multiplier || 1);
    const result = await awardLP(coupleId, actualAmount, reason, relatedId);

    return NextResponse.json({
      success: true,
      newTotal: result.newTotal,
      awarded: result.awarded,
      alreadyAwarded: result.alreadyAwarded
    });
  } catch (error) {
    console.error('Error syncing love points:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// ============================================================================
// STEPS HANDLERS
// ============================================================================

async function handleStepsGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const coupleId = coupleResult.rows[0].id;
    const user1Id = coupleResult.rows[0].user1_id;
    const user2Id = coupleResult.rows[0].user2_id;
    const partnerId = userId === user1Id ? user2Id : user1Id;

    const connectionsResult = await query(
      `SELECT user_id, is_connected, connected_at FROM steps_connections WHERE couple_id = $1`,
      [coupleId]
    );

    const userConnection = connectionsResult.rows.find(
      (r: { user_id: string }) => r.user_id === userId
    );
    const partnerConnection = connectionsResult.rows.find(
      (r: { user_id: string }) => r.user_id === partnerId
    );

    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    const stepsResult = await query(
      `SELECT user_id, date_key, steps, last_sync_at
       FROM steps_daily
       WHERE couple_id = $1 AND date_key IN ($2, $3)
       ORDER BY date_key DESC`,
      [coupleId, today, yesterday]
    );

    const claimResult = await query(
      `SELECT * FROM steps_rewards WHERE couple_id = $1 AND date_key = $2`,
      [coupleId, yesterday]
    );

    const stepsMap: Record<
      string,
      { user: { steps: number; lastSync: string | null }; partner: { steps: number; lastSync: string | null } }
    > = {};

    for (const row of stepsResult.rows) {
      const dateKey = row.date_key.toISOString().split('T')[0];
      if (!stepsMap[dateKey]) {
        stepsMap[dateKey] = {
          user: { steps: 0, lastSync: null },
          partner: { steps: 0, lastSync: null },
        };
      }
      if (row.user_id === userId) {
        stepsMap[dateKey].user = { steps: row.steps, lastSync: row.last_sync_at };
      } else {
        stepsMap[dateKey].partner = { steps: row.steps, lastSync: row.last_sync_at };
      }
    }

    return NextResponse.json({
      connection: {
        user: {
          isConnected: userConnection?.is_connected || false,
          connectedAt: userConnection?.connected_at || null,
        },
        partner: {
          isConnected: partnerConnection?.is_connected || false,
          connectedAt: partnerConnection?.connected_at || null,
        },
      },
      today: stepsMap[today] || { user: { steps: 0 }, partner: { steps: 0 } },
      yesterday: stepsMap[yesterday] || { user: { steps: 0 }, partner: { steps: 0 } },
      claim: claimResult.rows[0] || null,
    });
  } catch (error) {
    console.error('Error fetching steps:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleStepsPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { operation } = body;

    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const coupleId = coupleResult.rows[0].id;

    switch (operation) {
      case 'connection':
        return handleConnectionSync(userId, coupleId, body);
      case 'steps':
        return handleStepsSync(userId, coupleId, body);
      case 'claim':
        return handleClaimSync(userId, coupleId, body);
      default:
        return NextResponse.json(
          { error: 'Invalid operation. Use: connection, steps, or claim' },
          { status: 400 }
        );
    }
  } catch (error) {
    console.error('Error syncing steps:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleConnectionSync(
  userId: string,
  coupleId: string,
  body: { isConnected: boolean; connectedAt?: string }
) {
  const { isConnected, connectedAt } = body;

  await query(
    `INSERT INTO steps_connections (user_id, couple_id, is_connected, connected_at, updated_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (user_id) DO UPDATE SET
       is_connected = $3,
       connected_at = COALESCE($4, steps_connections.connected_at),
       updated_at = NOW()`,
    [userId, coupleId, isConnected, connectedAt || null]
  );

  return NextResponse.json({ success: true, operation: 'connection' });
}

async function handleStepsSync(
  userId: string,
  coupleId: string,
  body: { dateKey: string; steps: number; lastSyncAt?: string }
) {
  const { dateKey, steps, lastSyncAt } = body;

  if (!dateKey || steps === undefined) {
    return NextResponse.json(
      { error: 'Missing required fields: dateKey, steps' },
      { status: 400 }
    );
  }

  await query(
    `INSERT INTO steps_daily (couple_id, user_id, date_key, steps, last_sync_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     ON CONFLICT (user_id, date_key) DO UPDATE SET
       steps = $4,
       last_sync_at = COALESCE($5, NOW()),
       updated_at = NOW()`,
    [coupleId, userId, dateKey, steps, lastSyncAt || new Date().toISOString()]
  );

  return NextResponse.json({ success: true, operation: 'steps' });
}

async function handleClaimSync(
  userId: string,
  coupleId: string,
  body: { dateKey: string; combinedSteps: number; lpEarned: number }
) {
  const { dateKey, combinedSteps, lpEarned } = body;

  if (!dateKey || combinedSteps === undefined || lpEarned === undefined) {
    return NextResponse.json(
      { error: 'Missing required fields: dateKey, combinedSteps, lpEarned' },
      { status: 400 }
    );
  }

  try {
    await query(
      `INSERT INTO steps_rewards (couple_id, date_key, combined_steps, lp_earned, claimed_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [coupleId, dateKey, combinedSteps, lpEarned, userId]
    );

    await awardLP(coupleId, lpEarned, 'steps_claim', dateKey);

    return NextResponse.json({ success: true, operation: 'claim', alreadyClaimed: false });
  } catch (error: unknown) {
    if (error && typeof error === 'object' && 'code' in error && error.code === '23505') {
      return NextResponse.json({ success: true, operation: 'claim', alreadyClaimed: true });
    }
    throw error;
  }
}

// ============================================================================
// QUEST STATUS HANDLER
// ============================================================================

async function handleQuestStatusGET(req: NextRequest, userId: string) {
  try {
    const { searchParams } = new URL(req.url);
    const dateParam = searchParams.get('date');
    const date = dateParam || new Date().toISOString().split('T')[0];

    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, total_lp FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'No couple found for user' }, { status: 404 });
    }

    const { id: coupleId, user1_id, user2_id, total_lp } = coupleResult.rows[0];
    const partnerId = userId === user1_id ? user2_id : user1_id;
    const isPlayer1 = userId === user1_id;

    const quizMatchesResult = await query(
      `SELECT id, quiz_type, quiz_id, status,
              player1_answer_count, player2_answer_count,
              player1_score, player2_score,
              match_percentage, completed_at
       FROM quiz_matches
       WHERE couple_id = $1 AND DATE(created_at) = $2`,
      [coupleId, date]
    );

    const quests: any[] = [];

    for (const match of quizMatchesResult.rows) {
      const userAnswered = isPlayer1
        ? (match.player1_answer_count || 0) > 0
        : (match.player2_answer_count || 0) > 0;
      const partnerAnswered = isPlayer1
        ? (match.player2_answer_count || 0) > 0
        : (match.player1_answer_count || 0) > 0;

      quests.push({
        questId: match.quiz_id,
        questType: match.quiz_type,
        status: match.status,
        userCompleted: userAnswered,
        partnerCompleted: partnerAnswered,
        matchId: match.id,
        matchPercentage: match.match_percentage,
        player1Score: match.player1_score,
        player2Score: match.player2_score,
        lpAwarded: match.status === 'completed' ? 30 : 0,
      });
    }

    return NextResponse.json({
      quests,
      totalLp: total_lp || 0,
      userId,
      partnerId,
      date,
    });
  } catch (error) {
    console.error('Error fetching quest status:', error);
    return NextResponse.json({ error: 'Failed to fetch quest status' }, { status: 500 });
  }
}

// ============================================================================
// QUIZ SESSIONS HANDLERS
// ============================================================================

async function handleQuizSessionsGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }
    const coupleId = coupleResult.rows[0].id;

    const sessionsResult = await query(
      `SELECT * FROM quiz_sessions
       WHERE couple_id = $1
       ORDER BY created_at DESC
       LIMIT 10`,
      [coupleId]
    );

    return NextResponse.json({ sessions: sessionsResult.rows });
  } catch (error) {
    console.error('Error fetching quiz sessions:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleQuizSessionsPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const {
      id,
      questionIds,
      createdAt,
      expiresAt,
      status,
      formatType,
      isDailyQuest,
      answers,
      completedAt,
      quizName,
      category
    } = body;

    if (!id) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }
    const coupleId = coupleResult.rows[0].id;

    const client = await getClient();
    try {
      await client.query('BEGIN');

      await client.query(
        `INSERT INTO quiz_sessions (
           id, couple_id, created_by, format_type, category, status, questions,
           quiz_name, is_daily_quest, created_at, expires_at, completed_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (id) DO UPDATE SET
           status = EXCLUDED.status,
           completed_at = EXCLUDED.completed_at,
           questions = EXCLUDED.questions`,
        [
          id,
          coupleId,
          userId,
          formatType,
          category,
          status,
          JSON.stringify(questionIds),
          quizName,
          isDailyQuest,
          new Date(createdAt).toISOString(),
          new Date(expiresAt).toISOString(),
          completedAt ? new Date(completedAt).toISOString() : null
        ]
      );

      if (answers) {
        const qIds = questionIds as string[];
        for (const [uid, userAnswers] of Object.entries(answers)) {
          const ansIndices = userAnswers as number[];
          for (let i = 0; i < ansIndices.length; i++) {
            if (i < qIds.length) {
              await client.query(
                `INSERT INTO quiz_answers (
                   session_id, user_id, question_id, selected_index, is_correct, answered_at
                 ) VALUES ($1, $2, $3, $4, $5, NOW())
                 ON CONFLICT (session_id, user_id, question_id) DO UPDATE SET
                   selected_index = EXCLUDED.selected_index`,
                [id, uid, qIds[i], ansIndices[i], false]
              );
            }
          }
        }
      }

      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing quiz session:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// ============================================================================
// COUPLE PREFERENCES HANDLERS
// ============================================================================

async function handleCouplePreferencesGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, first_player_id, anniversary_date, created_at
       FROM couples
       WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const couple = coupleResult.rows[0];
    const firstPlayerId = couple.first_player_id || couple.user2_id;

    return NextResponse.json({
      coupleId: couple.id,
      user1Id: couple.user1_id,
      user2Id: couple.user2_id,
      firstPlayerId: firstPlayerId,
      isDefaultValue: couple.first_player_id === null,
      anniversaryDate: couple.anniversary_date ? couple.anniversary_date.toISOString().split('T')[0] : null
    });
  } catch (error) {
    console.error('Error fetching couple preferences:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handleCouplePreferencesPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { firstPlayerId, anniversaryDate } = body;

    if (firstPlayerId === undefined && anniversaryDate === undefined) {
      return NextResponse.json({ error: 'Missing firstPlayerId or anniversaryDate' }, { status: 400 });
    }

    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, first_player_id, anniversary_date FROM couples
       WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const couple = coupleResult.rows[0];
    const coupleId = couple.id;

    if (firstPlayerId !== undefined) {
      if (firstPlayerId !== couple.user1_id && firstPlayerId !== couple.user2_id) {
        return NextResponse.json(
          { error: 'Invalid player ID - must be one of the couple members' },
          { status: 400 }
        );
      }
    }

    const updates: string[] = [];
    const values: (string | null | Date)[] = [];
    let paramIndex = 1;

    if (firstPlayerId !== undefined) {
      updates.push(`first_player_id = $${paramIndex}`);
      values.push(firstPlayerId);
      paramIndex++;
    }

    if (anniversaryDate !== undefined) {
      updates.push(`anniversary_date = $${paramIndex}`);
      values.push(anniversaryDate ? new Date(anniversaryDate) : null);
      paramIndex++;
    }

    updates.push('updated_at = NOW()');
    values.push(coupleId);

    await query(
      `UPDATE couples SET ${updates.join(', ')} WHERE id = $${paramIndex}`,
      values
    );

    const updatedResult = await query(
      `SELECT first_player_id, anniversary_date FROM couples WHERE id = $1`,
      [coupleId]
    );
    const updated = updatedResult.rows[0];

    return NextResponse.json({
      success: true,
      coupleId: coupleId,
      firstPlayerId: updated.first_player_id || couple.user2_id,
      anniversaryDate: updated.anniversary_date ? updated.anniversary_date.toISOString().split('T')[0] : null
    });
  } catch (error) {
    console.error('Error updating couple preferences:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// ============================================================================
// COUPLE STATS HANDLER
// ============================================================================

async function handleCoupleStatsGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT
          c.id as couple_id,
          c.user1_id,
          c.user2_id,
          c.anniversary_date,
          u1.raw_user_meta_data->>'full_name' as user1_name,
          u2.raw_user_meta_data->>'full_name' as user2_name
       FROM couples c
       LEFT JOIN auth.users u1 ON c.user1_id = u1.id
       LEFT JOIN auth.users u2 ON c.user2_id = u2.id
       WHERE c.user1_id = $1 OR c.user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const couple = coupleResult.rows[0];
    const coupleId = couple.couple_id;
    const user1Id = couple.user1_id;
    const user2Id = couple.user2_id;

    const activitiesResult = await query(
      `SELECT
          user_id,
          COUNT(*) as count
       FROM quest_completions qc
       JOIN daily_quests dq ON qc.quest_id = dq.id
       WHERE dq.couple_id = $1
       GROUP BY user_id`,
      [coupleId]
    );

    const activitiesByUser: Record<string, number> = {};
    for (const row of activitiesResult.rows) {
      activitiesByUser[row.user_id] = parseInt(row.count);
    }

    const streakUser1 = await calculateStreak(coupleId, user1Id);
    const streakUser2 = await calculateStreak(coupleId, user2Id);

    const gamesWonResult = await query(
      `WITH quiz_scores AS (
          SELECT
              qs.id as session_id,
              qa.user_id,
              COUNT(CASE WHEN qa.is_correct THEN 1 END) as correct_count
          FROM quiz_sessions qs
          JOIN quiz_answers qa ON qs.id = qa.session_id
          WHERE qs.couple_id = $1 AND qs.completed_at IS NOT NULL
          GROUP BY qs.id, qa.user_id
      ),
      session_winners AS (
          SELECT
              s1.session_id,
              CASE
                  WHEN s1.correct_count > s2.correct_count THEN s1.user_id
                  WHEN s2.correct_count > s1.correct_count THEN s2.user_id
                  ELSE NULL
              END as winner_id
          FROM quiz_scores s1
          JOIN quiz_scores s2 ON s1.session_id = s2.session_id AND s1.user_id != s2.user_id
          WHERE s1.user_id = $2
      )
      SELECT winner_id, COUNT(*) as wins
      FROM session_winners
      WHERE winner_id IS NOT NULL
      GROUP BY winner_id`,
      [coupleId, user1Id]
    );

    const gameWinsByUser: Record<string, number> = {};
    for (const row of gamesWonResult.rows) {
      gameWinsByUser[row.winner_id] = parseInt(row.wins);
    }

    const user1Name = couple.user1_name || 'Partner 1';
    const user2Name = couple.user2_name || 'Partner 2';

    return NextResponse.json({
      anniversaryDate: couple.anniversary_date
        ? couple.anniversary_date.toISOString().split('T')[0]
        : null,
      user1: {
        id: user1Id,
        name: user1Name,
        initial: user1Name.charAt(0).toUpperCase(),
        activitiesCompleted: activitiesByUser[user1Id] || 0,
        currentStreakDays: streakUser1,
        coupleGamesWon: gameWinsByUser[user1Id] || 0
      },
      user2: {
        id: user2Id,
        name: user2Name,
        initial: user2Name.charAt(0).toUpperCase(),
        activitiesCompleted: activitiesByUser[user2Id] || 0,
        currentStreakDays: streakUser2,
        coupleGamesWon: gameWinsByUser[user2Id] || 0
      },
      currentUserId: userId
    });
  } catch (error) {
    console.error('Error fetching couple stats:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function calculateStreak(coupleId: string, userId: string): Promise<number> {
  try {
    const result = await query(
      `WITH completion_dates AS (
          SELECT DISTINCT DATE(qc.completed_at) as completion_date
          FROM quest_completions qc
          JOIN daily_quests dq ON qc.quest_id = dq.id
          WHERE dq.couple_id = $1 AND qc.user_id = $2
          ORDER BY completion_date DESC
      ),
      streak_calc AS (
          SELECT
              completion_date,
              completion_date - (ROW_NUMBER() OVER (ORDER BY completion_date DESC))::int as streak_group
          FROM completion_dates
          WHERE completion_date >= CURRENT_DATE - INTERVAL '1 day'
             OR completion_date = CURRENT_DATE
      )
      SELECT COUNT(*) as streak
      FROM streak_calc
      WHERE streak_group = (
          SELECT streak_group FROM streak_calc LIMIT 1
      )`,
      [coupleId, userId]
    );

    return parseInt(result.rows[0]?.streak || '0');
  } catch (error) {
    console.error('Error calculating streak:', error);
    return 0;
  }
}

// ============================================================================
// BRANCH PROGRESSION HANDLERS
// ============================================================================

const VALID_ACTIVITY_TYPES = ['classicQuiz', 'affirmation', 'youOrMe', 'linked', 'wordSearch'];

async function handleBranchProgressionGET(req: NextRequest, userId: string) {
  const searchParams = req.nextUrl.searchParams;
  const coupleId = searchParams.get('couple_id');
  const activityType = searchParams.get('activity_type');

  if (!coupleId) {
    return NextResponse.json({ error: 'couple_id is required' }, { status: 400 });
  }

  try {
    if (activityType) {
      if (!VALID_ACTIVITY_TYPES.includes(activityType)) {
        return NextResponse.json(
          { error: `Invalid activity_type. Must be one of: ${VALID_ACTIVITY_TYPES.join(', ')}` },
          { status: 400 }
        );
      }

      const result = await query(
        `SELECT couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at
         FROM branch_progression
         WHERE couple_id = $1 AND activity_type = $2`,
        [coupleId, activityType]
      );

      if (result.rows.length === 0) {
        return NextResponse.json({ state: null }, { status: 200 });
      }

      return NextResponse.json({
        state: formatBranchStateForResponse(result.rows[0])
      });
    } else {
      const result = await query(
        `SELECT couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at
         FROM branch_progression
         WHERE couple_id = $1`,
        [coupleId]
      );

      return NextResponse.json({
        states: result.rows.map(formatBranchStateForResponse)
      });
    }
  } catch (error) {
    console.error('Error fetching branch progression:', error);
    return NextResponse.json({ error: 'Failed to fetch branch progression' }, { status: 500 });
  }
}

async function handleBranchProgressionPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const {
      couple_id,
      activity_type,
      current_branch,
      total_completions,
      max_branches = 3,
      last_completed_at,
    } = body;

    if (!couple_id) {
      return NextResponse.json({ error: 'couple_id is required' }, { status: 400 });
    }
    if (!activity_type || !VALID_ACTIVITY_TYPES.includes(activity_type)) {
      return NextResponse.json(
        { error: `Invalid activity_type. Must be one of: ${VALID_ACTIVITY_TYPES.join(', ')}` },
        { status: 400 }
      );
    }
    if (current_branch === undefined || typeof current_branch !== 'number') {
      return NextResponse.json({ error: 'current_branch is required and must be a number' }, { status: 400 });
    }
    if (total_completions === undefined || typeof total_completions !== 'number') {
      return NextResponse.json({ error: 'total_completions is required and must be a number' }, { status: 400 });
    }

    const result = await query(
      `INSERT INTO branch_progression (
        couple_id, activity_type, current_branch, total_completions,
        max_branches, last_completed_at
      ) VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (couple_id, activity_type)
      DO UPDATE SET
        current_branch = EXCLUDED.current_branch,
        total_completions = EXCLUDED.total_completions,
        max_branches = EXCLUDED.max_branches,
        last_completed_at = EXCLUDED.last_completed_at,
        updated_at = NOW()
      RETURNING couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at`,
      [couple_id, activity_type, current_branch, total_completions, max_branches, last_completed_at || null]
    );

    console.log(`Branch progression updated: ${couple_id} / ${activity_type} -> branch ${current_branch} (${total_completions} completions)`);

    return NextResponse.json({
      success: true,
      state: formatBranchStateForResponse(result.rows[0])
    });
  } catch (error) {
    console.error('Error updating branch progression:', error);
    return NextResponse.json({ error: 'Failed to update branch progression' }, { status: 500 });
  }
}

function formatBranchStateForResponse(row: any) {
  return {
    couple_id: row.couple_id,
    activity_type: row.activity_type,
    current_branch: row.current_branch,
    total_completions: row.total_completions,
    max_branches: row.max_branches,
    last_completed_at: row.last_completed_at?.toISOString() || null,
    created_at: row.created_at?.toISOString() || null,
  };
}

// ============================================================================
// REMINDERS HANDLER
// ============================================================================

async function handleRemindersPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const {
      id,
      type,
      fromName,
      toName,
      text,
      category = 'reminder',
      emoji,
      scheduledFor,
      status = 'pending',
      createdAt,
      sentAt,
    } = body;

    if (!id || !type || !fromName || !toName || !text || !scheduledFor || !createdAt) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'No couple found for user' }, { status: 404 });
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];

    let fromUserId: string;
    let toUserId: string;

    if (type === 'sent') {
      fromUserId = userId;
      toUserId = user1_id === userId ? user2_id : user1_id;
    } else {
      toUserId = userId;
      fromUserId = user1_id === userId ? user2_id : user1_id;
    }

    await query(
      `INSERT INTO reminders (
        id, couple_id, type, from_user_id, to_user_id, from_name, to_name,
        text, category, emoji, scheduled_for, status, created_at, sent_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      ON CONFLICT (id) DO UPDATE SET
        status = EXCLUDED.status,
        sent_at = EXCLUDED.sent_at`,
      [id, coupleId, type, fromUserId, toUserId, fromName, toName, text, category, emoji, scheduledFor, status, createdAt, sentAt || null]
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing reminder/poke:', error);
    return NextResponse.json({ error: 'Failed to sync reminder/poke' }, { status: 500 });
  }
}

// ============================================================================
// PUSH TOKEN HANDLERS
// ============================================================================

async function handlePushTokenGET(req: NextRequest, userId: string) {
  try {
    const coupleResult = await query(
      `SELECT user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ partnerToken: null, partnerPlatform: null });
    }

    const couple = coupleResult.rows[0];
    const partnerId = couple.user1_id === userId ? couple.user2_id : couple.user1_id;

    const tokenResult = await query(
      `SELECT fcm_token, platform FROM user_push_tokens WHERE user_id = $1`,
      [partnerId]
    );

    if (tokenResult.rows.length === 0) {
      return NextResponse.json({ partnerToken: null, partnerPlatform: null });
    }

    const { fcm_token, platform } = tokenResult.rows[0];

    return NextResponse.json({
      partnerToken: fcm_token,
      partnerPlatform: platform,
    });
  } catch (error) {
    console.error('Error getting partner push token:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

async function handlePushTokenPOST(req: NextRequest, userId: string) {
  try {
    const body = await req.json();
    const { fcmToken, platform, deviceName } = body;

    if (!fcmToken) {
      return NextResponse.json({ error: 'fcmToken is required' }, { status: 400 });
    }

    if (!platform || !['ios', 'android', 'web'].includes(platform)) {
      return NextResponse.json(
        { error: 'platform must be ios, android, or web' },
        { status: 400 }
      );
    }

    await query(
      `INSERT INTO user_push_tokens (user_id, fcm_token, platform, device_name, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET
         fcm_token = EXCLUDED.fcm_token,
         platform = EXCLUDED.platform,
         device_name = COALESCE(EXCLUDED.device_name, user_push_tokens.device_name),
         updated_at = NOW()`,
      [userId, fcmToken, platform, deviceName || null]
    );

    console.log(`[PUSH TOKEN] Registered for user ${userId} on ${platform}`);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error registering push token:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
