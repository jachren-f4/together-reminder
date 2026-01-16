/**
 * Retention API Endpoint
 */

import { NextRequest, NextResponse } from 'next/server';
import { requireAdminAuth } from '@/lib/admin/auth';
import { getRetentionCohorts, getRetentionSummary } from '@/lib/admin/queries/retention';

export async function GET(request: NextRequest) {
  try {
    // Verify admin auth
    await requireAdminAuth();

    // Get query params
    const searchParams = request.nextUrl.searchParams;
    const weeks = parseInt(searchParams.get('weeks') || '8');

    // Fetch all data in parallel
    const [cohorts, summary] = await Promise.all([
      getRetentionCohorts(weeks),
      getRetentionSummary(),
    ]);

    return NextResponse.json({
      cohorts,
      summary,
    });
  } catch (error) {
    console.error('Retention API error:', error);

    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json(
      { error: 'Failed to fetch retention data' },
      { status: 500 }
    );
  }
}
