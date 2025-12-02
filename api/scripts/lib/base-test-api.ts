/**
 * Base Test API Client
 *
 * Abstract base class for making authenticated API requests.
 * Extended by game-specific API clients (QuizTestApi, LinkedTestApi, etc.)
 */

import { TEST_CONFIG } from './test-config';
import { ApiResponse } from './test-utils';

/**
 * Abstract base class for test API clients
 */
export abstract class BaseTestApi {
  protected baseUrl: string;
  protected userId: string;

  constructor(userId: string, baseUrl?: string) {
    this.userId = userId;
    this.baseUrl = baseUrl || TEST_CONFIG.apiBaseUrl;
  }

  /**
   * Make an authenticated API request
   */
  async request<T = ApiResponse>(
    method: 'GET' | 'POST' | 'DELETE',
    path: string,
    body?: Record<string, unknown>
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': this.userId,
    };

    const options: RequestInit = {
      method,
      headers,
    };

    if (body && (method === 'POST' || method === 'DELETE')) {
      options.body = JSON.stringify(body);
    }

    const response = await fetch(url, options);
    const data = await response.json();

    if (!response.ok) {
      const error = new Error(data.error || 'API request failed') as Error & {
        statusCode: number;
        code?: string;
      };
      error.statusCode = response.status;
      error.code = data.code || data.error;
      throw error;
    }

    return data as T;
  }

  /**
   * Get couple's current LP from the love-points endpoint
   */
  async getCoupleLP(): Promise<number> {
    const response = await this.request<{ total?: number }>('GET', '/api/sync/love-points');
    return response.total ?? 0;
  }
}

/**
 * Factory function to create a pair of API clients for user and partner
 */
export function createTestClients<T extends BaseTestApi>(
  ClientClass: new (userId: string) => T
): { user: T; partner: T } {
  return {
    user: new ClientClass(TEST_CONFIG.testUserId),
    partner: new ClientClass(TEST_CONFIG.partnerUserId),
  };
}
