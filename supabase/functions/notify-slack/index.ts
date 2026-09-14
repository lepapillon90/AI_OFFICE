// Posts an activity-log message to a company's configured Slack incoming
// webhook. Runs server-side (Supabase Edge Function / Deno) rather than the
// browser calling Slack directly, for two reasons: Slack's incoming-webhook
// endpoint doesn't send CORS headers permitting a browser origin to POST to
// it, and the webhook URL itself (a bearer-token-equivalent secret) never
// needs to reach the client bundle this way. See docs/PHASE8_SLACK.md.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Slack's own message cap is far higher; this just keeps one activity-log
// line from ever ballooning into something unreasonable to relay.
const MAX_TEXT_LENGTH = 4000;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Same pattern as ask-employee: the gateway already confirmed *a*
  // signed-in user of this project, not which company they belong to —
  // the membership check below is what scopes this to "a member of
  // companyId".
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "server misconfigured" }, 500);
  }

  // Scoped to the caller's own JWT, so both queries below run under their
  // normal RLS — this only ever sees what their own membership already
  // allows (see docs/PHASE8_SLACK.md for the company_integrations policies
  // this depends on).
  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  try {
    const { companyId, text } = await req.json();
    if (!companyId || !text) {
      return jsonResponse({ error: "companyId, text required" }, 400);
    }

    // Not .maybeSingle(): the owner's own RLS policy lets them see every
    // row in their company, so this can legitimately return more than one
    // row once a company has more than one member (same reasoning as
    // ask-employee's membership check).
    const { data: membershipRows, error: membershipError } =
      await callerClient
        .from("company_members")
        .select("user_id")
        .eq("company_id", companyId)
        .limit(1);
    if (membershipError) {
      return jsonResponse({ error: membershipError.message }, 500);
    }
    if (!membershipRows || membershipRows.length === 0) {
      return jsonResponse({ error: "not a member of this company" }, 403);
    }

    const { data: integration, error: integrationError } = await callerClient
      .from("company_integrations")
      .select("slack_webhook_url")
      .eq("company_id", companyId)
      .maybeSingle();
    if (integrationError) {
      return jsonResponse({ error: integrationError.message }, 500);
    }
    const webhookUrl = integration?.slack_webhook_url as string | null | undefined;
    if (!webhookUrl) {
      // Not every company enables Slack — an expected outcome, not an
      // error the caller needs to react to.
      return jsonResponse({ skipped: true });
    }

    const truncated = String(text).slice(0, MAX_TEXT_LENGTH);
    const slackResponse = await fetch(webhookUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text: truncated }),
    });
    if (!slackResponse.ok) {
      const body = await slackResponse.text();
      return jsonResponse({ error: `slack webhook failed: ${body}` }, 502);
    }

    return jsonResponse({ ok: true });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
