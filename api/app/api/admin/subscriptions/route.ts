/**
 * Subscriptions API Endpoint
 */

import { NextRequest, NextResponse } from 'next/server';
import { requireAdminAuth } from '@/lib/admin/auth';
import {
  getSubscriptionMetrics,
  getSubscriptionsByProduct,
  getSubscriptionTrends,
  getRecentCancellations,
  getTrialConversionRate,
  getEstimatedRevenue,
} from '@/lib/admin/queries/subscriptions';

export async function GET(request: NextRequest) {
  try {
    // Verify admin auth
    await requireAdminAuth();

    // Get query params
    const searchParams = request.nextUrl.searchParams;
    const range = parseInt(searchParams.get('range') || '30');

    // Fetch all data in parallel
    const [
      metrics,
      byProduct,
      trends,
      cancellations,
      conversionRate,
      revenue,
    ] = await Promise.all([
      getSubscriptionMetrics(),
      getSubscriptionsByProduct(),
      getSubscriptionTrends(range),
      getRecentCancellations(10),
      getTrialConversionRate(),
      getEstimatedRevenue(),
    ]);

    return NextResponse.json({
      metrics,
      byProduct,
      trends,
      cancellations,
      conversionRate,
      revenue,
    });
  } catch (error) {
    console.error('Subscriptions API error:', error);

    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json(
      { error: 'Failed to fetch subscription data' },
      { status: 500 }
    );
  }
}
