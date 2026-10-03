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

// Master API keys allowed to interact with the Job Bot API
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

/**
 * GET /api/v1/jobs
 * Query jobs for integrations and applications
 */
export async function GET(req: NextRequest) {
  const isAuthed = verifyApiKey(req);
  const { searchParams } = new URL(req.url);
  const limit = Math.min(Number(searchParams.get("limit") || 50), 200);
  const page = Math.max(Number(searchParams.get("page") || 1), 1);
  const offset = (page - 1) * limit;
  const category = searchParams.get("category");
  const language = searchParams.get("lang") || searchParams.get("language");
  const tag = searchParams.get("tag") || searchParams.get("tech");
  const jobType = searchParams.get("job_type") || searchParams.get("type");
  const query = searchParams.get("q") || searchParams.get("query");
  const status = searchParams.get("status") || "published";

  try {
    const params = new URLSearchParams();
    params.set("select", "*");
    params.set("order", "created_at.desc");
    params.set("limit", String(limit));
    params.set("offset", String(offset));

    if (status !== "all") {
      params.set("status", `in.(${status},published,active)`);
    }

    if (category && category !== "all" && category !== "general") {
      params.set("category", `eq.${category}`);
    }

    if (language && language !== "all") {
      params.set("language", `eq.${language.toLowerCase()}`);
    }

    if (jobType && jobType !== "all") {
      params.set("job_type", `eq.${jobType.toLowerCase()}`);
    }

    if (tag && tag !== "all") {
      params.set("tags", `cs.{${tag.toLowerCase()}}`);
    }

    if (query) {
      params.set("or", `(title.ilike.*${query}*,company_name.ilike.*${query}*,description.ilike.*${query}*)`);
    }

    const res = await fetch(`${SUPABASE_URL}/rest/v1/connect_jobs?${params.toString()}`, {
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        Prefer: "count=exact",
      },
      next: { revalidate: 0 },
    });

    if (!res.ok) {
      return NextResponse.json(
        { ok: false, error: "Failed to fetch jobs from database" },
        { status: res.status }
      );
    }

    const data = await res.json();
    const contentRange = res.headers.get("content-range");
    let totalCount = data.length;
    if (contentRange) {
      const match = contentRange.match(/\/(\d+)$/);
      if (match) totalCount = Number(match[1]);
    }

    // Mask sensitive publisher fields if not authenticated with bot key
    const sanitized = data.map((job: Record<string, unknown>) => {
      if (!isAuthed) {
        return {
          id: job.id,
          title: job.title,
          company_name: job.company_name,
          category: job.category,
          language: job.language || "en",
          tags: job.tags,
          salary_min: job.salary_min,
          salary_max: job.salary_max,
          currency: job.currency,
          location: job.location,
          job_type: job.job_type,
          seo_slug: job.seo_slug,
          created_at: job.created_at,
          apply_url: `/jobs/view/${job.seo_slug || job.id}`,
        };
      }
      return job;
    });

    return NextResponse.json({
      ok: true,
      authenticated: isAuthed,
      page,
      limit,
      total: totalCount,
      totalPages: Math.ceil(totalCount / limit),
      jobs: sanitized,
    });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : "Internal Server Error" },
      { status: 500 }
    );
  }
}

/**
 * POST /api/v1/jobs
 * Ingest jobs from an external source, authenticated with JOB_BOT_API_KEY
 */
export async function POST(req: NextRequest) {
  if (!verifyApiKey(req)) {
    return NextResponse.json(
      { ok: false, error: "Unauthorized: Valid API Key required in x-api-key or Authorization Bearer header" },
      { status: 401 }
    );
  }

  try {
    const body = await req.json();
    const {
      title,
      company_name,
      company_domain,
      company_email,
      description,
      category = "Software Development",
      tags = [],
      salary_min = null,
      salary_max = null,
      currency = "USD",
      location = "Remote",
      job_type = "Full-time",
      source = "bot",
      source_id = null,
      source_url = null,
    } = body;

    if (!title || !description) {
      return NextResponse.json(
        { ok: false, error: "Missing required fields: title and description are required" },
        { status: 400 }
      );
    }

    const slugBase = String(title)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
    const randomSuffix = Math.random().toString(36).substring(2, 7);
    const seo_slug = `${slugBase}-${randomSuffix}`;

    const newJob = {
      title,
      company_name: company_name || "Confidential",
      company_domain: company_domain || null,
      company_email: company_email || null,
      description,
      category,
      tags: Array.isArray(tags) ? tags : [],
      salary_min: salary_min ? Number(salary_min) : null,
      salary_max: salary_max ? Number(salary_max) : null,
      currency,
      location,
      job_type,
      source,
      source_id,
      source_url,
      seo_slug,
      status: "active",
      is_public: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const res = await fetch(`${SUPABASE_URL}/rest/v1/connect_jobs`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(newJob),
    });

    if (!res.ok) {
      const errText = await res.text();
      return NextResponse.json(
        { ok: false, error: "Failed to insert job: " + errText },
        { status: res.status }
      );
    }

    const inserted = await res.json();
    return NextResponse.json(
      { ok: true, message: "Job successfully created", job: inserted[0] || inserted },
      { status: 201 }
    );
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : "Internal Server Error" },
      { status: 500 }
    );
  }
}
