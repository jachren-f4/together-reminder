import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

/**
 * POST /api/sync/steps
 *
 * Sync step data from Flutter app to Supabase.
 * Handles three types of sync operations:
 * 1. Connection status update (isConnected, connectedAt)
 * 2. Daily steps update (steps, lastSyncAt)
 * 3. Claim reward (dateKey, combinedSteps, lpEarned)
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { operation } = body;

    // Find couple
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
});

/**
 * Sync connection status (HealthKit/Health Connect connected)
 */
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

/**
 * Sync daily step count
 */
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

/**
 * Sync reward claim (prevents double-claiming via UNIQUE constraint)
 */
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
    // Insert claim - will fail if already claimed (UNIQUE constraint)
    await query(
      `INSERT INTO steps_rewards (couple_id, date_key, combined_steps, lp_earned, claimed_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [coupleId, dateKey, combinedSteps, lpEarned, userId]
    );

    return NextResponse.json({ success: true, operation: 'claim', alreadyClaimed: false });
  } catch (error: unknown) {
    // Check if it's a unique constraint violation (already claimed)
    if (error && typeof error === 'object' && 'code' in error && error.code === '23505') {
      return NextResponse.json({ success: true, operation: 'claim', alreadyClaimed: true });
    }
    throw error;
  }
}

/**
 * GET /api/sync/steps
 *
 * Get current step data for the couple.
 * Returns connection status, today's steps, yesterday's steps, and claim status.
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    // Find couple
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

    // Get connection status for both users
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

    // Get today's date
    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    // Get steps for today and yesterday
    const stepsResult = await query(
      `SELECT user_id, date_key, steps, last_sync_at
       FROM steps_daily
       WHERE couple_id = $1 AND date_key IN ($2, $3)
       ORDER BY date_key DESC`,
      [coupleId, today, yesterday]
    );

    // Get claim status for yesterday
    const claimResult = await query(
      `SELECT * FROM steps_rewards WHERE couple_id = $1 AND date_key = $2`,
      [coupleId, yesterday]
    );

    // Organize response
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
});
