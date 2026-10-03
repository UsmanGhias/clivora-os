import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

const SUPABASE_URL =
  process.env.SUPABASE_URL ??
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  "http://127.0.0.1:54321";

const SUPABASE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "";

const VALID_API_KEYS = new Set([
  "clv_live_bot_8a39b4f2e1c750d96a23",
  process.env.JOB_BOT_API_KEY,
  process.env.CLIVORA_API_KEY,
].filter(Boolean));

function verifyApiKey(req: NextRequest): boolean {
  const headerKey = req.headers.get("x-api-key");
  const authHeader = req.headers.get("authorization");
  let bearerToken = "";
  if (authHeader?.startsWith("Bearer ")) {
    bearerToken = authHeader.slice(7).trim();
  }
  const token = headerKey || bearerToken;
  if (!token) return false;
  return VALID_API_KEYS.has(token);
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  try {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
    const filter = isUuid ? `id=eq.${id}` : `seo_slug=eq.${id}`;

    const res = await fetch(`${SUPABASE_URL}/rest/v1/connect_jobs?${filter}`, {
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
      },
      next: { revalidate: 0 },
    });

    if (!res.ok) {
      return NextResponse.json({ ok: false, error: "Job not found" }, { status: 404 });
    }

    const data = await res.json();
    if (!data.length) {
      return NextResponse.json({ ok: false, error: "Job not found" }, { status: 404 });
    }

    return NextResponse.json({ ok: true, job: data[0] });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : "Internal Server Error" },
      { status: 500 }
    );
  }
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  if (!verifyApiKey(req)) {
    return NextResponse.json(
      { ok: false, error: "Unauthorized: Valid API Key required" },
      { status: 401 }
    );
  }

  const { id } = await params;
  try {
    const body = await req.json();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
    const filter = isUuid ? `id=eq.${id}` : `seo_slug=eq.${id}`;

    const res = await fetch(`${SUPABASE_URL}/rest/v1/connect_jobs?${filter}`, {
      method: "PATCH",
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        ...body,
        updated_at: new Date().toISOString(),
      }),
    });

    if (!res.ok) {
      return NextResponse.json(
        { ok: false, error: "Failed to update job" },
        { status: res.status }
      );
    }

    const updated = await res.json();
    return NextResponse.json({ ok: true, job: updated[0] || updated });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : "Internal Server Error" },
      { status: 500 }
    );
  }
}
