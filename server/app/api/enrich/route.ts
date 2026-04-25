import { NextRequest, NextResponse } from "next/server";

function buildSystemPrompt(availableTags: string[]) {
  const tagsSection =
    availableTags.length === 0
      ? "Tags: Return an empty array []."
      : `Tags: Choose zero to two tags from this exact list only: ${availableTags.join(", ")}. Never invent new tags. Prefer applying at least one tag when the transcript clearly matches one. Return [] only when nothing fits.`;

  return `You analyze voice notes for a personal memory app.

CRITICAL: If the voice note contains MULTIPLE distinct actions or tasks, YOU MUST split them into separate entries.
Examples that require splitting:
- "I need to buy milk, call mom, and finish homework" → 3 separate todo entries
- "Remind me to email Sarah and schedule the dentist appointment" → 2 separate todo entries
- "I should clean my room and do laundry tomorrow" → 2 separate todo entries

If it contains only ONE item or is a general thought/idea, return a single entry.

Return ONLY valid JSON matching this exact schema — no markdown, no explanation:
{
  "entries": [
    {
      "type": "braindump" | "todo" | "idea",
      "transcript": "<the focused source text for this entry only; do not repeat the full original note when split>",
      "summary": "<one crisp sentence, max 80 chars, no emoji, no quotes>",
      "taskTitle": "<cleaned task phrase if type is todo, otherwise null>",
      "triggerTimeIso": "<ISO 8601 datetime if type is todo and a resolvable time exists, otherwise null>",
      "tags": ["<subset of allowed tags>"]
    }
  ]
}

Classification guide:
- todo: any concrete action, obligation, or follow-up, even if phrased casually or imperatively ("need to", "should", "call", "buy", "send", "schedule", "finish")
- idea: creative, speculative, or invention-style thought ("what if", "idea:", "could build", "I could")
- braindump: general observation, reflection, context, or note that is not directly actionable

${tagsSection}

SPLITTING RULES:
1. Look for conjunctions: "and", "also", comma-separated lists
2. Each distinct action/task becomes its own entry
3. Each entry should have ONE clear action/purpose
4. Keep time context: if "tomorrow" applies to all tasks, include it in each task transcript and taskTitle
5. When splitting a note, each entry transcript must only describe that one entry
6. If one project, product, or life area tag applies to the whole note, repeat that same tag on every split entry where it still fits`;
}

export async function POST(req: NextRequest) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: "OpenAI API key not configured" },
      { status: 503 },
    );
  }

  const { transcript, capturedAt, availableTags } = await req.json();
  if (!transcript) {
    return NextResponse.json({ error: "transcript required" }, { status: 400 });
  }

  const normalizedTags = Array.isArray(availableTags)
    ? [
        ...new Set(
          availableTags
            .map((tag) => String(tag).trim().toLowerCase())
            .filter(Boolean),
        ),
      ]
    : [];
  console.info("[reverb:enrich] request", {
    availableTags: normalizedTags,
    transcriptPreview: String(transcript).slice(0, 120),
  });

  // Responses API — replaces Chat Completions for all new projects.
  const upstream = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-5.4-nano",
      instructions: buildSystemPrompt(normalizedTags),
      input: `Return JSON. Captured at: ${capturedAt ?? new Date().toISOString()}\nAvailable tags: ${normalizedTags.join(", ") || "[]"}\nTranscript: ${transcript}`,
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

    // Support new array format: { entries: [...] }
    // Also maintain backward compatibility with single entry format
    if (parsed.entries && Array.isArray(parsed.entries)) {
      console.info(
        "[reverb:enrich] response",
        parsed.entries.map((entry: { type?: string; tags?: string[] }) => ({
          type: entry.type,
          tags: entry.tags ?? [],
        })),
      );
      return NextResponse.json(parsed);
    } else if (parsed.type) {
      // Legacy single-entry format, wrap in entries array
      return NextResponse.json({
        entries: [parsed],
      });
    } else {
      return NextResponse.json(
        { error: "invalid response format", raw: content },
        { status: 502 },
      );
    }
  } catch {
    return NextResponse.json(
      { error: "bad upstream JSON", raw: content },
      { status: 502 },
    );
  }
}
