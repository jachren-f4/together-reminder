import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

/**
 * GET /api/sync/couple-preferences
 * Fetch couple preferences including first_player_id and anniversary_date
 * Returns user2_id as default if first_player_id is null
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        // 1. Find couple with all relevant fields
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

        // Default to user2_id (latest joiner) if first_player_id is null
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
});

/**
 * POST /api/sync/couple-preferences
 * Update couple preferences (first_player_id and/or anniversary_date)
 * Body: { firstPlayerId?: string, anniversaryDate?: string | null }
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { firstPlayerId, anniversaryDate } = body;

        // At least one field must be provided
        if (firstPlayerId === undefined && anniversaryDate === undefined) {
            return NextResponse.json({ error: 'Missing firstPlayerId or anniversaryDate' }, { status: 400 });
        }

        // 1. Find couple
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

        // 2. Validate firstPlayerId if provided
        if (firstPlayerId !== undefined) {
            if (firstPlayerId !== couple.user1_id && firstPlayerId !== couple.user2_id) {
                return NextResponse.json(
                    { error: 'Invalid player ID - must be one of the couple members' },
                    { status: 400 }
                );
            }
        }

        // 3. Build update query dynamically
        const updates: string[] = [];
        const values: (string | null | Date)[] = [];
        let paramIndex = 1;

        if (firstPlayerId !== undefined) {
            updates.push(`first_player_id = $${paramIndex}`);
            values.push(firstPlayerId);
            paramIndex++;
        }

        if (anniversaryDate !== undefined) {
            // "First one wins" - only set anniversary if not already set
            // Unless explicitly clearing (null) or overwrite flag is true
            const shouldSetAnniversary =
                anniversaryDate === null ||  // Allow clearing
                body.overwrite === true ||   // Allow explicit overwrite from settings
                couple.anniversary_date === null;  // First one wins

            if (shouldSetAnniversary) {
                updates.push(`anniversary_date = $${paramIndex}`);
                values.push(anniversaryDate ? new Date(anniversaryDate) : null);
                paramIndex++;
            }
        }

        updates.push('updated_at = NOW()');
        values.push(coupleId);

        await query(
            `UPDATE couples SET ${updates.join(', ')} WHERE id = $${paramIndex}`,
            values
        );

        // 4. Fetch updated values
        const updatedResult = await query(
            `SELECT first_player_id, anniversary_date FROM couples WHERE id = $1`,
            [coupleId]
        );
        const updated = updatedResult.rows[0];

        // 5. Return success with updated values
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
});
