/**
 * Admin Dashboard Authentication
 *
 * Email allowlist with signed cookie sessions.
 * Uses JWT for session tokens stored in httpOnly cookies.
 */

import jwt from 'jsonwebtoken';
import { cookies } from 'next/headers';

const COOKIE_NAME = 'admin_session';
const SESSION_EXPIRY_DAYS = 7;

interface AdminSession {
  email: string;
  exp: number;
  iat: number;
}

function getAdminEmails(): string[] {
  const emails = process.env.ADMIN_EMAILS || '';
  return emails.split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
}

function getSessionSecret(): string {
  const secret = process.env.ADMIN_SESSION_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error('ADMIN_SESSION_SECRET must be at least 32 characters');
  }
  return secret;
}

/**
 * Check if email is in the admin allowlist
 */
export function isAllowedEmail(email: string): boolean {
  const normalizedEmail = email.trim().toLowerCase();
  const allowedEmails = getAdminEmails();
  return allowedEmails.includes(normalizedEmail);
}

/**
 * Create a signed session token for the given email
 */
export function createSessionToken(email: string): string {
  const secret = getSessionSecret();
  const expiresIn = `${SESSION_EXPIRY_DAYS}d`;

  return jwt.sign(
    { email: email.toLowerCase() },
    secret,
    { expiresIn }
  );
}

/**
 * Verify and decode a session token
 * Returns null if invalid or expired
 */
export function verifySessionToken(token: string): AdminSession | null {
  try {
    const secret = getSessionSecret();
    const decoded = jwt.verify(token, secret) as AdminSession;

    // Double-check email is still in allowlist
    if (!isAllowedEmail(decoded.email)) {
      return null;
    }

    return decoded;
  } catch {
    return null;
  }
}

/**
 * Get the current admin session from cookies
 * Returns null if not authenticated
 */
export async function getAdminSession(): Promise<AdminSession | null> {
  try {
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get(COOKIE_NAME);

    if (!sessionCookie?.value) {
      return null;
    }

    return verifySessionToken(sessionCookie.value);
  } catch {
    return null;
  }
}

/**
 * Set the admin session cookie
 */
export async function setAdminSession(token: string): Promise<void> {
  const cookieStore = await cookies();

  cookieStore.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: SESSION_EXPIRY_DAYS * 24 * 60 * 60, // seconds
    path: '/',
  });
}

/**
 * Clear the admin session cookie
 */
export async function clearAdminSession(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(COOKIE_NAME);
}

/**
 * Check if the current request is authenticated
 * Use in server components and API routes
 */
export async function requireAdminAuth(): Promise<AdminSession> {
  const session = await getAdminSession();

  if (!session) {
    throw new Error('Unauthorized');
  }

  return session;
}
