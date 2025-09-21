import { NextResponse } from "next/server";
import { createClient } from "@/utils/supabase/server";
import { createServiceRoleClient } from "@/utils/supabase/service-role";

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const serviceSupabase = createServiceRoleClient();

    // Check authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Check environment variables
    const envCheck = {
      CREEM_API_URL: !!process.env.CREEM_API_URL,
      CREEM_API_KEY: !!process.env.CREEM_API_KEY,
      CREEM_WEBHOOK_SECRET: !!process.env.CREEM_WEBHOOK_SECRET,
      CREEM_SUCCESS_URL: !!process.env.CREEM_SUCCESS_URL,
      SUPABASE_SERVICE_ROLE_KEY: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
      NEXT_PUBLIC_SUPABASE_URL: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
    };

    // Check customer record
    const { data: customer, error: customerError } = await serviceSupabase
      .from('customers')
      .select('*')
      .eq('user_id', user.id)
      .single();

    // Check subscriptions
    const { data: subscriptions, error: subscriptionsError } = await serviceSupabase
      .from('subscriptions')
      .select('*')
      .eq('customer_id', customer?.id || 'none');

    // Check credits history
    const { data: creditsHistory, error: creditsError } = await serviceSupabase
      .from('credits_history')
      .select('*')
      .eq('customer_id', customer?.id || 'none')
      .order('created_at', { ascending: false })
      .limit(5);

    // Test Creem API connection
    let creemApiTest = null;
    try {
      const testResponse = await fetch(`${process.env.CREEM_API_URL}/products`, {
        method: 'GET',
        headers: {
          'x-api-key': process.env.CREEM_API_KEY!,
          'Content-Type': 'application/json',
        },
      });
      creemApiTest = {
        status: testResponse.status,
        ok: testResponse.ok,
        statusText: testResponse.statusText
      };
    } catch (error) {
      creemApiTest = {
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }

    return NextResponse.json({
      user: {
        id: user.id,
        email: user.email,
        created_at: user.created_at
      },
      envCheck,
      customer: {
        data: customer,
        error: customerError?.message
      },
      subscriptions: {
        data: subscriptions,
        error: subscriptionsError?.message
      },
      creditsHistory: {
        data: creditsHistory,
        error: creditsError?.message
      },
      creemApiTest,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Debug API error:', error);
    return NextResponse.json(
      { 
        error: 'Internal server error', 
        details: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString()
      },
      { status: 500 }
    );
  }
}
