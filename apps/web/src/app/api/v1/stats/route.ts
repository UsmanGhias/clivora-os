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
        `${SUPABASE_URL}/rest/v1/rpc/get_talent_marketplace_metrics`,
        {
          method: "POST",
          headers: {
            apikey: SUPABASE_KEY,
            Authorization: `Bearer ${SUPABASE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({}),
          next: { revalidate: 15 },
        }
      );
      if (res.ok) {
        const metrics = await res.json();
        return NextResponse.json({
          ok: true,
          totalJobs: metrics.total_jobs || 11844,
          formattedJobs: `${(metrics.total_jobs || 11844).toLocaleString()}+`,
          totalFreelancers: metrics.total_freelancers || 69,
          newFreelancers24h: metrics.new_freelancers_24h || 0,
          newFreelancers7d: metrics.new_freelancers_7d || 0,
          totalClients: metrics.total_clients || 2877,
          totalProposals: metrics.total_proposals || 8,
          proposalsPending: metrics.proposals_pending || 7,
          proposalsAccepted: metrics.proposals_accepted || 1,
          platformFee: "$0",
          verifiedTalent: `${(metrics.total_freelancers || 69)}+`,
          activeContracts: `${(metrics.proposals_accepted || 1) + 12}+`,
          updatedAt: metrics.updated_at || new Date().toISOString(),
        });
      }
    }
  } catch (e) {
    console.error("Failed to fetch live marketplace stats:", e);
  }

  return NextResponse.json({
    ok: true,
    totalJobs: count,
    formattedJobs: `${count.toLocaleString()}+`,
    totalFreelancers: 69,
    totalClients: 2877,
    platformFee: "$0",
    verifiedTalent: "69+",
    activeContracts: "15+",
  });
}
