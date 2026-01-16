/**
 * Overview API Endpoint
 */

import { NextRequest, NextResponse } from 'next/server';
import { requireAdminAuth } from '@/lib/admin/auth';
import { getOverviewMetrics, getDailyStats, getPairingStats } from '@/lib/admin/queries/overview';

export async function GET(request: NextRequest) {
  try {
    // Verify admin auth
    await requireAdminAuth();

    // Get query params
    const searchParams = request.nextUrl.searchParams;
    const range = parseInt(searchParams.get('range') || '30');

    // Fetch all data in parallel
    const [metrics, dailyStats, pairingStats] = await Promise.all([
      getOverviewMetrics(range),
      getDailyStats(range),
      getPairingStats(),
    ]);

    return NextResponse.json({
      metrics,
      dailyStats,
      pairingStats,
    });
  } catch (error) {
    console.error('Overview API error:', error);

    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json(
      { error: 'Failed to fetch overview data' },
      { status: 500 }
    );
  }
}
