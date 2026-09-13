// Proxies an "@employee command" chat message to the OpenAI API.
//
// This runs server-side (Supabase Edge Function / Deno), never in the
// browser, so the OpenAI API key set via `OPENAI_API_KEY` stays out of the
// client bundle. See docs/PHASE6_AI_EMPLOYEES.md for how to deploy this
// function and set that secret, and docs/PHASE7_OPS_REVIEW.md for why the
// company-membership check and rate limit below were added.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENAI_MODEL = "gpt-4o-mini";

// A raw HTTP call (bypassing the app's own UI/typing) could otherwise send
// an arbitrarily long command or history to inflate token cost per call —
// these caps are the actual enforcement point; the client-side maxLength
// on ChatPanel's TextField is just a UX nicety, not a security boundary.
const MAX_COMMAND_LENGTH = 2000;
const MAX_HISTORY_TURNS = 6;
const MAX_HISTORY_TURN_LENGTH = 2000;

// No client is trusted to send its own OpenAI usage count, so this caps
// how many *actual* OpenAI calls one company can trigger per window,
// checked against npc_usage_events (the same table OfficeGame already
// writes one row to per askEmployee attempt, retries included).
const RATE_LIMIT_MAX_CALLS = 30;
const RATE_LIMIT_WINDOW_MINUTES = 5;

// ChatPanel renders plain text (no markdown support), so strip common
// markdown syntax the model might still emit despite the system prompt
// asking it not to — a belt-and-suspenders fallback, not the primary fix.
function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/__(.*?)__/g, "$1")
    .replace(/\*(.*?)\*/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^[-*]\s+/gm, "· ")
    .trim();
}

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

  // Supabase's platform gateway already rejects a missing/invalid JWT
  // before this code runs (the function isn't deployed with
  // --no-verify-jwt), so this only confirms *some* signed-in user of this
  // Supabase project is calling — it says nothing about which company
  // they belong to. The membership check below is what actually scopes
  // this to "a member of the company this command claims to be for".
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    // Both are set automatically for every Edge Function by the Supabase
    // platform — missing here would mean something is very wrong with the
    // deployment, not a caller error.
    return jsonResponse({ error: "server misconfigured" }, 500);
  }

  // Scoped to the CALLER's own JWT (not a service-role client), so every
  // query below runs under that user's normal RLS — it can only ever see
  // rows their own membership policies already allow.
  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  try {
    const { employeeName, employeeRole, command, history, companyId } =
      await req.json();
    if (!employeeName || !employeeRole || !command || !companyId) {
      return jsonResponse(
        { error: "employeeName, employeeRole, command, companyId required" },
        400,
      );
    }

    // Confirms the caller is actually a member of companyId — closes the
    // gap where any signed-in user of this Supabase project (regardless of
    // which company they belong to, or whether "employeeName" is even on
    // that company's roster) could otherwise spend the shared
    // OPENAI_API_KEY's budget by calling this function directly.
    //
    // Not .maybeSingle(): the owner's own RLS policy
    // ("owner_manage_members") lets them see *every* row in their company,
    // not just their own, so this can legitimately return more than one
    // row once a company has more than one member — .maybeSingle() throws
    // ("multiple rows returned") in that case instead of just confirming
    // membership.
    const { data: membershipRows, error: membershipError } = await callerClient
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

    // Rate limit: counts this company's actual OpenAI calls in the recent
    // window (npc_usage_events — one row per askEmployee attempt,
    // including retries) rather than trusting anything the client sends.
    const windowStart = new Date(
      Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60_000,
    ).toISOString();
    const { count: recentCalls, error: usageError } = await callerClient
      .from("npc_usage_events")
      .select("id", { count: "exact", head: true })
      .eq("company_id", companyId)
      .gte("created_at", windowStart);
    if (usageError) {
      return jsonResponse({ error: usageError.message }, 500);
    }
    if ((recentCalls ?? 0) >= RATE_LIMIT_MAX_CALLS) {
      return jsonResponse(
        {
          error:
            `이 회사는 최근 ${RATE_LIMIT_WINDOW_MINUTES}분 동안 AI 직원 호출 한도(${RATE_LIMIT_MAX_CALLS}회)를 초과했습니다. 잠시 후 다시 시도해주세요.`,
        },
        429,
      );
    }

    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return jsonResponse({ error: "OPENAI_API_KEY is not configured" }, 500);
    }

    const systemPrompt =
      `당신은 가상 오피스에서 일하는 AI 직원 '${employeeName}'이며, ` +
      `역할은 '${employeeRole}'입니다. 동료가 채팅으로 업무를 요청하면 ` +
      `그 역할에 맞게 짧고 실무적인 한국어로 답하세요. 실제로 파일을 ` +
      `만들거나 외부 시스템을 조작할 수는 없으니, 할 수 있는 조언이나 ` +
      `결과물(요약, 목록, 초안 등)을 텍스트로 바로 제공하세요. 이전 대화 ` +
      `내역이 함께 주어지면 그 맥락(이미 답한 내용, 지시받은 조건 등)을 ` +
      `참고해서 답하세요. 이 채팅창은 마크다운을 렌더링하지 않으니 **, #, ` +
      `- 같은 마크다운 기호를 절대 쓰지 말고, 목록도 "1) 항목" 처럼 순수 ` +
      `텍스트로만 작성하세요.`;

    const truncatedCommand = String(command).slice(0, MAX_COMMAND_LENGTH);

    // Prior turns with this same employee, so multi-turn follow-ups (e.g.
    // "그럼 그중 두 번째 항목만 더 자세히") have something to refer back to.
    // Capped in count and per-turn length regardless of what the client
    // claims — see MAX_HISTORY_* above.
    const historyMessages = Array.isArray(history)
      ? history
          .filter(
            (turn: unknown): turn is { role: string; content: string } =>
              !!turn &&
              typeof turn === "object" &&
              ((turn as { role?: unknown }).role === "user" ||
                (turn as { role?: unknown }).role === "assistant") &&
              typeof (turn as { content?: unknown }).content === "string",
          )
          .slice(-MAX_HISTORY_TURNS)
          .map((turn) => ({
            role: turn.role,
            content: turn.content.slice(0, MAX_HISTORY_TURN_LENGTH),
          }))
      : [];

    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        max_tokens: 400,
        messages: [
          { role: "system", content: systemPrompt },
          ...historyMessages,
          { role: "user", content: truncatedCommand },
        ],
      }),
    });

    if (!openaiResponse.ok) {
      const errorBody = await openaiResponse.text();
      return jsonResponse({ error: `OpenAI API error: ${errorBody}` }, 502);
    }

    const data = await openaiResponse.json();
    const rawReply = data?.choices?.[0]?.message?.content ?? "(응답을 받지 못했습니다)";
    const reply = stripMarkdown(rawReply);

    // OpenAI's chat completions response reports token usage for this call —
    // passed through as-is so the client can track usage/cost per employee.
    return jsonResponse({ reply, usage: data?.usage ?? null });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
});
