// Proxies an "@employee command" chat message to the OpenAI API.
//
// This runs server-side (Supabase Edge Function / Deno), never in the
// browser, so the OpenAI API key set via `OPENAI_API_KEY` stays out of the
// client bundle. See docs/PHASE6_AI_EMPLOYEES.md for how to deploy this
// function and set that secret.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENAI_MODEL = "gpt-4o-mini";

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
    const { employeeName, employeeRole, command, history } = await req.json();
    if (!employeeName || !employeeRole || !command) {
      return new Response(
        JSON.stringify({ error: "employeeName, employeeRole, command required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
    }

    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "OPENAI_API_KEY is not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
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

    // Prior turns with this same employee, so multi-turn follow-ups (e.g.
    // "그럼 그중 두 번째 항목만 더 자세히") have something to refer back to.
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
          .map((turn) => ({ role: turn.role, content: turn.content }))
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
          { role: "user", content: command },
        ],
      }),
    });

    if (!openaiResponse.ok) {
      const errorBody = await openaiResponse.text();
      return new Response(
        JSON.stringify({ error: `OpenAI API error: ${errorBody}` }),
        {
          status: 502,
          headers: { ...corsHeaders, "content-type": "application/json" },
        },
      );
    }

    const data = await openaiResponse.json();
    const rawReply = data?.choices?.[0]?.message?.content ?? "(응답을 받지 못했습니다)";
    const reply = stripMarkdown(rawReply);

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
