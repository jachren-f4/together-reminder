# Monitoring & Alerting Documentation

**Issue #3: INFRA-103**

Complete monitoring setup for TogetherRemind API with health checks, metrics, and alerting.

---

## 🎯 Overview

### What's Monitored

1. **API Health**
   - Database connectivity
   - Response times
   - Connection pool usage
   - System uptime

2. **Performance Metrics**
   - Request latency (P50, P95, P99)
   - Error rates
   - Request throughput
   - Database query performance

3. **Alerts**
   - High error rates (>5%)
   - Slow responses (P95 >300ms)
   - Database connection saturation (>50/60)
   - Sync failures

---

## 📍 Endpoints

### `/api/health` - Health Check

**Purpose:** Comprehensive health status for load balancers and monitoring

**Response Format:**
```json
{
  "status": "healthy",
  "checks": {
    "database": {
      "status": "pass",
      "response_time_ms": 12,
      "connections": 3
    },
    "api": {
      "status": "pass",
      "uptime_seconds": 43200
    }
  },
  "metrics": {
    "requests_last_5min": 1245,
    "errors_last_5min": 3,
    "error_rate_percent": "0.24",
    "latency_p95_ms": 145
  },
  "system": {
    "timestamp": "2025-11-19T10:30:00.000Z",
    "environment": "production",
    "version": "a3c9f21",
    "node_version": "v20.10.0"
  }
}
```

**Status Codes:**
- `200` - Healthy
- `503` - Degraded (some checks failing)
- `500` - Unhealthy (critical failure)

**Usage:**
```bash
# Check health
curl https://your-api.vercel.app/api/health

# Monitor with watch
watch -n 5 'curl -s https://your-api.vercel.app/api/health | jq ".status"'
```

### `/api/metrics` - Performance Metrics

**Purpose:** Detailed performance metrics for dashboards

**Response Format:**
```json
{
  "http_requests_total": 1245,
  "http_errors_total": 3,
  "http_error_rate_percent": 0.24,
  "http_request_duration_p50_ms": 78,
  "http_request_duration_p95_ms": 145,
  "http_request_duration_p99_ms": 289,
  "timestamp": "2025-11-19T10:30:00.000Z"
}
```

---

## 🚨 Alert Thresholds

### Critical Alerts (Immediate Action Required)

| Metric | Threshold | Action |
|--------|-----------|--------|
| Error Rate | >5% | Check logs, investigate cause |
| API P95 Latency | >300ms | Check database, optimize queries |
| DB Connections | >55 (of 60) | Investigate connection leaks |
| Failed Syncs | >20/min | Check client-side issues |

### Warning Alerts (Monitor Closely)

| Metric | Threshold | Action |
|--------|-----------|--------|
| Error Rate | >1% | Monitor trends |
| API P95 Latency | >150ms | Review recent deploys |
| DB Connections | >50 | Review connection patterns |
| Failed Syncs | >5/min | Check for patterns |

---

## 📊 Monitoring Setup

### Vercel Dashboard

Vercel provides built-in monitoring:
1. Go to https://vercel.com/dashboard
2. Select your project
3. Click "Analytics" tab

**Available Metrics:**
- Request count
- Error rates
- Response times
- Bandwidth usage

### Custom Dashboard (Grafana/Similar)

Query the `/api/metrics` endpoint every 30 seconds:

```bash
# Example: Store metrics in time-series database
while true; do
  curl -s https://your-api.vercel.app/api/metrics | \
    jq '.' >> metrics.jsonl
  sleep 30
done
```

### Uptime Monitoring

Use external services:
- **UptimeRobot** (free): https://uptimerobot.com
- **Better Uptime**: https://betteruptime.com
- **Pingdom**: https://pingdom.com

Configure to check `/api/health` every 5 minutes.

---

## 🛠️ Sentry Error Tracking

### Setup Instructions

1. **Create Sentry Project**
   ```bash
   # Sign up at https://sentry.io
   # Create new project (Next.js)
   # Copy DSN
   ```

2. **Install Sentry**
   ```bash
   cd api
   npm install @sentry/nextjs
   ```

3. **Add Environment Variable**
   ```bash
   # In Vercel dashboard or locally
   SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
   ```

4. **Initialize Sentry**
   ```typescript
   // Already configured in lib/monitoring/sentry.ts
   // Just uncomment after installing @sentry/nextjs
   ```

### What Sentry Captures

- All API route errors
- Database query failures
- Unhandled exceptions
- Performance traces (10% sampling)

### Viewing Errors

1. Go to https://sentry.io
2. Select your project
3. View Issues dashboard
4. Get notified via email/Slack

---

## 📈 Performance Optimization

### Database Connection Pooling

**Current Setup:**
- Single connection per Vercel worker
- Max 60 total connections (Supabase limit)
- Connection reuse across requests

**Monitoring:**
```typescript
// Check connection count
const pool = getPool();
console.log('Active connections:', pool.totalCount);
```

**Optimization Tips:**
1. Keep connections <50 (83% utilization)
2. Increase pool size if hitting limits
3. Use PgBouncer for connection multiplexing

### API Latency Optimization

**Target:** P95 <200ms, P99 <500ms

**Strategies:**
1. **Database Indexing** - Ensure all foreign keys indexed
2. **Query Optimization** - Use EXPLAIN ANALYZE
3. **Caching** - Add Redis for frequent queries
4. **Connection Pooling** - Reuse database connections

**Monitoring:**
```bash
# Watch latency in real-time
watch -n 1 'curl -s https://your-api.vercel.app/api/metrics | jq ".http_request_duration_p95_ms"'
```

---

## 🔍 Debugging Issues

### High Error Rate

```bash
# Check recent errors
curl https://your-api.vercel.app/api/metrics | jq

# View Vercel logs
vercel logs --follow

# Check Sentry for error details
open https://sentry.io
```

### Slow Response Times

```bash
# Check database response time
curl https://your-api.vercel.app/api/health | jq ".checks.database"

# Check Supabase dashboard
open https://supabase.com/dashboard

# Look for slow queries
# In Supabase: Database → Query Performance
```

### High Database Connections

```bash
# Check connection count
curl https://your-api.vercel.app/api/health | jq ".checks.database.connections"

# In Supabase dashboard:
# Database → Connection pooling
# Check active connections
```

---

## 🧪 Testing Monitoring

### Test Health Endpoint

```bash
# Should return 200 and "healthy"
curl -i https://your-api.vercel.app/api/health

# Test with jq
curl -s https://your-api.vercel.app/api/health | jq ".status"
```

### Test Error Tracking

```bash
# Trigger an error (404)
curl https://your-api.vercel.app/api/nonexistent

# Check if logged in Sentry
```

### Test Metrics Collection

```bash
# Make several requests
for i in {1..10}; do
  curl https://your-api.vercel.app/api/health > /dev/null 2>&1
done

# Check metrics updated
curl https://your-api.vercel.app/api/metrics | jq
```

---

## 📝 Checklist

- [ ] Health endpoint responds correctly
- [ ] Metrics endpoint shows data
- [ ] Sentry DSN configured (optional)
- [ ] Vercel analytics enabled
- [ ] Uptime monitor configured
- [ ] Alert thresholds documented
- [ ] Team trained on monitoring tools

---

## 🔗 Related Documentation

- [API README](README.md)
- [Migration Plan](../docs/MIGRATION_TO_NEXTJS_POSTGRES.md)
- [Codex Review](../docs/CODEX_ROUND_2_REVIEW_SUMMARY.md)

---

**Issue #3 Status:** ✅ Complete - Ready for production monitoring
