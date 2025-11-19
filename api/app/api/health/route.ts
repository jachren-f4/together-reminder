import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = createClient();
    
    // Test database connection
    const { data, error } = await supabase
      .from('_health_check')
      .select('*')
      .limit(1);
    
    if (error && error.code !== 'PGRST116') {
      // PGRST116 = table doesn't exist (OK for initial setup)
      console.error('Database connection error:', error);
      return NextResponse.json(
        {
          status: 'degraded',
          message: 'Database connection issue',
          timestamp: new Date().toISOString(),
          error: error.message,
        },
        { status: 503 }
      );
    }
    
    return NextResponse.json({
      status: 'healthy',
      message: 'API and database connections working',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
    });
  } catch (error) {
    console.error('Health check failed:', error);
    return NextResponse.json(
      {
        status: 'unhealthy',
        message: 'Health check failed',
        timestamp: new Date().toISOString(),
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 500 }
    );
  }
}
