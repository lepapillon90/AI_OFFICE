// Proxies an "@employee command" chat message to the Anthropic API.
//
// This runs server-side (Supabase Edge Function / Deno), never in the
// browser, so the Anthropic API key set via `ANTHROPIC_API_KEY` stays out
// of the client bundle. See docs/PHASE6_AI_EMPLOYEES.md for how to deploy
// this function and set that secret.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Supabase's client SDK attaches the signed-in user's JWT automatically;
  // this only checks that *some* authenticated request is calling in, not
  // which company the caller belongs to — fine for this MVP since the
  // company-management UI is itself gated (see docs/PHASE4_SUPABASE.md).
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  try {
    const { employeeName, employeeRole, command } = await req.json();
    if (!employeeName || !employeeRole || !command) {
      return new Response(
        JSON.stringify({ error: "employeeName, employeeRole, command required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "ANTHROPIC_API_KEY is not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
    }

    const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 400,
        system:
          `당신은 가상 오피스에서 일하는 AI 직원 '${employeeName}'이며, ` +
          `역할은 '${employeeRole}'입니다. 동료가 채팅으로 업무를 요청하면 ` +
          `그 역할에 맞게 짧고 실무적인 한국어로 답하세요. 실제로 파일을 ` +
          `만들거나 외부 시스템을 조작할 수는 없으니, 할 수 있는 조언이나 ` +
          `결과물(요약, 목록, 초안 등)을 텍스트로 바로 제공하세요.`,
        messages: [{ role: "user", content: command }],
      }),
    });

    if (!anthropicResponse.ok) {
      const errorBody = await anthropicResponse.text();
      return new Response(
        JSON.stringify({ error: `Anthropic API error: ${errorBody}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
    }

    const data = await anthropicResponse.json();
    const reply = data?.content?.[0]?.text ?? "(응답을 받지 못했습니다)";

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
});
