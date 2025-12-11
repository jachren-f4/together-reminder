import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { awardLP, getUserLP } from '@/lib/lp/award';
import { NextResponse } from 'next/server';

export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { amount, reason, relatedId, multiplier } = body;

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

        // 2. Award LP using shared utility (updates couples.total_lp)
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

        // 2. Fetch total points from couples.total_lp (single source of truth)
        const total = await getUserLP(userId);

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
