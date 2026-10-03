"use client";

import Link from "next/link";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  CheckCircle2,
  MessageSquare,
  Search,
  ShoppingBag,
  Smartphone,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { proposalStatusLabel, type ProposalRow } from "@/lib/connect-proposals-shared";
import { parseConnectCreditError } from "@/lib/connect-credits";
import { cn } from "@/lib/utils";

const TABS = ["all", "pending", "viewed", "shortlisted", "hired", "declined"] as const;

function statusBucket(status: string) {
  const s = status.toLowerCase();
  if (s === "accepted") return "hired";
  if (s === "shortlisted") return "shortlisted";
  if (s === "declined") return "declined";
  if (s === "viewed") return "viewed";
  if (s === "withdrawn") return "declined";
  return "pending";
}

const STATUS_STYLE: Record<string, string> = {
  pending: "bg-amber-100 text-amber-800",
  viewed: "bg-sky-100 text-sky-800",
  shortlisted: "bg-emerald-100 text-emerald-800",
  hired: "bg-primary text-white",
  declined: "bg-red-100 text-red-700",
};

function JobIcon({ title }: { title: string }) {
  const t = title.toLowerCase();
  const Icon = t.includes("mobile") || t.includes("ui") ? Smartphone : ShoppingBag;
  return (
    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
      <Icon className="h-5 w-5" />
    </span>
  );
}

export function FreelancerProposalsPanel({ proposals }: { proposals: ProposalRow[] }) {
  const router = useRouter();
  const [tab, setTab] = useState<(typeof TABS)[number]>("all");
  const [query, setQuery] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const counts = useMemo(() => {
    const fresh = { all: proposals.length, pending: 0, viewed: 0, shortlisted: 0, hired: 0, declined: 0 };
    for (const p of proposals) {
      const b = statusBucket(p.status);
      if (b === "pending") fresh.pending += 1;
      else if (b === "viewed") fresh.viewed += 1;
      else if (b === "shortlisted") fresh.shortlisted += 1;
      else if (b === "hired") fresh.hired += 1;
      else if (b === "declined") fresh.declined += 1;
      else fresh.pending += 1;
    }
    return fresh;
  }, [proposals]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return proposals.filter((p) => {
      const bucket = statusBucket(p.status);
      if (tab !== "all" && bucket !== tab) return false;
      if (!q) return true;
      const hay = [p.need_title, p.to_name, p.message].filter(Boolean).join(" ").toLowerCase();
      return hay.includes(q);
    });
  }, [proposals, tab, query]);

  async function withdraw(id: string) {
    setBusyId(id);
    setActionError(null);
    try {
      const supabase = createClient();
      const { error } = await supabase.rpc("connect_withdraw_proposal", {
        p_proposal_id: id,
      });
      if (error) throw error;
      startTransition(() => router.refresh());
    } catch (e) {
      setActionError(parseConnectCreditError(e).message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy">My proposals</h1>
          <p className="mt-1 text-sm text-text-secondary">
            Track every pitch. Free applies on Connect. Message a client after they hire you.
          </p>
        </div>
        <Link
          href="/app/connect?tab=jobs"
          className="inline-flex items-center justify-center rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white"
        >
          Browse jobs and apply
        </Link>
      </div>

      {actionError && (
        <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">
          {actionError}
        </div>
      )}

      <div className="flex flex-wrap gap-2 border-b border-border pb-2">
        {TABS.map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={cn(
              "rounded-lg px-3 py-1.5 text-sm font-semibold capitalize",
              tab === t
                ? "bg-primary text-white"
                : "text-text-secondary hover:bg-primary/5 hover:text-primary",
            )}
          >
            {t === "all" ? `All (${counts.all})` : `${t} (${counts[t]})`}
          </button>
        ))}
      </div>

      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your proposals…"
          className="w-full rounded-xl border border-border py-2.5 pl-10 pr-3 text-sm outline-none ring-primary focus:ring-2"
        />
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-10 text-center">
          <p className="font-semibold text-navy">No proposals yet</p>
          <p className="mt-2 text-sm text-text-secondary">
            Browse Connect jobs and submit your first proposal.
          </p>
          <Link href="/app/connect" className="mt-4 inline-block text-sm font-semibold text-primary">
            Find jobs →
          </Link>
        </div>
      ) : (
        <ul className="space-y-3">
          {filtered.map((p) => {
            const bucket = statusBucket(p.status);
            const hired = bucket === "hired";
            const canWithdraw =
              bucket === "pending" || bucket === "viewed" || bucket === "shortlisted";
            const busy = busyId === p.id || pending;
            return (
              <li
                key={p.id}
                className="rounded-2xl border border-border bg-surface p-5 shadow-sm transition hover:border-primary/30"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex gap-3">
                    <JobIcon title={p.need_title ?? ""} />
                    <div>
                      <h3 className="font-bold text-navy">{p.need_title}</h3>
                      <p className="text-xs text-text-muted">
                        {p.need_budget || "Fixed price"} · Posted{" "}
                        {new Date(p.created_at).toLocaleDateString()}
                      </p>
                      <p className="mt-2 font-display text-lg font-extrabold text-primary">
                        ${Number(p.amount ?? 0).toLocaleString()}{" "}
                        <span className="text-sm font-semibold text-text-secondary">your bid</span>
                      </p>
                      <p className="mt-2 line-clamp-2 text-sm text-text-secondary">
                        {p.message || "No cover letter saved."}
                      </p>
                      <p className="mt-1 inline-flex items-center gap-1 text-xs text-text-secondary">
                        Client: {hired ? p.to_name || "Client" : "Hidden until hire"}
                        {hired && (
                          <>
                            <CheckCircle2 className="h-3.5 w-3.5 text-success" />
                            <span className="text-success">Hired</span>
                          </>
                        )}
                      </p>
                    </div>
                  </div>
                  <span
                    className={cn(
                      "shrink-0 rounded-lg px-2.5 py-1 text-[10px] font-bold uppercase",
                      STATUS_STYLE[bucket] ?? STATUS_STYLE.pending,
                    )}
                  >
                    {proposalStatusLabel(p.status)}
                  </span>
                </div>
                <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-4">
                  {!hired ? (
                    canWithdraw && (
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => void withdraw(p.id)}
                        className="text-sm font-semibold text-text-secondary disabled:opacity-50"
                      >
                        Withdraw
                      </button>
                    )
                  ) : (
                    <Link
                      href="/app/projects"
                      className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white"
                    >
                      View project
                    </Link>
                  )}
                  {hired ? (
                    <Link
                      href={`/app/messages?to=${encodeURIComponent(p.to_user_id)}`}
                      className="ml-auto inline-flex items-center gap-1 text-sm font-semibold text-primary"
                    >
                      <MessageSquare className="h-4 w-4" />
                      Message client
                    </Link>
                  ) : (
                    <span className="ml-auto text-xs text-text-muted">
                      Messaging unlocks after the client hires you
                    </span>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
