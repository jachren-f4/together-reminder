/**
 * Overview Dashboard Queries
 *
 * Fetches summary metrics for the admin dashboard
 */

import { query } from '@/lib/db/pool';

export interface OverviewMetrics {
  totalUsers: number;
  totalCouples: number;
  dau: number;
  wau: number;
  mau: number;
  activeSubscriptions: number;
  trialUsers: number;
  totalLP: number;
  newUsersToday: number;
  newCouplesToday: number;
}

export interface DailyStats {
  date: string;
  newUsers: number;
  newCouples: number;
  activeUsers: number;
}

export interface PairingStats {
  invitesCreated: number;
  invitesUsed: number;
  conversionRate: number;
}

/**
 * Get all overview metrics for the dashboard
 */
export async function getOverviewMetrics(days: number = 30): Promise<OverviewMetrics> {
  // Run queries in parallel
  const [
    usersResult,
    couplesResult,
    dauResult,
    wauResult,
    mauResult,
    subscriptionsResult,
    lpResult,
    newUsersTodayResult,
    newCouplesTodayResult,
  ] = await Promise.all([
    // Total users
    query(`SELECT COUNT(*) as count FROM auth.users`),

    // Total couples
    query(`SELECT COUNT(*) as count FROM couples WHERE brand_id = 'us2' OR brand_id IS NULL`),

    // DAU - couples with activity in last 24 hours
    query(`
      SELECT COUNT(DISTINCT couple_id) as count FROM (
        SELECT dq.couple_id FROM quest_completions qc
        JOIN daily_quests dq ON qc.quest_id = dq.id
        WHERE qc.completed_at >= NOW() - INTERVAL '1 day'
        UNION
        SELECT couple_id FROM quiz_sessions WHERE created_at >= NOW() - INTERVAL '1 day'
        UNION
        SELECT couple_id FROM linked_matches WHERE created_at >= NOW() - INTERVAL '1 day'
        UNION
        SELECT couple_id FROM word_search_matches WHERE created_at >= NOW() - INTERVAL '1 day'
      ) active_couples
    `),

    // WAU - couples with activity in last 7 days
    query(`
      SELECT COUNT(DISTINCT couple_id) as count FROM (
        SELECT dq.couple_id FROM quest_completions qc
        JOIN daily_quests dq ON qc.quest_id = dq.id
        WHERE qc.completed_at >= NOW() - INTERVAL '7 days'
        UNION
        SELECT couple_id FROM quiz_sessions WHERE created_at >= NOW() - INTERVAL '7 days'
        UNION
        SELECT couple_id FROM linked_matches WHERE created_at >= NOW() - INTERVAL '7 days'
        UNION
        SELECT couple_id FROM word_search_matches WHERE created_at >= NOW() - INTERVAL '7 days'
      ) active_couples
    `),

    // MAU - couples with activity in last 30 days
    query(`
      SELECT COUNT(DISTINCT couple_id) as count FROM (
        SELECT dq.couple_id FROM quest_completions qc
        JOIN daily_quests dq ON qc.quest_id = dq.id
        WHERE qc.completed_at >= NOW() - INTERVAL '30 days'
        UNION
        SELECT couple_id FROM quiz_sessions WHERE created_at >= NOW() - INTERVAL '30 days'
        UNION
        SELECT couple_id FROM linked_matches WHERE created_at >= NOW() - INTERVAL '30 days'
        UNION
        SELECT couple_id FROM word_search_matches WHERE created_at >= NOW() - INTERVAL '30 days'
      ) active_couples
    `),

    // Active subscriptions and trial users
    query(`
      SELECT
        COUNT(*) FILTER (WHERE subscription_status = 'active') as active,
        COUNT(*) FILTER (WHERE subscription_status = 'trial') as trial
      FROM couples
      WHERE brand_id = 'us2' OR brand_id IS NULL
    `),

    // Total LP
    query(`
      SELECT COALESCE(SUM(total_lp), 0) as total
      FROM couples
      WHERE brand_id = 'us2' OR brand_id IS NULL
    `),

    // New users today
    query(`SELECT COUNT(*) as count FROM auth.users WHERE created_at >= CURRENT_DATE`),

    // New couples today
    query(`
      SELECT COUNT(*) as count FROM couples
      WHERE created_at >= CURRENT_DATE AND (brand_id = 'us2' OR brand_id IS NULL)
    `),
  ]);

  return {
    totalUsers: parseInt(usersResult.rows[0]?.count || '0'),
    totalCouples: parseInt(couplesResult.rows[0]?.count || '0'),
    dau: parseInt(dauResult.rows[0]?.count || '0'),
    wau: parseInt(wauResult.rows[0]?.count || '0'),
    mau: parseInt(mauResult.rows[0]?.count || '0'),
    activeSubscriptions: parseInt(subscriptionsResult.rows[0]?.active || '0'),
    trialUsers: parseInt(subscriptionsResult.rows[0]?.trial || '0'),
    totalLP: parseInt(lpResult.rows[0]?.total || '0'),
    newUsersToday: parseInt(newUsersTodayResult.rows[0]?.count || '0'),
    newCouplesToday: parseInt(newCouplesTodayResult.rows[0]?.count || '0'),
  };
}

