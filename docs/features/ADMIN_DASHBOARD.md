# Admin Dashboard

## Overview

The Admin Dashboard provides analytics and metrics for monitoring Us 2.0 app performance. It's a web-based dashboard built with Next.js, accessible to authorized administrators via email allowlist authentication.

**URL:** `https://api-joakim-achrens-projects.vercel.app/admin`

## Authentication

### How It Works

1. User enters their email on the login page (`/admin/login`)
2. Server checks if email is in the `ADMIN_EMAILS` allowlist (environment variable)
3. If authorized, a JWT session token is created and stored in an httpOnly cookie
4. Session expires after 7 days

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ADMIN_EMAILS` | Comma-separated list of authorized emails | `admin@example.com,team@example.com` |
| `ADMIN_SESSION_SECRET` | JWT signing secret (min 32 chars) | `your-secure-secret-at-least-32-chars` |

### Adding New Admin Users

Add email to `ADMIN_EMAILS` in Vercel environment variables:

```bash
vercel env add ADMIN_EMAILS
# Enter: existing@email.com,new@email.com
```

Or via Vercel Dashboard → Project → Settings → Environment Variables.

## Dashboard Pages

### Overview (`/admin`)

Main dashboard showing key metrics and daily trends.

**Metrics Displayed:**
| Metric | Description |
|--------|-------------|
| Total Users | Count of all registered users |
| Total Couples | Count of paired couples (Us 2.0 brand) |
| DAU | Daily Active Users (couples with activity in last 24h) |
| WAU | Weekly Active Users (last 7 days) |
| MAU | Monthly Active Users (last 30 days) |
| Active Subscriptions | Couples with `subscription_status = 'active'` |
| Trial Users | Couples with `subscription_status = 'trial'` |
| Total LP | Sum of all Love Points across couples |
| New Users Today | Users created since midnight |
| New Couples Today | Couples created since midnight |

**Charts:**
- Daily new users/couples trend (configurable range: 7/30/90 days)
- Daily active users trend

**Pairing Stats:**
- Invites created (total couples)
- Invites used (couples with user2_id)
- Conversion rate (paired / total)

### Retention (`/admin/retention`)

Cohort-based retention analysis.

**Metrics:**
| Metric | Description |
|--------|-------------|
| D1 Retention | % of couples active 1 day after signup |
| D7 Retention | % of couples active 7 days after signup |
| D30 Retention | % of couples active 30 days after signup |

**Cohort Table:**
- Weekly cohorts (configurable: 4/8/12 weeks)
- Cohort size
- D1, D7, D30 retention percentages
- D7/D30 show as "—" if cohort is too recent

**Activity Definition:**
Activity is tracked from these tables:
- `quest_completions` (via `daily_quests`)
- `quiz_sessions`
- `linked_matches`
- `word_search_matches`

### Subscriptions (`/admin/subscriptions`)

Subscription analytics and revenue metrics.

**Status Breakdown:**
| Status | Description |
|--------|-------------|
| Active | Paid subscribers |
| Trial | Users in trial period |
| Cancelled | Cancelled but not expired |
| Expired | Subscription ended |
| None | Never subscribed |

**By Product:**
- Breakdown of active subscriptions by product ID
- Maps to "Premium Yearly" or "Premium Monthly"
- Shows count and percentage

**Trends Chart:**
- New trials per day
- Conversions per day
- Churned per day

**Trial Conversion:**
- Total trials started
- Converted to paid
- Conversion rate %

**Revenue Estimates:**
- MRR (Monthly Recurring Revenue)
- ARR (Annual Recurring Revenue)
- Based on: Yearly = $49.99/year, Monthly = $7.99/month

**Recent Cancellations:**
- Last 10 cancelled/expired subscriptions
- Shows anonymized couple ID, product, duration, status

## API Endpoints

All endpoints require admin authentication (session cookie).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/admin/auth` | POST | Login with email |
| `/api/admin/auth` | GET | Validate current session |
| `/api/admin/auth` | DELETE | Logout |
| `/api/admin/overview` | GET | Overview metrics |
| `/api/admin/retention` | GET | Retention cohort data |
| `/api/admin/subscriptions` | GET | Subscription metrics |

### Query Parameters

**Overview:**
- `range` (default: 30) - Days of historical data

**Retention:**
- `weeks` (default: 8) - Number of weeks for cohort analysis

**Subscriptions:**
- `range` (default: 30) - Days for trend data

## Key Files

| File | Purpose |
|------|---------|
| `api/app/admin/page.tsx` | Overview page |
| `api/app/admin/retention/page.tsx` | Retention page |
| `api/app/admin/subscriptions/page.tsx` | Subscriptions page |
| `api/app/admin/login/page.tsx` | Login page |
| `api/app/admin/layout.tsx` | Admin layout |
| `api/app/admin/components/AdminShell.tsx` | Layout wrapper with auth |
| `api/app/admin/components/AdminNav.tsx` | Sidebar navigation |
| `api/app/admin/components/OverviewContent.tsx` | Overview UI |
| `api/app/admin/components/RetentionContent.tsx` | Retention UI |
| `api/app/admin/components/SubscriptionsContent.tsx` | Subscriptions UI |
| `api/app/admin/components/MetricCard.tsx` | Metric display card |
| `api/app/admin/components/Chart.tsx` | Chart component |
| `api/app/admin/components/TimeRangePicker.tsx` | Date range selector |
| `api/lib/admin/auth.ts` | Authentication logic |
| `api/lib/admin/queries/overview.ts` | Overview SQL queries |
| `api/lib/admin/queries/retention.ts` | Retention SQL queries |
| `api/lib/admin/queries/subscriptions.ts` | Subscription SQL queries |
| `api/app/api/admin/auth/route.ts` | Auth API endpoint |
| `api/app/api/admin/overview/route.ts` | Overview API endpoint |
| `api/app/api/admin/retention/route.ts` | Retention API endpoint |
| `api/app/api/admin/subscriptions/route.ts` | Subscriptions API endpoint |

## Data Sources

All metrics query the Supabase PostgreSQL database directly. Key tables:

| Table | Used For |
|-------|----------|
| `auth.users` | User counts |
| `couples` | Couple counts, subscriptions, LP totals |
| `quest_completions` | Activity tracking |
| `daily_quests` | Quest-to-couple mapping |
| `quiz_sessions` | Activity tracking |
| `linked_matches` | Activity tracking |
| `word_search_matches` | Activity tracking |

**Brand Filtering:** All queries filter by `brand_id = 'us2' OR brand_id IS NULL` to show only Us 2.0 data.

## Security

- **Authentication:** Email allowlist + JWT session tokens
- **Cookies:** httpOnly, secure (in production), sameSite: lax
- **Session Duration:** 7 days
- **Re-validation:** Session checks that email is still in allowlist on every request

## Local Development

```bash
cd api

# Set environment variables in .env.local
ADMIN_EMAILS=your-email@example.com
ADMIN_SESSION_SECRET=your-secret-at-least-32-characters-long

# Start dev server
npm run dev

# Access at http://localhost:3000/admin
```

## Troubleshooting

### "This email is not authorized"
- Email not in `ADMIN_EMAILS` environment variable
- Check for typos, ensure lowercase

### "ADMIN_SESSION_SECRET must be at least 32 characters"
- Set `ADMIN_SESSION_SECRET` env var with 32+ character string

### Metrics showing 0
- Check database connection
- Verify `brand_id` filter matches your data
- Check if tables have data

### Session expired unexpectedly
- Sessions last 7 days
- Check if email was removed from allowlist (re-validates on each request)
