/**
 * UNIFIED API CATCH-ALL ROUTE
 *
 * This single route.ts file handles ALL API endpoints to minimize Vercel serverless functions.
 * Vercel Hobby plan limit: 12 functions. With Next.js 16 RSC, each route.ts creates 2 functions.
 * This consolidation ensures we stay under the limit (1 route = 2 functions total).
 *
 * Routes are delegated to domain-specific handlers based on the first path segment:
 * - /api/auth/*      → Auth handlers (verify)
 * - /api/couples/*   → Couples handlers (invite, join, pair-direct, status)
 * - /api/dev/*       → Dev handlers (user-data, reset-games, complete-games, etc.)
 * - /api/health      → Health check
 * - /api/leaderboard → Leaderboard
 * - /api/metrics     → Metrics
 * - /api/puzzles/*   → Puzzle images
 * - /api/sync/*      → Sync handlers (quests, LP, steps, games, etc.)
 * - /api/user/*      → User handlers (profile, name, country, push-token)
 */

import { NextRequest, NextResponse } from 'next/server';

// Domain handlers - sync routes
import {
  routeSyncGET,
  routeSyncPOST,
  routeSyncPATCH,
  routeSyncDELETE,
} from '@/lib/handlers/sync-router';

// Domain handlers - other routes
import {
  routeAuthGET,
} from '@/lib/handlers/auth-router';

import {
  routeCouplesGET,
  routeCouplesPOST,
  routeCouplesDELETE,
} from '@/lib/handlers/couples-router';

import {
  routeDevGET,
  routeDevPOST,
} from '@/lib/handlers/dev-router';

import {
  handleHealthGET,
} from '@/lib/handlers/health-handler';

import {
  handleLeaderboardGET,
} from '@/lib/handlers/leaderboard-handler';

import {
  handleMetricsGET,
} from '@/lib/handlers/metrics-handler';

import {
  routePuzzlesGET,
} from '@/lib/handlers/puzzles-router';

import {
  routeUserGET,
  routeUserPOST,
  routeUserPATCH,
} from '@/lib/handlers/user-router';

export const dynamic = 'force-dynamic';

// ============================================================================
// CORS Handler
// ============================================================================

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

// ============================================================================
// GET Handler
// ============================================================================

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const domain = slug[0] || '';
  const subPath = slug.slice(1);

  switch (domain) {
    case 'auth':
      return routeAuthGET(req, subPath);
    case 'couples':
      return routeCouplesGET(req, subPath);
    case 'dev':
      return routeDevGET(req, subPath);
    case 'health':
      return handleHealthGET(req);
    case 'leaderboard':
      return handleLeaderboardGET(req);
    case 'metrics':
      return handleMetricsGET(req);
    case 'puzzles':
      return routePuzzlesGET(req, subPath);
    case 'sync':
      return routeSyncGET(req, subPath);
    case 'user':
      return routeUserGET(req, subPath);
    default:
      return NextResponse.json(
        { error: `Unknown API route: /api/${slug.join('/')}` },
        { status: 404 }
      );
  }
}

// ============================================================================
// POST Handler
// ============================================================================

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const domain = slug[0] || '';
  const subPath = slug.slice(1);

  switch (domain) {
    case 'couples':
      return routeCouplesPOST(req, subPath);
    case 'dev':
      return routeDevPOST(req, subPath);
    case 'sync':
      return routeSyncPOST(req, subPath);
    case 'user':
      return routeUserPOST(req, subPath);
    default:
      return NextResponse.json(
        { error: `Unknown API route: POST /api/${slug.join('/')}` },
        { status: 404 }
      );
  }
}

// ============================================================================
// PATCH Handler
// ============================================================================

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const domain = slug[0] || '';
  const subPath = slug.slice(1);

  switch (domain) {
    case 'sync':
      return routeSyncPATCH(req, subPath);
    case 'user':
      return routeUserPATCH(req, subPath);
    default:
      return NextResponse.json(
        { error: `Unknown API route: PATCH /api/${slug.join('/')}` },
        { status: 404 }
      );
  }
}

// ============================================================================
// DELETE Handler
// ============================================================================

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const domain = slug[0] || '';
  const subPath = slug.slice(1);

  switch (domain) {
    case 'couples':
      return routeCouplesDELETE(req, subPath);
    case 'sync':
      return routeSyncDELETE(req, subPath);
    default:
      return NextResponse.json(
        { error: `Unknown API route: DELETE /api/${slug.join('/')}` },
        { status: 404 }
      );
  }
}
