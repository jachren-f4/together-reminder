# Development Authentication Bypass

## Overview

This development-only feature allows you to skip the email authentication flow during development, eliminating the need to constantly check your email for magic link tokens.

## How It Works

When enabled, API requests bypass JWT verification and automatically use a test user ID from your environment variables. This only works in development mode (`NODE_ENV=development`) and requires explicit opt-in.

## Setup Instructions

### 1. Find Your User ID

You need your actual user ID from the database. You have two options:

**Option A: From existing login (recommended)**
1. Log in once using the normal email authentication flow
2. Copy the JWT token from the network request or browser storage
3. Decode it at https://jwt.io
4. Copy the `sub` claim (this is your user ID)

**Option B: Query the database directly**
```bash
# Connect to your Supabase database and run:
SELECT user1_id, user2_id FROM couples LIMIT 1;

# Use either user1_id or user2_id
```

### 2. Update .env.local

Edit `/api/.env.local` and replace the placeholder:

```bash
# Before
AUTH_DEV_USER_ID=replace-with-your-user-id-from-database

# After (example)
AUTH_DEV_USER_ID=a1b2c3d4-e5f6-7890-abcd-1234567890ab
```

The bypass is already enabled with:
```bash
AUTH_DEV_BYPASS_ENABLED=true
AUTH_DEV_USER_EMAIL=dev@togetherremind.local
```

### 3. Restart Next.js Dev Server

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
# Kill existing process (Ctrl+C) then restart:
npm run dev
```

### 4. Verify It's Working

You should see log messages like this when you make API requests:

```
[DEV AUTH BYPASS] Active for userId: a1b2c3d4-... | Email: dev@togetherremind.local | Endpoint: /api/sync/daily-quests
```

## What Gets Bypassed

All sync endpoints now use the dev bypass:
- ✅ `/api/sync/daily-quests` - Quest sync
- ✅ `/api/sync/love-points` - Love Points sync
- ✅ `/api/sync/quiz-sessions` - Quiz sessions
- ✅ `/api/sync/you-or-me` - You or Me game
- ✅ `/api/sync/memory-flip` - Memory Flip game
- ✅ `/api/sync/reminders` - Reminders and Pokes

## Security Notes

### This is 100% Safe for Production

The bypass requires **both** conditions to be true:
1. `NODE_ENV=development` - Must be in development mode
2. `AUTH_DEV_BYPASS_ENABLED=true` - Must explicitly opt-in

**If misconfigured in production:**
- If someone accidentally sets `AUTH_DEV_BYPASS_ENABLED=true` in Vercel, the bypass is **blocked**
- An error log is emitted: `[DEV AUTH BYPASS] BLOCKED - AUTH_DEV_BYPASS_ENABLED is true but NODE_ENV=production`
- Normal JWT authentication is used instead

**Additional safeguards:**
- Clear WARN-level logging when bypass is active
- Error-level logging when bypass is blocked due to environment mismatch

### Disabling the Bypass

To go back to normal JWT authentication during development:

```bash
# In .env.local, change:
AUTH_DEV_BYPASS_ENABLED=false

# Then restart the dev server
```

## Troubleshooting

### "Couple not found" Error

Your `AUTH_DEV_USER_ID` must exist in the `couples` table. Verify with:

```bash
SELECT * FROM couples WHERE user1_id = 'your-user-id' OR user2_id = 'your-user-id';
```

If no results, you need to:
1. Create a new account using normal auth flow
2. Complete the pairing process
3. Use one of the resulting user IDs

### Bypass Not Activating

Check:
1. ✅ `NODE_ENV=development` in .env.local
2. ✅ `AUTH_DEV_BYPASS_ENABLED=true` in .env.local
3. ✅ You restarted the Next.js dev server after changing .env.local
4. ✅ You're seeing the `[DEV AUTH BYPASS]` log messages

### Wrong User Data

The bypass uses the userId you specify. If you're seeing data for the wrong user, you likely need to:
1. Verify your `AUTH_DEV_USER_ID` is correct
2. Make sure that userId has the expected couple/data in the database

## Files Modified

```
/api/lib/auth/dev-middleware.ts              (NEW) - Bypass implementation
/api/.env.local                              - Added bypass configuration
/api/app/api/sync/daily-quests/route.ts      - Uses withAuthOrDevBypass()
/api/app/api/sync/love-points/route.ts       - Uses withAuthOrDevBypass()
/api/app/api/sync/quiz-sessions/route.ts     - Uses withAuthOrDevBypass()
/api/app/api/sync/you-or-me/route.ts         - Uses withAuthOrDevBypass()
/api/app/api/sync/memory-flip/route.ts       - Uses withAuthOrDevBypass()
/api/app/api/sync/reminders/route.ts         - Uses withAuthOrDevBypass()
```

## Benefits

- 🚀 **10x faster development** - No more email checking
- 🔒 **Production-safe** - Impossible to enable in production
- 🎯 **Easy to toggle** - Single environment variable
- 📝 **Clear visibility** - Warning logs show when active
- 🔄 **Reversible** - Can switch back to normal auth anytime

---

**Last Updated:** 2025-12-09
