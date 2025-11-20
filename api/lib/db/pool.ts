/**
 * Database Connection Pool Management
 * 
 * Implements singleton pattern for Vercel serverless functions
 * Single connection per worker, connection reuse across requests
 */

import { Pool, PoolClient } from 'pg';

let pool: Pool | null = null;

export function getPool(): Pool {
  if (!pool) {
    const connectionString = process.env.DATABASE_POOL_URL || process.env.DATABASE_URL;
    
    if (!connectionString) {
      throw new Error('DATABASE_POOL_URL or DATABASE_URL environment variable is required');
    }

    pool = new Pool({
      connectionString,
      max: 1, // Single connection per Vercel worker
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });

    // Log only errors (not new connections)
    pool.on('error', (err) => {
      console.error('Unexpected database pool error:', err);
    });
  }

  return pool;
}

export async function query(text: string, params?: any[]) {
  const pool = getPool();
  return pool.query(text, params);
}

export async function getClient(): Promise<PoolClient> {
  const pool = getPool();
  return pool.connect();
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
