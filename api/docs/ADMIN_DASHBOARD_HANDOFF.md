# Admin Dashboard Handoff Document

## Current Status: DEBUGGING NEEDED

The admin dashboard has been implemented but there are styling/display issues that need to be debugged using Chrome browser tools.

## What Was Built

A full analytics dashboard at `/admin` routes with:

### Pages
- `/admin/login` - Email allowlist login
- `/admin` - Overview dashboard (metrics, charts)
- `/admin/retention` - Cohort retention analysis
- `/admin/subscriptions` - Subscription analytics

### Key Files

**Authentication:**
- `lib/admin/auth.ts` - JWT session management with email allowlist
- `app/api/admin/auth/route.ts` - Login/logout/validate API

**API Routes:**
- `app/api/admin/overview/route.ts` - Overview metrics API
- `app/api/admin/retention/route.ts` - Retention cohorts API
- `app/api/admin/subscriptions/route.ts` - Subscription data API

**Query Layer:**
- `lib/admin/queries/overview.ts` - DAU/WAU/MAU, daily stats, pairing stats
- `lib/admin/queries/retention.ts` - Weekly cohort retention (D1/D7/D30)
- `lib/admin/queries/subscriptions.ts` - Subscription metrics, trends, cancellations

**UI Components:**
- `app/admin/components/AdminShell.tsx` - Auth wrapper + layout (Server Component)
- `app/admin/components/AdminNav.tsx` - Sidebar navigation
- `app/admin/components/OverviewContent.tsx` - Overview page content (Client Component)
- `app/admin/components/RetentionContent.tsx` - Retention page content (Client Component)
- `app/admin/components/SubscriptionsContent.tsx` - Subscriptions page content (Client Component)
- `app/admin/components/Chart.tsx` - Recharts wrapper (LineChart, DonutChart)
- `app/admin/components/TimeRangePicker.tsx` - 1D/7D/30D/90D selector

**Config:**
- `app/globals.css` - Tailwind v4 import (`@import "tailwindcss";`)
- `tailwind.config.ts` - Tailwind configuration
- `postcss.config.mjs` - PostCSS with `@tailwindcss/postcss`

## Environment Variables

In `.env.local`:
```
ADMIN_EMAILS=joakim.achren@gmail.com
ADMIN_SESSION_SECRET=99fd6bd90b4a920592fdce17bd4ff142fe25f241ed70cfa08cc08a49f21fb29c
```

## The Problem

When viewing `/admin/login` in Chrome, the page was displaying incorrectly (showing giant Next.js "N" logo instead of the login form). Several fixes were applied:

1. **Tailwind v4 syntax** - Changed from `@tailwind base/components/utilities` to `@import "tailwindcss";`
2. **Server/Client component separation** - Pages are now Server Components that wrap Client Components (to avoid `next/headers` import issues)

## Current State

- Dev server should be running: `npm run dev` (from `/api` directory)
- APIs are working (tested with curl)
- Login page returns 200 status but visual display needs verification

## Debug Task

Use Chrome browser tools to:

1. Navigate to `http://localhost:3000/admin/login`
2. Check if the login form displays correctly (purple gradient background, white card, email input, Sign In button)
3. If broken, check browser console for errors
4. Test login with `joakim.achren@gmail.com`
5. Verify the overview dashboard loads with real data

## How to Start Dev Server

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npm run dev
```

Server runs at http://localhost:3000

## API Test Commands

```bash
# Login and get session cookie
curl -s -X POST http://localhost:3000/api/admin/auth \
  -H "Content-Type: application/json" \
  -d '{"email":"joakim.achren@gmail.com"}' \
  -c /tmp/admin_cookies.txt

# Test overview API
curl -s "http://localhost:3000/api/admin/overview?range=30" -b /tmp/admin_cookies.txt

# Test retention API
curl -s "http://localhost:3000/api/admin/retention?weeks=8" -b /tmp/admin_cookies.txt

# Test subscriptions API
curl -s "http://localhost:3000/api/admin/subscriptions?range=30" -b /tmp/admin_cookies.txt
```

## Tech Stack

- Next.js 16 with Turbopack
- Tailwind CSS v4 (with `@tailwindcss/postcss`)
- Recharts for charts
- JWT-based sessions with httpOnly cookies
- PostgreSQL (Supabase) via `lib/db/pool.ts`