/**
 * Get daily stats for charts
 */
export async function getDailyStats(days: number = 30): Promise<DailyStats[]> {
  const result = await query(`
    WITH dates AS (
      SELECT generate_series(
        CURRENT_DATE - INTERVAL '${days} days',
        CURRENT_DATE,
        INTERVAL '1 day'
      )::date as date
    ),
    daily_users AS (
      SELECT DATE(created_at) as date, COUNT(*) as count
      FROM auth.users
      WHERE created_at >= CURRENT_DATE - INTERVAL '${days} days'
      GROUP BY DATE(created_at)
    ),
    daily_couples AS (
      SELECT DATE(created_at) as date, COUNT(*) as count
      FROM couples
      WHERE created_at >= CURRENT_DATE - INTERVAL '${days} days'
        AND (brand_id = 'us2' OR brand_id IS NULL)
      GROUP BY DATE(created_at)
    ),
    daily_active AS (
      SELECT activity_date as date, COUNT(DISTINCT couple_id) as count
      FROM (
        SELECT dq.couple_id, DATE(qc.completed_at) as activity_date
        FROM quest_completions qc
        JOIN daily_quests dq ON qc.quest_id = dq.id
        WHERE qc.completed_at >= CURRENT_DATE - INTERVAL '${days} days'
        UNION
        SELECT couple_id, DATE(created_at) FROM quiz_sessions
        WHERE created_at >= CURRENT_DATE - INTERVAL '${days} days'
        UNION
        SELECT couple_id, DATE(created_at) FROM linked_matches
        WHERE created_at >= CURRENT_DATE - INTERVAL '${days} days'
        UNION
        SELECT couple_id, DATE(created_at) FROM word_search_matches
        WHERE created_at >= CURRENT_DATE - INTERVAL '${days} days'
      ) activity
      GROUP BY activity_date
    )
    SELECT
      d.date::text,
      COALESCE(u.count, 0) as new_users,
      COALESCE(c.count, 0) as new_couples,
      COALESCE(a.count, 0) as active_users
    FROM dates d
    LEFT JOIN daily_users u ON d.date = u.date
    LEFT JOIN daily_couples c ON d.date = c.date
    LEFT JOIN daily_active a ON d.date = a.date
    ORDER BY d.date ASC
  `);

  return result.rows.map(row => ({
    date: row.date,
    newUsers: parseInt(row.new_users || '0'),
    newCouples: parseInt(row.new_couples || '0'),
    activeUsers: parseInt(row.active_users || '0'),
  }));
}

/**
 * Get pairing conversion stats
 *
 * Since couples are created when both users are paired, we count:
 * - Total couples (as "invites created" - user1 initiated)
 * - Couples with user2_id set (as "invites used" - user2 joined)
 */
export async function getPairingStats(): Promise<PairingStats> {
  const result = await query(`
    SELECT
      COUNT(*) as total_couples,
      COUNT(*) FILTER (WHERE user2_id IS NOT NULL) as paired_couples
    FROM couples
    WHERE brand_id = 'us2' OR brand_id IS NULL
  `);

  const totalCouples = parseInt(result.rows[0]?.total_couples || '0');
  const pairedCouples = parseInt(result.rows[0]?.paired_couples || '0');
  const conversionRate = totalCouples > 0
    ? Math.round((pairedCouples / totalCouples) * 1000) / 10
    : 0;

  return {
    invitesCreated: totalCouples,
    invitesUsed: pairedCouples,
    conversionRate,
  };
}
