/**
 * Retention Analytics Queries
 *
 * Calculates cohort retention metrics
 */

import { query } from '@/lib/db/pool';

export interface CohortData {
  cohortWeek: string;
  cohortLabel: string;
  size: number;
  d1: number | null;
  d7: number | null;
  d30: number | null;
}

/**
 * Get weekly cohort retention data
 */
export async function getRetentionCohorts(weeks: number = 8): Promise<CohortData[]> {
  const result = await query(`
    WITH cohorts AS (
      SELECT
        DATE_TRUNC('week', created_at)::date as cohort_week,
        id as couple_id,
        created_at
      FROM couples
      WHERE created_at >= NOW() - INTERVAL '${weeks} weeks'
        AND (brand_id = 'us2' OR brand_id IS NULL)
    ),
    all_activity AS (
      SELECT dq.couple_id, DATE(qc.completed_at) as activity_date
      FROM quest_completions qc
      JOIN daily_quests dq ON qc.quest_id = dq.id
      UNION
      SELECT couple_id, DATE(created_at) FROM quiz_sessions
      UNION
      SELECT couple_id, DATE(created_at) FROM linked_matches
      UNION
      SELECT couple_id, DATE(created_at) FROM word_search_matches
    ),
    cohort_retention AS (
      SELECT
        c.cohort_week,
        c.couple_id,
        c.created_at,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 1 THEN 1 ELSE 0 END) as retained_d1,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 7 THEN 1 ELSE 0 END) as retained_d7,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 30 THEN 1 ELSE 0 END) as retained_d30
      FROM cohorts c
      LEFT JOIN all_activity a ON c.couple_id = a.couple_id
      GROUP BY c.cohort_week, c.couple_id, c.created_at
    )
    SELECT
      cohort_week::text,
      COUNT(*) as size,
      ROUND(AVG(retained_d1) * 100, 1) as d1,
      CASE
        WHEN cohort_week <= CURRENT_DATE - INTERVAL '7 days'
        THEN ROUND(AVG(retained_d7) * 100, 1)
        ELSE NULL
      END as d7,
      CASE
        WHEN cohort_week <= CURRENT_DATE - INTERVAL '30 days'
        THEN ROUND(AVG(retained_d30) * 100, 1)
        ELSE NULL
      END as d30
    FROM cohort_retention
    GROUP BY cohort_week
    ORDER BY cohort_week DESC
  `);

  return result.rows.map(row => {
    const cohortDate = new Date(row.cohort_week);
    const endDate = new Date(cohortDate);
    endDate.setDate(endDate.getDate() + 6);

    const formatDate = (d: Date) => {
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    };

    return {
      cohortWeek: row.cohort_week,
      cohortLabel: `${formatDate(cohortDate)} - ${formatDate(endDate)}`,
      size: parseInt(row.size || '0'),
      d1: row.d1 !== null ? parseFloat(row.d1) : null,
      d7: row.d7 !== null ? parseFloat(row.d7) : null,
      d30: row.d30 !== null ? parseFloat(row.d30) : null,
    };
  });
}

/**
 * Get overall retention summary
 */
export async function getRetentionSummary(): Promise<{
  avgD1: number;
  avgD7: number;
  avgD30: number;
  totalCohortSize: number;
}> {
  const result = await query(`
    WITH cohorts AS (
      SELECT
        DATE_TRUNC('week', created_at)::date as cohort_week,
        id as couple_id,
        created_at
      FROM couples
      WHERE created_at >= NOW() - INTERVAL '8 weeks'
        AND created_at <= NOW() - INTERVAL '30 days'
        AND (brand_id = 'us2' OR brand_id IS NULL)
    ),
    all_activity AS (
      SELECT dq.couple_id, DATE(qc.completed_at) as activity_date
      FROM quest_completions qc
      JOIN daily_quests dq ON qc.quest_id = dq.id
      UNION
      SELECT couple_id, DATE(created_at) FROM quiz_sessions
      UNION
      SELECT couple_id, DATE(created_at) FROM linked_matches
      UNION
      SELECT couple_id, DATE(created_at) FROM word_search_matches
    ),
    cohort_retention AS (
      SELECT
        c.couple_id,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 1 THEN 1 ELSE 0 END) as retained_d1,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 7 THEN 1 ELSE 0 END) as retained_d7,
        MAX(CASE WHEN a.activity_date = DATE(c.created_at) + 30 THEN 1 ELSE 0 END) as retained_d30
      FROM cohorts c
      LEFT JOIN all_activity a ON c.couple_id = a.couple_id
      GROUP BY c.couple_id
    )
    SELECT
      COUNT(*) as total,
      ROUND(AVG(retained_d1) * 100, 1) as avg_d1,
      ROUND(AVG(retained_d7) * 100, 1) as avg_d7,
      ROUND(AVG(retained_d30) * 100, 1) as avg_d30
    FROM cohort_retention
  `);

  return {
    totalCohortSize: parseInt(result.rows[0]?.total || '0'),
    avgD1: parseFloat(result.rows[0]?.avg_d1 || '0'),
    avgD7: parseFloat(result.rows[0]?.avg_d7 || '0'),
    avgD30: parseFloat(result.rows[0]?.avg_d30 || '0'),
  };
}
