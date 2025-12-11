import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleId } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';

export const POST = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { quests, dateKey } = body;

        if (!quests || !Array.isArray(quests) || !dateKey) {
            return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
        }

        // Find couple
        const coupleId = await getCoupleId(userId);
        if (!coupleId) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        // Insert quests within transaction
        await withTransaction(async (client) => {
            for (const quest of quests) {
                // Use DO NOTHING to preserve first-written quests (idempotent)
                // This prevents race conditions when both devices try to upload
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
});

// PATCH: Update content_id for a daily quest (used when session ID changes after server sync)
export const PATCH = withAuthOrDevBypass(async (req, userId) => {
    try {
        const body = await req.json();
        const { questId, contentId } = body;

        if (!questId || !contentId) {
            return NextResponse.json({ error: 'Missing questId or contentId' }, { status: 400 });
        }

        // Find couple
        const coupleId = await getCoupleId(userId);
        if (!coupleId) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        // Update content_id for the specific quest
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
});

export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        const { searchParams } = new URL(req.url);
        const date = searchParams.get('date');

        if (!date) {
            return NextResponse.json({ error: 'Missing date parameter' }, { status: 400 });
        }

        // Find couple
        const coupleId = await getCoupleId(userId);
        if (!coupleId) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        // Fetch quests
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
