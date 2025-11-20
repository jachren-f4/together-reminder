import { withAuth } from '@/lib/auth/middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

export const POST = withAuth(async (req, userId) => {
    try {
        const body = await req.json();
        const { quest_id, timestamp } = body;

        if (!quest_id) {
            return NextResponse.json({ error: 'Missing quest_id' }, { status: 400 });
        }

        // Insert into quest_completions
        // We use ON CONFLICT DO NOTHING to handle idempotency
        await query(
            `INSERT INTO quest_completions (quest_id, user_id, completed_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (quest_id, user_id) DO NOTHING`,
            [
                quest_id,
                userId,
                timestamp || new Date().toISOString()
            ]
        );

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error syncing quest completion:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});
