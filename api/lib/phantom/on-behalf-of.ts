/**
 * onBehalfOf Validation Utility
 *
 * When playing in single-phone mode, the logged-in user submits answers
 * for their phantom partner using the `onBehalfOf` field. This utility
 * validates that the caller is coupled with the target AND the target
 * is a phantom user.
 */

import { PoolClient } from 'pg';
import { query } from '@/lib/db/pool';
import { isPhantomUser } from './utils';

export interface OnBehalfOfResult {
  valid: boolean;
  error?: string;
  effectiveUserId: string;
}

/**
 * Validate and resolve the effective user ID for a game submission.
 *
 * If `onBehalfOf` is provided:
 *   - Validates caller is coupled with target
 *   - Validates target is a phantom user
 *   - Returns target as effectiveUserId
 *
 * If `onBehalfOf` is absent:
 *   - Returns caller as effectiveUserId (existing behavior)
 *
 * @param callerId - The authenticated user making the request
 * @param onBehalfOf - Optional phantom user ID to act on behalf of
 * @param client - Optional database client (for use within transactions)
 */
export async function validateOnBehalfOf(
  callerId: string,
  onBehalfOf: string | undefined | null,
  client?: PoolClient
): Promise<OnBehalfOfResult> {
  // No onBehalfOf → existing behavior
  if (!onBehalfOf) {
    return { valid: true, effectiveUserId: callerId };
  }

  // Can't act on behalf of yourself
  if (onBehalfOf === callerId) {
    return { valid: false, error: 'Cannot act on behalf of yourself', effectiveUserId: callerId };
  }

  const queryFn = client ? client.query.bind(client) : query;

  // Verify caller is coupled with the target
  const coupleResult = await queryFn(
    `SELECT id FROM couples
     WHERE (user1_id = $1 AND user2_id = $2)
        OR (user1_id = $2 AND user2_id = $1)`,
    [callerId, onBehalfOf]
  );

  if (coupleResult.rows.length === 0) {
    return { valid: false, error: 'Not coupled with target user', effectiveUserId: callerId };
  }

  // Verify target is a phantom user
  const phantom = await isPhantomUser(onBehalfOf, client);
  if (!phantom) {
    return { valid: false, error: 'Target user is not a phantom user', effectiveUserId: callerId };
  }

  return { valid: true, effectiveUserId: onBehalfOf };
}
