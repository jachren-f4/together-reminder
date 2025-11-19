/**
 * JWT Verification - Local verification with Supabase JWT secret
 * 
 * Performance: <1ms verification time (no network calls)
 * 
 * Install: npm install jsonwebtoken @types/jsonwebtoken
 */

import jwt from 'jsonwebtoken';

interface JWTPayload {
  sub: string; // user ID
  email?: string;
  role?: string;
  aud?: string;
  exp?: number;
  iat?: number;
}

interface VerifyResult {
  valid: boolean;
  userId?: string;
  email?: string;
  error?: string;
}

/**
 * Verify JWT token locally using Supabase JWT secret
 * 
 * @param token - JWT token from Authorization header
 * @returns Verification result with user ID if valid
 */
export function verifyToken(token: string): VerifyResult {
  const startTime = performance.now();

  try {
    const jwtSecret = process.env.SUPABASE_JWT_SECRET;

    if (!jwtSecret) {
      console.error('SUPABASE_JWT_SECRET not configured');
      return {
        valid: false,
        error: 'JWT secret not configured',
      };
    }

    // Verify token signature and expiration locally (no network call)
    const decoded = jwt.verify(token, jwtSecret, {
      algorithms: ['HS256'], // Supabase uses HS256
    }) as JWTPayload;

    const verificationTime = performance.now() - startTime;

    // Log slow verifications (should be <1ms)
    if (verificationTime > 1) {
      console.warn(`Slow JWT verification: ${verificationTime.toFixed(2)}ms`);
    }

    return {
      valid: true,
      userId: decoded.sub,
      email: decoded.email,
    };
  } catch (error) {
    const verificationTime = performance.now() - startTime;

    if (error instanceof jwt.TokenExpiredError) {
      return {
        valid: false,
        error: 'Token expired',
      };
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return {
        valid: false,
        error: 'Invalid token',
      };
    }

    console.error('JWT verification error:', error);
    return {
      valid: false,
      error: 'Token verification failed',
    };
  }
}

/**
 * Extract token from Authorization header
 * 
 * @param authHeader - Authorization header value
 * @returns JWT token or null
 */
export function extractToken(authHeader: string | null): string | null {
  if (!authHeader) {
    return null;
  }

  // Format: "Bearer <token>"
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }

  return authHeader.substring(7); // Remove "Bearer " prefix
}

/**
 * Check if token is close to expiration (within 5 minutes)
 * 
 * @param token - JWT token
 * @returns true if token expires within 5 minutes
 */
export function isTokenExpiringSoon(token: string): boolean {
  try {
    const decoded = jwt.decode(token) as JWTPayload | null;
    
    if (!decoded || !decoded.exp) {
      return false;
    }

    const now = Math.floor(Date.now() / 1000);
    const timeUntilExpiry = decoded.exp - now;

    // Refresh if expires within 5 minutes (300 seconds)
    return timeUntilExpiry < 300;
  } catch {
    return false;
  }
}

/**
 * Decode token without verification (for debugging)
 * 
 * @param token - JWT token
 * @returns Decoded payload or null
 */
export function decodeToken(token: string): JWTPayload | null {
  try {
    return jwt.decode(token) as JWTPayload;
  } catch {
    return null;
  }
}
