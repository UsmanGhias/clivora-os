import type { Metadata } from "next";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import {
  CheckCircle2,
  DollarSign,
  Clock,
  Briefcase,
  ShieldCheck,
  MessageSquare,
  Sparkles,
  ExternalLink,
  Lock,
} from "lucide-react";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Review Candidate Proposal - CLIVORA",
  description: "Review freelancer proposal on CLIVORA with $0 platform fees.",
};

export default async function ReviewProposalPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const sp = await searchParams;
  const token = sp.token;

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!token) {
    // If logged in, fetch their recent proposals
    let recentProposals: Array<{ id: string; client_name?: string | null; amount?: number | null; created_at: string; review_token?: string | null }> = [];
    if (user) {
      const { data } = await supabase
        .from("connect_proposals")
        .select("id, client_name, amount, created_at, review_token")
        .or(`to_user_id.eq.${user.id},from_user_id.eq.${user.id}`)
        .order("created_at", { ascending: false })
        .limit(5);
      recentProposals = data ?? [];
    }

    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center p-6">
        <div className="max-w-lg w-full rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-sm space-y-5">
          <div className="mx-auto h-12 w-12 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center">
            <Sparkles className="h-6 w-6" />
          </div>
          <h1 className="text-xl font-bold text-slate-900">Review Candidate Proposals</h1>
          <p className="text-sm text-slate-600 max-w-sm mx-auto">
            Hiring clients receive unique magic review links in their email notification when a freelancer submits a proposal.
          </p>

          {recentProposals.length > 0 && (
            <div className="text-left border-t border-slate-100 pt-4 space-y-2">
              <p className="text-xs font-bold uppercase tracking-wider text-slate-400">Your Recent Proposals</p>
              <div className="space-y-1.5">
                {recentProposals.map((p) => (
                  <Link
                    key={p.id}
                    href={p.review_token ? `/connect/review?token=${p.review_token}` : "/app/proposals"}
                    className="flex items-center justify-between p-3 rounded-xl border border-slate-100 hover:border-teal-300 hover:bg-teal-50/50 transition-colors text-xs font-semibold text-slate-800"
                  >
                    <span>{p.client_name || "Proposal"} · ${p.amount || 0} USD</span>
                    <span className="text-teal-700">Review →</span>
                  </Link>
                ))}
              </div>
            </div>
          )}

          <div className="pt-2 flex flex-wrap justify-center gap-3">
            <Link
              href="/app/proposals"
              className="rounded-xl bg-teal-700 hover:bg-teal-800 px-5 py-2.5 text-xs font-bold text-white shadow-xs transition-colors"
            >
              Open Proposals Portal
            </Link>
            <Link
              href="/connect"
              className="rounded-xl border border-slate-200 bg-white hover:bg-slate-50 px-5 py-2.5 text-xs font-semibold text-slate-700 transition-colors"
            >
              Go to Connect
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // Secure token-scoped lookup via RPC (marks read receipt atomically)
  const { data: rows, error: rpcErr } = await supabase.rpc(
    "connect_proposal_by_review_token",
    { p_token: token.trim() },
  );

  const proposal = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;

  if (!proposal || rpcErr) {
    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center p-6">
        <div className="max-w-md w-full rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm">
          <h1 className="text-xl font-bold text-slate-900">Proposal Not Found or Expired</h1>
          <p className="mt-2 text-sm text-slate-600">
            This review link is invalid or the proposal has been updated.
          </p>
          <Link
            href="/connect"
            className="mt-6 inline-block rounded-xl bg-teal-700 px-5 py-2.5 text-sm font-bold text-white hover:bg-teal-800"
          >
            Explore CLIVORA Connect
          </Link>
        </div>
      </main>
    );
  }

  const freelancerName = proposal.freelancer_name || "Verified Freelancer";
  const jobTitle = proposal.job_title || "Project Opportunity";
  const companyName = proposal.job_company || proposal.client_name || "Your Company";

  return (
    <main className="min-h-screen bg-slate-50 py-12 px-4 sm:px-6">
      <div className="max-w-3xl mx-auto space-y-6">
        {/* Banner */}
        <div className="rounded-3xl border border-teal-200 bg-gradient-to-r from-teal-900 via-slate-900 to-navy p-6 sm:p-8 text-white shadow-xl">
          <div className="inline-flex items-center gap-2 rounded-full bg-teal-500/20 border border-teal-400/30 px-3.5 py-1 text-xs font-bold text-teal-300">
            <Sparkles className="h-3.5 w-3.5" />
            <span>0% Platform Commission - $0 Fee Guaranteed</span>
          </div>
          <h1 className="mt-3 text-2xl sm:text-3xl font-extrabold tracking-tight">
            Proposal for {jobTitle}
          </h1>
          <p className="mt-1 text-sm text-slate-300">
            Submitted to <strong>{companyName}</strong> via CLIVORA Connect Marketplace
          </p>
        </div>

        {/* Read Receipt Notice */}
        <div className="flex items-center gap-2 rounded-xl bg-teal-50 border border-teal-200/80 px-4 py-2.5 text-xs text-teal-900 font-medium">
          <CheckCircle2 className="h-4 w-4 text-teal-600 shrink-0" />
          <span>
            Read receipt recorded: The freelancer has been notified that you opened their proposal.
          </span>
        </div>

        {/* Candidate & Bid Card */}
        <div className="rounded-3xl border border-slate-200 bg-white p-6 sm:p-8 shadow-sm space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 border-b border-slate-100">
            <div className="flex items-center gap-3.5">
              <div className="h-14 w-14 rounded-2xl bg-gradient-to-br from-teal-600 to-slate-800 text-white font-black text-xl flex items-center justify-center shadow-md">
                {freelancerName.slice(0, 2).toUpperCase()}
              </div>
              <div>
                <h2 className="text-lg font-bold text-slate-900">{freelancerName}</h2>
                <span className="inline-flex items-center gap-1 text-xs font-semibold text-teal-700 bg-teal-50 px-2.5 py-0.5 rounded-full mt-0.5">
                  <ShieldCheck className="h-3 w-3" />
                  Verified Freelancer
                </span>
              </div>
            </div>

            <div className="flex items-center gap-4">
              <div className="rounded-2xl bg-slate-50 border border-slate-200/80 px-4 py-2.5 text-right">
                <span className="text-[10px] font-bold uppercase text-slate-500 block">Proposed Bid</span>
                <span className="text-xl font-extrabold text-slate-900 font-mono">
                  ${Number(proposal.amount || 0).toLocaleString()} USD
                </span>
              </div>
              {proposal.timeline_days && (
                <div className="rounded-2xl bg-slate-50 border border-slate-200/80 px-4 py-2.5 text-right">
                  <span className="text-[10px] font-bold uppercase text-slate-500 block">Timeline</span>
                  <span className="text-base font-bold text-slate-900 flex items-center justify-end gap-1">
                    <Clock className="h-3.5 w-3.5 text-slate-400" />
                    {proposal.timeline_days} Days
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Proposal Message / Pitch */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Candidate Pitch & Cover Note
            </h3>
            <div className="rounded-2xl bg-slate-50 border border-slate-100 p-5 text-sm text-slate-700 leading-relaxed whitespace-pre-line">
              {proposal.message || "No pitch message attached."}
            </div>
          </div>

          {/* Value Props & Protection */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
            <div className="rounded-2xl border border-slate-100 bg-slate-50/60 p-4 text-center">
              <DollarSign className="h-5 w-5 text-teal-600 mx-auto" />
              <p className="mt-1 text-xs font-bold text-slate-900">0% Commission</p>
              <p className="text-[11px] text-slate-500 mt-0.5">Pay $0 marketplace fee</p>
            </div>
            <div className="rounded-2xl border border-slate-100 bg-slate-50/60 p-4 text-center">
              <Lock className="h-5 w-5 text-teal-600 mx-auto" />
              <p className="mt-1 text-xs font-bold text-slate-900">100% Private</p>
              <p className="text-[11px] text-slate-500 mt-0.5">Safe mutual matching</p>
            </div>
            <div className="rounded-2xl border border-slate-100 bg-slate-50/60 p-4 text-center">
              <ShieldCheck className="h-5 w-5 text-teal-600 mx-auto" />
              <p className="mt-1 text-xs font-bold text-slate-900">Milestone Tracking</p>
              <p className="text-[11px] text-slate-500 mt-0.5">Approve on satisfaction</p>
            </div>
          </div>

          {/* CTA Actions */}
          <div className="pt-4 border-t border-slate-100 flex flex-col sm:flex-row items-center gap-3">
            <Link
              href={`/signup?role=client&next=/app/messages?to=${encodeURIComponent(proposal.freelancer_id || proposal.from_user_id || "")}`}
              className="w-full sm:w-auto flex-1 inline-flex items-center justify-center gap-2 rounded-2xl bg-teal-700 px-6 py-4 text-sm font-bold text-white shadow-lg shadow-teal-700/20 hover:bg-teal-800 transition-all text-center"
            >
              <MessageSquare className="h-4 w-4" />
              Accept & Start Direct Chat ($0 Fee)
            </Link>
            <Link
              href="/signup?role=client"
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-5 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
            >
              Post Another Job Free
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
