import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { quests, dateKey } = body;

        if (!quests || !Array.isArray(quests) || !dateKey) {
            return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
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

        // 2. Insert quests
        const client = await import('@/lib/db/pool').then(m => m.getClient());
        try {
            await client.query('BEGIN');

            for (const quest of quests) {
                await client.query(
                    `INSERT INTO daily_quests (
             id, couple_id, date, quest_type, content_id, sort_order, is_side_quest, metadata, expires_at
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (couple_id, date, quest_type, sort_order)
           DO UPDATE SET
             id = EXCLUDED.id,
             content_id = EXCLUDED.content_id,
             is_side_quest = EXCLUDED.is_side_quest,
             metadata = EXCLUDED.metadata,
             expires_at = EXCLUDED.expires_at,
             generated_at = NOW()`,
                    [
                        quest.id,
                        coupleId,
                        dateKey,
                        quest.questType, // Expecting string (e.g. 'quiz')
                        quest.contentId, // Expecting UUID
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

            await client.query('COMMIT');
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error syncing quests:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});

export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        const { searchParams } = new URL(req.url);
        const date = searchParams.get('date');

        if (!date) {
            return NextResponse.json({ error: 'Missing date parameter' }, { status: 400 });
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

        // 2. Fetch quests
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
});
