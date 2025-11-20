import { withAuth } from '@/lib/auth/middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

export const POST = withAuth(async (req, userId) => {
    try {
        const body = await req.json();
        const {
            id,
            questionIds,
            createdAt,
            expiresAt,
            status,
            initiatedBy,
            subjectUserId,
            formatType,
            isDailyQuest,
            dailyQuestId,
            answers,
            predictions,
            matchPercentage,
            lpEarned,
            completedAt,
            alignmentMatches,
            predictionScores,
            quizName,
            category
        } = body;

        if (!id || !initiatedBy) {
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

        // 2. Upsert Quiz Session
        // We use ON CONFLICT DO UPDATE to handle updates (e.g., status change, answers added)

        const client = await import('@/lib/db/pool').then(m => m.getClient());
        try {
            await client.query('BEGIN');

            // Upsert session
            await client.query(
                `INSERT INTO quiz_sessions (
           id, couple_id, created_by, format_type, category, status, questions, 
           quiz_name, is_daily_quest, created_at, expires_at, completed_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (id) DO UPDATE SET
           status = EXCLUDED.status,
           completed_at = EXCLUDED.completed_at,
           questions = EXCLUDED.questions -- In case questions were updated (rare)
        `,
                [
                    id,
                    coupleId,
                    userId, // Use authenticated Supabase user ID from JWT
                    formatType,
                    category,
                    status,
                    JSON.stringify(questionIds), // Storing IDs as JSON array for now
                    quizName,
                    isDailyQuest,
                    new Date(createdAt).toISOString(),
                    new Date(expiresAt).toISOString(),
                    completedAt ? new Date(completedAt).toISOString() : null
                ]
            );

            // Upsert Answers
            if (answers) {
                for (const [uid, userAnswers] of Object.entries(answers)) {
                    // userAnswers is List<int> (indices)
                    // We need to map these to question IDs if possible, but for now we'll store raw indices
                    // The schema expects (session_id, user_id, question_id) uniqueness
                    // But here we receive a map of userId -> [indices]

                    // Since the schema is normalized (one row per answer), but the input is denormalized...
                    // For Phase 2 dual-write, it might be safer/easier to store answers as a JSON blob 
                    // in a separate table or column if we want to avoid complex mapping logic here.

                    // However, let's try to respect the schema.
                    // We need the question IDs. `questionIds` is passed in the body.

                    const qIds = questionIds as string[];
                    const ansIndices = userAnswers as number[];

                    for (let i = 0; i < ansIndices.length; i++) {
                        if (i < qIds.length) {
                            await client.query(
                                `INSERT INTO quiz_answers (
                    session_id, user_id, question_id, selected_index, is_correct, answered_at
                  ) VALUES ($1, $2, $3, $4, $5, NOW())
                  ON CONFLICT (session_id, user_id, question_id) DO UPDATE SET
                    selected_index = EXCLUDED.selected_index
                 `,
                                [
                                    id,
                                    uid,
                                    qIds[i],
                                    ansIndices[i],
                                    false // is_correct logic is complex, defaulting to false for now
                                ]
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
});

export const GET = withAuth(async (req, userId) => {
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

        // 2. Fetch sessions
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
});
