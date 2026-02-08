/**
 * Create Couple with Phantom Partner
 *
 * POST /api/couples/create-with-phantom
 *
 * Creates a phantom Supabase Auth account for the partner and pairs
 * them with the caller. This enables single-phone mode where one
 * device submits answers for both players.
 *
 * The phantom user is a real auth.users row that no one logs into.
 * All game endpoints work unchanged because they see two real user IDs.
 */

import { NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { getClient } from '@/lib/db/pool';
import { createClient } from '@/lib/supabase/server';
import { randomUUID } from 'crypto';

export const dynamic = 'force-dynamic';

export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { partnerName } = body;

    if (!partnerName || typeof partnerName !== 'string' || partnerName.trim().length === 0) {
      return NextResponse.json(
        { error: 'partnerName is required' },
        { status: 400 }
      );
    }

    const trimmedName = partnerName.trim();

    // Check if user already has a partner
    const existingCouple = await client.query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (existingCouple.rows.length > 0) {
      client.release();
      return NextResponse.json(
        { error: 'You are already paired with a partner' },
        { status: 400 }
      );
    }

    // Create phantom user via Supabase Admin API
    const supabase = createClient();
    const phantomId = randomUUID();
    const phantomEmail = `phantom-${phantomId}@internal.togetherremind.app`;

    const { data: phantomUser, error: createError } = await supabase.auth.admin.createUser({
      email: phantomEmail,
      password: randomUUID(), // Random password nobody will use
      email_confirm: true,
      user_metadata: {
        is_phantom: 'true',
        full_name: trimmedName,
        created_by: userId,
      },
    });

    if (createError || !phantomUser?.user) {
      client.release();
      console.error('Failed to create phantom user:', createError);
      return NextResponse.json(
        { error: 'Failed to create phantom partner' },
        { status: 500 }
      );
    }

    const phantomUserId = phantomUser.user.id;

    // Create couple in a transaction
    await client.query('BEGIN');

    const coupleId = randomUUID();
    await client.query(
      `INSERT INTO couples (id, user1_id, user2_id, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())`,
      [coupleId, userId, phantomUserId]
    );

    // Insert into user_couples lookup table for both users
    // Use upsert in case stale rows exist from a previous couple
    await client.query(
      `INSERT INTO user_couples (user_id, couple_id) VALUES ($1, $2), ($3, $2)
       ON CONFLICT (user_id) DO UPDATE SET couple_id = EXCLUDED.couple_id`,
      [userId, coupleId, phantomUserId]
    );

    // Initialize couple_unlocks row
    await client.query(
      `INSERT INTO couple_unlocks (couple_id) VALUES ($1) ON CONFLICT DO NOTHING`,
      [coupleId]
    );

    await client.query('COMMIT');
    client.release();

    return NextResponse.json({
      coupleId,
      phantomUserId,
      partnerName: trimmedName,
      message: 'Phantom partner created successfully',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    client.release();
    console.error('Error creating phantom couple:', error);
    return NextResponse.json(
      { error: 'Failed to create couple with phantom partner' },
      { status: 500 }
    );
  }
});
