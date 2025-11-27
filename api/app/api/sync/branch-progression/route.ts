/**
 * Branch Progression API Endpoint
 *
 * Manages per-activity branch progression for branching content system.
 * GET: Fetch branch states for a couple (single or all)
 * POST: Upsert branch state after activity completion
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Valid activity types
const VALID_ACTIVITY_TYPES = ['classicQuiz', 'affirmation', 'youOrMe', 'linked', 'wordSearch'];

/**
 * GET /api/sync/branch-progression
 *
 * Query params:
 * - couple_id (required): UUID of the couple
 * - activity_type (optional): If provided, returns single state; otherwise returns all
 */
async function handleGet(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const coupleId = searchParams.get('couple_id');
  const activityType = searchParams.get('activity_type');

  if (!coupleId) {
    return NextResponse.json(
      { error: 'couple_id is required' },
      { status: 400 }
    );
  }

  try {
    if (activityType) {
      // Return single state
      if (!VALID_ACTIVITY_TYPES.includes(activityType)) {
        return NextResponse.json(
          { error: `Invalid activity_type. Must be one of: ${VALID_ACTIVITY_TYPES.join(', ')}` },
          { status: 400 }
        );
      }

      const result = await query(
        `SELECT couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at
         FROM branch_progression
         WHERE couple_id = $1 AND activity_type = $2`,
        [coupleId, activityType]
      );

      if (result.rows.length === 0) {
        return NextResponse.json({ state: null }, { status: 200 });
      }

      return NextResponse.json({
        state: formatStateForResponse(result.rows[0])
      });
    } else {
      // Return all states for couple
      const result = await query(
        `SELECT couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at
         FROM branch_progression
         WHERE couple_id = $1`,
        [coupleId]
      );

      return NextResponse.json({
        states: result.rows.map(formatStateForResponse)
      });
    }
  } catch (error) {
    console.error('Error fetching branch progression:', error);
    return NextResponse.json(
      { error: 'Failed to fetch branch progression' },
      { status: 500 }
    );
  }
}

/**
 * POST /api/sync/branch-progression
 *
 * Body:
 * - couple_id (required): UUID of the couple
 * - activity_type (required): Activity type
 * - current_branch (required): Current branch index (0, 1, 2)
 * - total_completions (required): Total completions count
 * - max_branches (optional): Max branches (default 3)
 * - last_completed_at (optional): ISO timestamp of last completion
 */
async function handlePost(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      couple_id,
      activity_type,
      current_branch,
      total_completions,
      max_branches = 3,
      last_completed_at,
    } = body;

    // Validation
    if (!couple_id) {
      return NextResponse.json({ error: 'couple_id is required' }, { status: 400 });
    }
    if (!activity_type || !VALID_ACTIVITY_TYPES.includes(activity_type)) {
      return NextResponse.json(
        { error: `Invalid activity_type. Must be one of: ${VALID_ACTIVITY_TYPES.join(', ')}` },
        { status: 400 }
      );
    }
    if (current_branch === undefined || typeof current_branch !== 'number') {
      return NextResponse.json({ error: 'current_branch is required and must be a number' }, { status: 400 });
    }
    if (total_completions === undefined || typeof total_completions !== 'number') {
      return NextResponse.json({ error: 'total_completions is required and must be a number' }, { status: 400 });
    }

    // Upsert branch progression
    const result = await query(
      `INSERT INTO branch_progression (
        couple_id, activity_type, current_branch, total_completions,
        max_branches, last_completed_at
      ) VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (couple_id, activity_type)
      DO UPDATE SET
        current_branch = EXCLUDED.current_branch,
        total_completions = EXCLUDED.total_completions,
        max_branches = EXCLUDED.max_branches,
        last_completed_at = EXCLUDED.last_completed_at,
        updated_at = NOW()
      RETURNING couple_id, activity_type, current_branch, total_completions,
                max_branches, last_completed_at, created_at`,
      [
        couple_id,
        activity_type,
        current_branch,
        total_completions,
        max_branches,
        last_completed_at || null,
      ]
    );

    console.log(`Branch progression updated: ${couple_id} / ${activity_type} -> branch ${current_branch} (${total_completions} completions)`);

    return NextResponse.json({
      success: true,
      state: formatStateForResponse(result.rows[0])
    });
  } catch (error) {
    console.error('Error updating branch progression:', error);
    return NextResponse.json(
      { error: 'Failed to update branch progression' },
      { status: 500 }
    );
  }
}

// Format database row for API response (snake_case)
function formatStateForResponse(row: any) {
  return {
    couple_id: row.couple_id,
    activity_type: row.activity_type,
    current_branch: row.current_branch,
    total_completions: row.total_completions,
    max_branches: row.max_branches,
    last_completed_at: row.last_completed_at?.toISOString() || null,
    created_at: row.created_at?.toISOString() || null,
  };
}

// Export with auth middleware
export const GET = withAuthOrDevBypass(handleGet);
export const POST = withAuthOrDevBypass(handlePost);
