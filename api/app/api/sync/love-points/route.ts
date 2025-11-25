import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { amount, reason, relatedId, multiplier, timestamp, partnerId } = body;

        if (!amount || !reason) {
            return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
        }

        // 1. Find couple
        const coupleResult = await query(
            `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
            [userId]
        );

        if (coupleResult.rows.length === 0) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }
        const coupleId = coupleResult.rows[0].id;

        // 2. Insert LP award
        // We use ON CONFLICT DO NOTHING to handle idempotency via related_id
        // If relatedId is not provided, we generate a UUID (handled by client usually, but we can fallback)

        const awardId = body.id || crypto.randomUUID();

        await query(
            `INSERT INTO love_point_awards (
         id, couple_id, amount, reason, related_id, multiplier, created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (couple_id, related_id) DO NOTHING`,
            [
                awardId,
                coupleId,
                amount,
                reason,
                relatedId || null, // related_id is unique per couple
                multiplier || 1,
                timestamp || new Date().toISOString()
            ]
        );

        // 3. Update user totals (Materialized view pattern)
        // We update both users in the couple since this is a shared award (usually)
        // But the request comes from one user. 
        // The client logic says "awardPointsToBothUsers", so we should update both.

        // However, strictly speaking, the `love_point_awards` table tracks the *event*.
        // The `user_love_points` table tracks the *state*.
        // We should update `user_love_points` for both users.

        // Get both user IDs
        const coupleUsers = await query(
            `SELECT user1_id, user2_id FROM couples WHERE id = $1`,
            [coupleId]
        );

        const user1 = coupleUsers.rows[0].user1_id;
        const user2 = coupleUsers.rows[0].user2_id;

        const actualAmount = amount * (multiplier || 1);

        // Update User 1
        await query(
            `INSERT INTO user_love_points (user_id, total_points, last_activity_date)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id) DO UPDATE
       SET total_points = user_love_points.total_points + $2,
           last_activity_date = NOW()`,
            [user1, actualAmount]
        );

        // Update User 2
        await query(
            `INSERT INTO user_love_points (user_id, total_points, last_activity_date)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id) DO UPDATE
       SET total_points = user_love_points.total_points + $2,
           last_activity_date = NOW()`,
            [user2, actualAmount]
        );

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error syncing love points:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});

export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        // 1. Find couple
        const coupleResult = await query(
            `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
            [userId]
        );

        if (coupleResult.rows.length === 0) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }
        const coupleId = coupleResult.rows[0].id;

        // 2. Fetch total points
        const totalResult = await query(
            `SELECT total_points FROM user_love_points WHERE user_id = $1`,
            [userId]
        );
        const total = totalResult.rows.length > 0 ? totalResult.rows[0].total_points : 0;

        // 3. Fetch recent transactions
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
});
