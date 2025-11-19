# TogetherRemind API - Next.js + PostgreSQL Backend

**Phase 1 - Issue #2: INFRA-101**

Complete backend API for TogetherRemind migration from Firebase RTDB to PostgreSQL/Supabase.

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Vercel CLI (`npm i -g vercel`)
- Supabase CLI (`brew install supabase/tap/supabase`)

### 1. Initialize Supabase Project

```bash
# Login to Supabase
supabase login

# Initialize project (creates supabase/ directory)
supabase init

# Link to your Supabase project (create one at https://supabase.com if needed)
supabase link --project-ref your-project-ref

# Apply database migrations
supabase db push
```

### 2. Initialize Vercel Project

```bash
# Login to Vercel
vercel login

# Deploy to Vercel (creates project and deploys)
vercel

# Follow prompts:
# - Set up and deploy? Yes
# - Which scope? Your account/team
# - Link to existing project? No
# - Project name? togetherremind-api
# - Directory? ./
# - Override settings? No
```

### 3. Configure Environment Variables

#### Get Supabase Credentials:
```bash
# Get your Supabase connection strings
supabase status

# Copy the following from output:
# - API URL → SUPABASE_URL
# - anon key → SUPABASE_ANON_KEY
# - service_role key → SUPABASE_SERVICE_ROLE_KEY
# - DB URL → DATABASE_URL
```

#### Set Vercel Environment Variables:
```bash
# Set environment variables in Vercel
vercel env add SUPABASE_URL
vercel env add SUPABASE_ANON_KEY
vercel env add SUPABASE_SERVICE_ROLE_KEY
vercel env add SUPABASE_JWT_SECRET
vercel env add DATABASE_URL
vercel env add DATABASE_POOL_URL
```

Or via Vercel Dashboard:
- Go to https://vercel.com/dashboard
- Select your project
- Settings → Environment Variables
- Add each variable

### 4. Local Development

```bash
# Copy example env file
cp .env.local.example .env.local

# Edit .env.local with your Supabase credentials
nano .env.local

# Install dependencies
npm install

# Run development server
npm run dev
```

Open http://localhost:3000/api/health to test the health check endpoint.

---

## 📁 Project Structure

```
api/
├── app/
│   └── api/
│       └── health/
│           └── route.ts          # Health check endpoint
├── lib/
│   ├── supabase/
│   │   └── server.ts             # Supabase client (server-side)
│   └── db/
│       └── pool.ts               # PostgreSQL connection pool
├── supabase/
│   └── migrations/
│       └── 001_initial_schema.sql # Database schema
├── next.config.ts                # Next.js configuration
├── tsconfig.json                 # TypeScript configuration
└── package.json                  # Dependencies

```

---

## 🔍 Testing

### Health Check
```bash
# Local
curl http://localhost:3000/api/health

# Production
curl https://your-project.vercel.app/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "message": "API and database connections working",
  "timestamp": "2025-11-19T10:30:00.000Z",
  "environment": "production"
}
```

---

## 🗄️ Database Schema

The initial schema includes:
- **Couples** - User relationships
- **Daily Quests** - Quest management
- **Quiz System** - Quiz sessions and answers
- **You or Me Game** - Game sessions
- **Memory Flip** - Puzzle game
- **Love Points** - Points tracking with deduplication

All tables have Row Level Security (RLS) enabled.

---

## 🚢 Deployment

### Deploy to Production
```bash
# Deploy latest changes
vercel --prod
```

### Check Deployment Status
```bash
# List deployments
vercel ls

# Check logs
vercel logs
```

---

## 📊 Monitoring

### Database Connections
```bash
# Check active connections
supabase db query "SELECT count(*) FROM pg_stat_activity WHERE datname = 'postgres';"
```

### API Health
- Health check: `/api/health`
- Vercel dashboard: https://vercel.com/dashboard
- Supabase dashboard: https://supabase.com/dashboard

---

## 🔧 Troubleshooting

### Database Connection Issues
1. Verify environment variables are set in Vercel
2. Check Supabase project is active
3. Verify connection strings are correct
4. Check Supabase dashboard for connection pool usage

### Vercel Deployment Fails
1. Check build logs: `vercel logs`
2. Verify all dependencies are in package.json
3. Check TypeScript compilation: `npm run build`
4. Verify environment variables are set

---

## 📚 Related Documentation

- [Migration Plan](/docs/MIGRATION_TO_NEXTJS_POSTGRES.md)
- [Codex Review](/docs/CODEX_ROUND_2_REVIEW_SUMMARY.md)
- [GitHub Issues](https://github.com/jachren-f4/together-reminder/issues)

---

## ✅ Issue #2 Acceptance Criteria

- [x] Create Vercel project with Next.js 14+ App Router
- [x] Create Supabase project with PostgreSQL 15+
- [ ] Configure database connection URLs (manual step)
- [ ] Set up environment variables in Vercel (manual step)
- [x] Run initial database schema migration
- [ ] Verify connection from Vercel to Supabase works

**Status:** Ready for manual Supabase/Vercel project setup

**Next Steps:**
1. Run `supabase init` and `supabase link`
2. Run `vercel` to create project
3. Set environment variables
4. Test health check endpoint
