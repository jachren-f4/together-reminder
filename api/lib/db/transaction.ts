/**
 * Database Transaction Utilities
 *
 * Provides a clean wrapper for handling database transactions.
 * Ensures proper commit/rollback behavior and client release.
 */

import { PoolClient } from 'pg';
import { getClient } from './pool';

// =============================================================================
// Types
// =============================================================================

/**
 * Result type for transaction callbacks.
 * Includes the result data and optionally a response to return early.
 */
export interface TransactionResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  status?: number;
}

// =============================================================================
// Transaction Wrapper
// =============================================================================

/**
 * Execute a callback function within a database transaction.
 * Automatically handles BEGIN, COMMIT, ROLLBACK, and client release.
 *
 * @param callback - Async function that receives the database client
 * @returns The result of the callback function
 * @throws Re-throws any error after rollback
 *
 * @example
 * const result = await withTransaction(async (client) => {
 *   // All queries in here use the same transaction
 *   await client.query('INSERT INTO users (name) VALUES ($1)', ['Alice']);
 *   await client.query('INSERT INTO profiles (user_id) VALUES ($1)', [userId]);
 *   return { success: true, userId };
 * });
 */
export async function withTransaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await getClient();

  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Execute a callback function within a database transaction with early return support.
 * Similar to withTransaction but allows returning early without committing.
 *
 * Use this when your callback might need to return an error response
 * before completing all operations.
 *
 * @param callback - Async function that receives the database client
 * @returns TransactionResult with success status and optional data/error
 *
 * @example
 * const result = await withTransactionResult(async (client) => {
 *   const couple = await getCoupleBasic(userId, client);
 *   if (!couple) {
 *     return { success: false, error: 'No couple found', status: 404 };
 *   }
 *
 *   await client.query('UPDATE couples SET total_lp = total_lp + $1', [30]);
 *   return { success: true, data: { lpAwarded: 30 } };
 * });
 *
 * if (!result.success) {
 *   return NextResponse.json({ error: result.error }, { status: result.status });
 * }
 */
export async function withTransactionResult<T>(
  callback: (client: PoolClient) => Promise<TransactionResult<T>>
): Promise<TransactionResult<T>> {
  const client = await getClient();

  try {
    await client.query('BEGIN');
    const result = await callback(client);

    if (result.success) {
      await client.query('COMMIT');
    } else {
      await client.query('ROLLBACK');
    }

    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Transaction error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Transaction failed',
      status: 500,
    };
  } finally {
    client.release();
  }
}

/**
 * Execute multiple operations in a single transaction.
 * Useful when you have a list of independent operations that should all succeed or all fail.
 *
 * @param operations - Array of async functions that each receive the client
 * @returns Array of results from each operation
 *
 * @example
 * const results = await batchTransaction([
 *   async (client) => client.query('UPDATE users SET name = $1 WHERE id = $2', ['Alice', 1]),
 *   async (client) => client.query('UPDATE users SET name = $1 WHERE id = $2', ['Bob', 2]),
 * ]);
 */
export async function batchTransaction<T>(
  operations: Array<(client: PoolClient) => Promise<T>>
): Promise<T[]> {
  return withTransaction(async (client) => {
    const results: T[] = [];
    for (const operation of operations) {
      results.push(await operation(client));
    }
    return results;
  });
}

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Get a database client for manual transaction management.
 * Use this when you need more control than withTransaction provides.
 *
 * IMPORTANT: Always call client.release() in a finally block!
 *
 * @returns Database client
 *
 * @example
 * const client = await getTransactionClient();
 * try {
 *   await client.query('BEGIN');
 *   // ... your operations ...
 *   await client.query('COMMIT');
 * } catch (error) {
 *   await client.query('ROLLBACK');
 *   throw error;
 * } finally {
 *   client.release();
 * }
 */
export async function getTransactionClient(): Promise<PoolClient> {
  return getClient();
}
