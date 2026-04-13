import { NextRequest, NextResponse } from "next/server";

const SYSTEM_PROMPT = `You analyze voice notes for a personal memory app.
Return ONLY valid JSON matching this exact schema — no markdown, no explanation:
{
  "type": "thought" | "todo" | "idea" | "reminder",
  "summary": "<one crisp sentence, max 80 chars, no emoji, no quotes>",
  "taskTitle": "<cleaned task phrase if type is todo or reminder, otherwise null>",
  "triggerTimeIso": "<ISO 8601 datetime if type is reminder with a resolvable time, otherwise null>"
}

Classification guide:
- reminder: user explicitly wants to be notified at a future time
- todo: action or task with no specific time ("need to", "should", "pick up", "call", "buy")
- idea: creative, speculative, or invention-style thought ("what if", "idea:", "could build")
- thought: general observation, reflection, or note that fits none of the above`;

export async function POST(req: NextRequest) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "OpenAI API key not configured" },
      { status: 503 },
    );
  }

  const { transcript, capturedAt } = await req.json();
  if (!transcript) {
    return NextResponse.json({ error: "transcript required" }, { status: 400 });
  }

  // Responses API — replaces Chat Completions for all new projects.
  const upstream = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-5.4-nano",
      instructions: SYSTEM_PROMPT,
      input: `Return JSON. Captured at: ${capturedAt ?? new Date().toISOString()}\nTranscript: ${transcript}`,
      text: { format: { type: "json_object" } },
      store: false,
    }),
  });

  if (!upstream.ok) {
    const text = await upstream.text();
    return new Response(text, { status: upstream.status });
  }

  const data = await upstream.json();

  // Responses API returns output as an array of typed items.
  // Find the message item and pull its text content.
  const messageItem = data?.output?.find(
    (item: { type: string }) => item.type === "message",
  );
  const content = messageItem?.content?.[0]?.text ?? null;

  try {
    const parsed = JSON.parse(content);
    return NextResponse.json(parsed);
  } catch {
    return NextResponse.json(
      { error: "bad upstream JSON", raw: content },
      { status: 502 },
    );
  }
}
