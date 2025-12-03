import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

/**
 * GET /api/sync/couple-stats
 * Fetch couple statistics for the profile page:
 * - Anniversary date
 * - Activities completed per user
 * - Current streak days per user
 * - Couple games won per user
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
    try {
        // 1. Find couple and get basic info
        const coupleResult = await query(
            `SELECT
                c.id as couple_id,
                c.user1_id,
                c.user2_id,
                c.anniversary_date,
                u1.raw_user_meta_data->>'full_name' as user1_name,
                u2.raw_user_meta_data->>'full_name' as user2_name
             FROM couples c
             LEFT JOIN auth.users u1 ON c.user1_id = u1.id
             LEFT JOIN auth.users u2 ON c.user2_id = u2.id
             WHERE c.user1_id = $1 OR c.user2_id = $1`,
            [userId]
        );

        if (coupleResult.rows.length === 0) {
            return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
        }

        const couple = coupleResult.rows[0];
        const coupleId = couple.couple_id;
        const user1Id = couple.user1_id;
        const user2Id = couple.user2_id;

        // 2. Get activities completed per user (from quest_completions)
        const activitiesResult = await query(
            `SELECT
                user_id,
                COUNT(*) as count
             FROM quest_completions qc
             JOIN daily_quests dq ON qc.quest_id = dq.id
             WHERE dq.couple_id = $1
             GROUP BY user_id`,
            [coupleId]
        );

        const activitiesByUser: Record<string, number> = {};
        for (const row of activitiesResult.rows) {
            activitiesByUser[row.user_id] = parseInt(row.count);
        }

        // 3. Get current streak per user
        // Streak = consecutive days with at least one quest completion
        const streakUser1 = await calculateStreak(coupleId, user1Id);
        const streakUser2 = await calculateStreak(coupleId, user2Id);

        // 4. Get couple games won per user
        // A "win" is when a user has more correct answers than partner in a completed quiz session
        const gamesWonResult = await query(
            `WITH quiz_scores AS (
                SELECT
                    qs.id as session_id,
                    qa.user_id,
                    COUNT(CASE WHEN qa.is_correct THEN 1 END) as correct_count
                FROM quiz_sessions qs
                JOIN quiz_answers qa ON qs.id = qa.session_id
                WHERE qs.couple_id = $1 AND qs.completed_at IS NOT NULL
                GROUP BY qs.id, qa.user_id
            ),
            session_winners AS (
                SELECT
                    s1.session_id,
                    CASE
                        WHEN s1.correct_count > s2.correct_count THEN s1.user_id
                        WHEN s2.correct_count > s1.correct_count THEN s2.user_id
                        ELSE NULL -- tie
                    END as winner_id
                FROM quiz_scores s1
                JOIN quiz_scores s2 ON s1.session_id = s2.session_id AND s1.user_id != s2.user_id
                WHERE s1.user_id = $2
            )
            SELECT winner_id, COUNT(*) as wins
            FROM session_winners
            WHERE winner_id IS NOT NULL
            GROUP BY winner_id`,
            [coupleId, user1Id]
        );

        const gameWinsByUser: Record<string, number> = {};
        for (const row of gamesWonResult.rows) {
            gameWinsByUser[row.winner_id] = parseInt(row.wins);
        }

        // 5. Build response
        const user1Name = couple.user1_name || 'Partner 1';
        const user2Name = couple.user2_name || 'Partner 2';

        return NextResponse.json({
            anniversaryDate: couple.anniversary_date
                ? couple.anniversary_date.toISOString().split('T')[0]
                : null,
            user1: {
                id: user1Id,
                name: user1Name,
                initial: user1Name.charAt(0).toUpperCase(),
                activitiesCompleted: activitiesByUser[user1Id] || 0,
                currentStreakDays: streakUser1,
                coupleGamesWon: gameWinsByUser[user1Id] || 0
            },
            user2: {
                id: user2Id,
                name: user2Name,
                initial: user2Name.charAt(0).toUpperCase(),
                activitiesCompleted: activitiesByUser[user2Id] || 0,
                currentStreakDays: streakUser2,
                coupleGamesWon: gameWinsByUser[user2Id] || 0
            },
            // Include which user is the current requester
            currentUserId: userId
        });
    } catch (error) {
        console.error('Error fetching couple stats:', error);
        return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
    }
});

/**
 * Calculate current streak for a user
 * Streak = consecutive days (ending today or yesterday) with at least one completion
 */
async function calculateStreak(coupleId: string, userId: string): Promise<number> {
    try {
        const result = await query(
            `WITH completion_dates AS (
                SELECT DISTINCT DATE(qc.completed_at) as completion_date
                FROM quest_completions qc
                JOIN daily_quests dq ON qc.quest_id = dq.id
                WHERE dq.couple_id = $1 AND qc.user_id = $2
                ORDER BY completion_date DESC
            ),
            streak_calc AS (
                SELECT
                    completion_date,
                    completion_date - (ROW_NUMBER() OVER (ORDER BY completion_date DESC))::int as streak_group
                FROM completion_dates
                WHERE completion_date >= CURRENT_DATE - INTERVAL '1 day'
                   OR completion_date = CURRENT_DATE
            )
            SELECT COUNT(*) as streak
            FROM streak_calc
            WHERE streak_group = (
                SELECT streak_group FROM streak_calc LIMIT 1
            )`,
            [coupleId, userId]
        );

        return parseInt(result.rows[0]?.streak || '0');
    } catch (error) {
        console.error('Error calculating streak:', error);
        return 0;
    }
}
