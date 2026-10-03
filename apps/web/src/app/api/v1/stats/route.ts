import { NextResponse } from "next/server";
import { SUPABASE_URL as DEFAULT_SUPABASE_URL, SUPABASE_ANON_KEY } from "@/lib/supabase/env";

export const runtime = "nodejs";
export const revalidate = 15; // Cache for 15 seconds

const SUPABASE_URL =
  process.env.SUPABASE_URL ??
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  DEFAULT_SUPABASE_URL;

const SUPABASE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  SUPABASE_ANON_KEY;

export async function GET() {
  let count = 1205;
  try {
    if (SUPABASE_KEY) {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/connect_jobs?select=id&is_public=eq.true&status=eq.published&limit=1`,
        {
          headers: {
            apikey: SUPABASE_KEY,
            Authorization: `Bearer ${SUPABASE_KEY}`,
            Prefer: "count=exact",
          },
          next: { revalidate: 15 },
        }
      );
      const cr = res.headers.get("content-range");
      if (cr) {
        const match = cr.match(/\/(\d+)$/);
        if (match && Number(match[1]) > 0) {
          count = Number(match[1]);
        }
      }
    }
  } catch (e) {
    console.error("Failed to fetch live job count:", e);
  }

  const formattedJobs = `${count.toLocaleString()}+`;

  return NextResponse.json({
    ok: true,
    totalJobs: count,
    formattedJobs,
    platformFee: "$0",
    verifiedTalent: "500+",
    activeContracts: "350+",
  });
}
