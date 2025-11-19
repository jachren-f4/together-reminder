/**
 * Sentry Error Tracking Configuration
 * 
 * Install: npm install @sentry/nextjs
 */

// Note: Uncomment after installing @sentry/nextjs
// import * as Sentry from '@sentry/nextjs';

export function initSentry() {
  if (!process.env.SENTRY_DSN) {
    console.warn('SENTRY_DSN not configured - error tracking disabled');
    return;
  }

  // Uncomment after installing @sentry/nextjs
  /*
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.VERCEL_ENV || 'development',
    
    // Performance monitoring
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
    
    // Error sampling
    sampleRate: 1.0,
    
    // Release tracking
    release: process.env.VERCEL_GIT_COMMIT_SHA,
    
    // Integration options
    integrations: [
      // PostgreSQL queries tracking
      new Sentry.Integrations.Postgres(),
    ],
    
    // Before sending to Sentry
    beforeSend(event, hint) {
      // Don't send certain errors
      if (event.exception) {
        const error = hint.originalException as Error;
        if (error?.message?.includes('ECONNREFUSED')) {
          return null; // Skip connection errors in development
        }
      }
      return event;
    },
  });
  */
}

export function captureError(error: Error, context?: Record<string, any>) {
  console.error('Error:', error, context);
  
  // Uncomment after installing @sentry/nextjs
  /*
  Sentry.captureException(error, {
    extra: context,
  });
  */
}

export function captureMessage(message: string, level: 'info' | 'warning' | 'error' = 'info') {
  console.log(`[${level.toUpperCase()}]`, message);
  
  // Uncomment after installing @sentry/nextjs
  /*
  Sentry.captureMessage(message, level);
  */
}
