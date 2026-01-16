/**
 * Subscription Analytics Queries
 */

import { query } from '@/lib/db/pool';

export interface SubscriptionMetrics {
  activeSubscribers: number;
  trialUsers: number;
  cancelled: number;
  expired: number;
  none: number;
  totalCouples: number;
}

export interface SubscriptionByProduct {
  productId: string;
  productName: string;
  count: number;
  percentage: number;
}

export interface SubscriptionTrend {
  date: string;
  newTrials: number;
  conversions: number;
  churned: number;
}

export interface RecentCancellation {
  coupleId: string;
  productId: string | null;
  subscribedAt: string | null;
  expiresAt: string | null;
  durationDays: number | null;
  status: string;
}

/**
 * Get subscription status breakdown
 */
export async function getSubscriptionMetrics(): Promise<SubscriptionMetrics> {
  const result = await query(`
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE subscription_status = 'active') as active,
      COUNT(*) FILTER (WHERE subscription_status = 'trial') as trial,
      COUNT(*) FILTER (WHERE subscription_status = 'cancelled') as cancelled,
      COUNT(*) FILTER (WHERE subscription_status = 'expired') as expired,
      COUNT(*) FILTER (WHERE subscription_status IS NULL OR subscription_status = 'none') as none
    FROM couples
    WHERE brand_id = 'us2' OR brand_id IS NULL
  `);

  return {
    activeSubscribers: parseInt(result.rows[0]?.active || '0'),
    trialUsers: parseInt(result.rows[0]?.trial || '0'),
    cancelled: parseInt(result.rows[0]?.cancelled || '0'),
    expired: parseInt(result.rows[0]?.expired || '0'),
    none: parseInt(result.rows[0]?.none || '0'),
    totalCouples: parseInt(result.rows[0]?.total || '0'),
  };
}

/**
 * Get subscriptions by product
 */
export async function getSubscriptionsByProduct(): Promise<SubscriptionByProduct[]> {
  const result = await query(`
    SELECT
      subscription_product_id as product_id,
      COUNT(*) as count
    FROM couples
    WHERE subscription_status IN ('active', 'trial')
      AND subscription_product_id IS NOT NULL
      AND (brand_id = 'us2' OR brand_id IS NULL)
    GROUP BY subscription_product_id
    ORDER BY count DESC
  `);

  const total = result.rows.reduce((sum, row) => sum + parseInt(row.count || '0'), 0);

  return result.rows.map(row => {
    const count = parseInt(row.count || '0');
    const productId = row.product_id || 'unknown';

    // Map product IDs to friendly names
    let productName = productId;
    if (productId.includes('yearly') || productId.includes('annual')) {
      productName = 'Premium Yearly';
    } else if (productId.includes('monthly')) {
      productName = 'Premium Monthly';
    }

    return {
      productId,
      productName,
      count,
      percentage: total > 0 ? Math.round((count / total) * 1000) / 10 : 0,
    };
  });
}

/**
 * Get subscription trends over time
 */
export async function getSubscriptionTrends(days: number = 30): Promise<SubscriptionTrend[]> {
  // Since we don't have subscription_status_history, we'll estimate from current data
  // This returns a simplified trend based on subscription dates
  const result = await query(`
    WITH dates AS (
      SELECT generate_series(
        CURRENT_DATE - INTERVAL '${days} days',
        CURRENT_DATE,
        INTERVAL '1 day'
      )::date as date
    ),
    daily_trials AS (
      SELECT DATE(subscription_started_at) as date, COUNT(*) as count
      FROM couples
      WHERE subscription_started_at >= CURRENT_DATE - INTERVAL '${days} days'
        AND (brand_id = 'us2' OR brand_id IS NULL)
      GROUP BY DATE(subscription_started_at)
    ),
    daily_conversions AS (
      SELECT DATE(subscription_started_at) as date, COUNT(*) as count
      FROM couples
      WHERE subscription_status = 'active'
        AND subscription_started_at >= CURRENT_DATE - INTERVAL '${days} days'
        AND (brand_id = 'us2' OR brand_id IS NULL)
      GROUP BY DATE(subscription_started_at)
    ),
    daily_churned AS (
      SELECT DATE(subscription_expires_at) as date, COUNT(*) as count
      FROM couples
      WHERE subscription_status IN ('cancelled', 'expired')
        AND subscription_expires_at >= CURRENT_DATE - INTERVAL '${days} days'
        AND subscription_expires_at <= CURRENT_DATE
        AND (brand_id = 'us2' OR brand_id IS NULL)
      GROUP BY DATE(subscription_expires_at)
    )
    SELECT
      d.date::text,
      COALESCE(t.count, 0) as new_trials,
      COALESCE(c.count, 0) as conversions,
      COALESCE(ch.count, 0) as churned
    FROM dates d
    LEFT JOIN daily_trials t ON d.date = t.date
    LEFT JOIN daily_conversions c ON d.date = c.date
    LEFT JOIN daily_churned ch ON d.date = ch.date
    ORDER BY d.date ASC
  `);

  return result.rows.map(row => ({
    date: row.date,
    newTrials: parseInt(row.new_trials || '0'),
    conversions: parseInt(row.conversions || '0'),
    churned: parseInt(row.churned || '0'),
  }));
}

