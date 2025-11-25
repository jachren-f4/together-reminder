import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

/**
 * GET /api/sync/couple-preferences
 * Fetch couple preferences including first_player_id
 * Returns user2_id as default if first_player_id is null
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        // 1. Find couple with all relevant fields
        const coupleResult = await query(
            `SELECT id, user1_id, user2_id, first_player_id, created_at
             FROM couples
             WHERE user1_id = $1 OR user2_id = $1`,
            [userId]
        );

        if (coupleResult.rows.length === 0) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        const couple = coupleResult.rows[0];

        // Default to user2_id (latest joiner) if first_player_id is null
        const firstPlayerId = couple.first_player_id || couple.user2_id;

        return NextResponse.json({
            coupleId: couple.id,
            user1Id: couple.user1_id,
            user2Id: couple.user2_id,
            firstPlayerId: firstPlayerId,
            isDefaultValue: couple.first_player_id === null
        });
    } catch (error) {
        console.error('Error fetching couple preferences:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});

/**
 * POST /api/sync/couple-preferences
 * Update couple preferences (first_player_id)
 * Body: { firstPlayerId: string }
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { firstPlayerId } = body;

        if (!firstPlayerId) {
            return NextResponse.json({ error: 'Missing firstPlayerId' }, { status: 400 });
        }

        // 1. Find couple
        const coupleResult = await query(
            `SELECT id, user1_id, user2_id FROM couples
             WHERE user1_id = $1 OR user2_id = $1`,
            [userId]
        );

        if (coupleResult.rows.length === 0) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        const couple = coupleResult.rows[0];
        const coupleId = couple.id;

        // 2. Validate that firstPlayerId is either user1_id or user2_id
        if (firstPlayerId !== couple.user1_id && firstPlayerId !== couple.user2_id) {
            return NextResponse.json(
                { error: 'Invalid player ID - must be one of the couple members' },
                { status: 400 }
            );
        }

        // 3. Update first_player_id in couples table
        await query(
            `UPDATE couples
             SET first_player_id = $1, updated_at = NOW()
             WHERE id = $2`,
            [firstPlayerId, coupleId]
        );

        // 4. Return success with updated values
        return NextResponse.json({
            success: true,
            coupleId: coupleId,
            firstPlayerId: firstPlayerId
        });
    } catch (error) {
        console.error('Error updating couple preferences:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});