/**
 * Get recent cancellations
 */
export async function getRecentCancellations(limit: number = 10): Promise<RecentCancellation[]> {
  const result = await query(`
    SELECT
      id,
      subscription_product_id,
      subscription_started_at,
      subscription_expires_at,
      subscription_status,
      CASE
        WHEN subscription_started_at IS NOT NULL AND subscription_expires_at IS NOT NULL
        THEN EXTRACT(DAY FROM subscription_expires_at - subscription_started_at)::int
        ELSE NULL
      END as duration_days
    FROM couples
    WHERE subscription_status IN ('cancelled', 'expired', 'refunded')
      AND (brand_id = 'us2' OR brand_id IS NULL)
    ORDER BY subscription_expires_at DESC NULLS LAST
    LIMIT $1
  `, [limit]);

  return result.rows.map(row => ({
    coupleId: `c_${row.id.substring(0, 4)}...${row.id.substring(row.id.length - 4)}`,
    productId: row.subscription_product_id,
    subscribedAt: row.subscription_started_at,
    expiresAt: row.subscription_expires_at,
    durationDays: row.duration_days,
    status: row.subscription_status,
  }));
}

/**
 * Get trial conversion rate
 */
export async function getTrialConversionRate(): Promise<{
  totalTrialsStarted: number;
  converted: number;
  conversionRate: number;
}> {
  const result = await query(`
    SELECT
      COUNT(*) FILTER (WHERE subscription_started_at IS NOT NULL) as total_trials,
      COUNT(*) FILTER (WHERE subscription_status = 'active') as converted
    FROM couples
    WHERE (brand_id = 'us2' OR brand_id IS NULL)
  `);

  const totalTrials = parseInt(result.rows[0]?.total_trials || '0');
  const converted = parseInt(result.rows[0]?.converted || '0');

  return {
    totalTrialsStarted: totalTrials,
    converted,
    conversionRate: totalTrials > 0 ? Math.round((converted / totalTrials) * 1000) / 10 : 0,
  };
}

/**
 * Get estimated revenue
 */
export async function getEstimatedRevenue(): Promise<{
  mrr: number;
  arr: number;
}> {
  // Estimate based on product types
  // Assuming: yearly = $49.99/year, monthly = $7.99/month
  const result = await query(`
    SELECT
      COUNT(*) FILTER (WHERE subscription_product_id LIKE '%yearly%' OR subscription_product_id LIKE '%annual%') as yearly,
      COUNT(*) FILTER (WHERE subscription_product_id LIKE '%monthly%') as monthly
    FROM couples
    WHERE subscription_status = 'active'
      AND (brand_id = 'us2' OR brand_id IS NULL)
  `);

  const yearly = parseInt(result.rows[0]?.yearly || '0');
  const monthly = parseInt(result.rows[0]?.monthly || '0');

  // MRR calculation
  const yearlyMRR = yearly * (49.99 / 12); // Yearly spread across months
  const monthlyMRR = monthly * 7.99;
  const mrr = Math.round((yearlyMRR + monthlyMRR) * 100) / 100;
  const arr = Math.round(mrr * 12 * 100) / 100;

  return { mrr, arr };
}
