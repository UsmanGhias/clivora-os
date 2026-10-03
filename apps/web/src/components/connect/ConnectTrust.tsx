"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { CONNECT_CREDIT_COSTS, parseConnectCreditError } from "@/lib/connect-credits";
import type { ConnectMilestone, ConnectReview } from "@/lib/connect";

const MILESTONE_STATUSES = ["pending", "funded", "released", "disputed"] as const;
type MilestoneStatus = (typeof MILESTONE_STATUSES)[number];

function statusBadge(s: string) {
  const map: Record<string, string> = {
    pending: "bg-slate-100 text-slate-700",
    funded: "bg-blue-100 text-blue-800",
    released: "bg-emerald-100 text-emerald-800",
    disputed: "bg-red-100 text-red-800",
  };
  return map[s] ?? "bg-slate-100 text-slate-700";
}

function StarRating({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  return (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          onClick={() => onChange(n)}
          className={`text-xl transition ${n <= value ? "text-amber-400" : "text-slate-300"}`}
        >
          ★
        </button>
      ))}
    </div>
  );
}

function ReviewForm({
  requestId,
  revieweeId,
  onDone,
}: {
  requestId: string;
  revieweeId: string;
  onDone: () => void;
}) {
  const [rating, setRating] = useState(5);
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const { error: err } = await supabase.rpc("connect_submit_review", {
        p_to_user_id: revieweeId,
        p_request_id: requestId,
        p_rating: rating,
        p_body: body.trim() || "",
      });
      if (err) throw err;
      onDone();
    } catch (err) {
      setError(parseConnectCreditError(err).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-2 rounded-xl border border-border bg-surface p-4">
      <p className="text-sm font-semibold text-navy">Leave a review</p>
      <StarRating value={rating} onChange={setRating} />
      <textarea
        rows={2}
        placeholder="Share your experience (optional)"
        value={body}
        onChange={(e) => setBody(e.target.value)}
        className="w-full rounded-xl border border-border px-3 py-2 text-sm"
      />
      {error && <p className="text-sm text-error">{error}</p>}
      <button
        type="submit"
        disabled={busy}
        className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
      >
        {busy ? "Submitting…" : "Submit review"}
      </button>
    </form>
  );
}

function ProposalForm({
  needId,
  toUserId,
  onDone,
}: {
  needId: string;
  toUserId: string;
  onDone: () => void;
}) {
  const [amount, setAmount] = useState("");
  const [timelineDays, setTimelineDays] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const { error: err } = await supabase.rpc("connect_submit_proposal", {
        p_to_user_id: toUserId,
        p_need_id: needId,
        p_amount: amount ? Number(amount) : 0,
        p_currency: "USD",
        p_timeline_days: timelineDays ? Number(timelineDays) : null,
        p_message: message.trim() || "",
      });
      if (err) throw err;
      onDone();
    } catch (err) {
      setError(parseConnectCreditError(err).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-2 rounded-xl border border-border bg-surface p-4">
      <p className="text-sm font-semibold text-navy">Submit proposal</p>
      <div className="grid grid-cols-2 gap-2">
        <input
          type="number"
          min="1"
          placeholder="Amount (USD)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="w-full rounded-xl border border-border px-3 py-2 text-sm"
        />
        <input
          type="number"
          min="1"
          placeholder="Timeline (days)"
          value={timelineDays}
          onChange={(e) => setTimelineDays(e.target.value)}
          className="w-full rounded-xl border border-border px-3 py-2 text-sm"
        />
      </div>
      <textarea
        required
        rows={2}
        placeholder="Message to client…"
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        className="w-full rounded-xl border border-border px-3 py-2 text-sm"
      />
      {error && <p className="text-sm text-error">{error}</p>}
      <button
        type="submit"
        disabled={busy}
        className="rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
      >
        {busy ? "Sending…" : "Send proposal"}
      </button>
    </form>
  );
}

function MilestonesPanel({
  requestId,
  clientUserId,
  freelancerUserId,
}: {
  requestId: string;
  clientUserId: string;
  freelancerUserId: string;
}) {
  const [milestones, setMilestones] = useState<ConnectMilestone[]>([]);
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    const supabase = createClient();
    const { data } = await supabase
      .from("connect_milestones")
      .select("*")
      .eq("engagement_request_id", requestId)
      .order("created_at", { ascending: true });
    setMilestones((data ?? []) as ConnectMilestone[]);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [requestId]);

  async function addMilestone(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error: err } = await supabase.from("connect_milestones").insert({
        engagement_request_id: requestId,
        client_user_id: clientUserId,
        freelancer_user_id: freelancerUserId,
        title: title.trim(),
        amount: amount ? Number(amount) : 0,
        currency: "USD",
        status: "pending",
      });
      if (err) throw err;
      setTitle("");
      setAmount("");
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not add milestone");
    } finally {
      setBusy(false);
    }
  }

  async function updateStatus(id: string, status: MilestoneStatus) {
    setBusy(true);
    try {
      const supabase = createClient();
      const patch: Record<string, string> = {
        status,
        updated_at: new Date().toISOString(),
      };
      if (status === "funded") patch.funded_at = new Date().toISOString();
      if (status === "released") patch.released_at = new Date().toISOString();
      if (status === "disputed") patch.disputed_at = new Date().toISOString();
      const { error: msErr } = await supabase.rpc("connect_transition_milestone", {
        p_milestone_id: id,
        p_status: patch.status,
      });
      if (msErr) throw msErr;
      await load();
    } finally {
      setBusy(false);
    }
  }

  const nextStatus = (current: string): MilestoneStatus | null => {
    const idx = MILESTONE_STATUSES.indexOf(current as MilestoneStatus);
    if (idx < 0 || idx >= MILESTONE_STATUSES.length - 1) return null;
    return MILESTONE_STATUSES[idx + 1];
  };

  return (
    <div className="space-y-3">
      <p className="text-sm font-bold text-navy">Milestones & payment tracking</p>
      {milestones.length === 0 ? (
        <p className="text-sm text-text-secondary">No milestones yet.</p>
      ) : (
        <ul className="space-y-2">
          {milestones.map((m) => {
            const next = nextStatus(m.status);
            return (
              <li
                key={m.id}
                className="flex flex-wrap items-start justify-between gap-2 rounded-xl border border-border bg-white px-3 py-2"
              >
                <div>
                  <p className="text-sm font-semibold">{m.title}</p>
                  <div className="mt-0.5 flex flex-wrap gap-1.5">
                    <span
                      className={`inline-block rounded px-2 py-0.5 text-[10px] font-bold uppercase ${statusBadge(m.status)}`}
                    >
                      {m.status}
                    </span>
                    {m.amount != null && (
                      <span className="text-xs text-text-secondary">
                        ${m.amount} {m.currency}
                      </span>
                    )}
                  </div>
                </div>
                {next && (
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => updateStatus(m.id, next)}
                    className="rounded-lg border border-primary px-2 py-1 text-xs font-semibold text-primary hover:bg-primary/5 disabled:opacity-50"
                  >
                    → {next}
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      )}
      <form
        onSubmit={addMilestone}
        className="space-y-2 rounded-xl border border-dashed border-border bg-background p-3"
      >
        <p className="text-xs font-semibold text-text-secondary">Add milestone</p>
        <div className="grid grid-cols-2 gap-2">
          <input
            required
            placeholder="Title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="rounded-xl border border-border px-3 py-1.5 text-sm"
          />
          <input
            type="number"
            min="0"
            placeholder="Amount"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="rounded-xl border border-border px-3 py-1.5 text-sm"
          />
        </div>
        {error && <p className="text-xs text-error">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="rounded-full bg-navy px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Adding…" : "Add milestone"}
        </button>
      </form>
    </div>
  );
}

function ProposalsInbox({
  needId,
  myUserId,
  requestId,
  clientUserId,
  freelancerUserId,
}: {
  needId: string;
  myUserId: string;
  requestId?: string;
  clientUserId: string;
  freelancerUserId?: string;
}) {
  const [rows, setRows] = useState<
    Array<{
      id: string;
      from_user_id: string;
      to_user_id: string;
      amount: number | null;
      currency: string | null;
      timeline_days: number | null;
      message: string | null;
      status: string;
    }>
  >([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    const supabase = createClient();
    const { data } = await supabase
      .from("connect_proposals")
      .select("id, from_user_id, to_user_id, amount, currency, timeline_days, message, status")
      .eq("need_id", needId)
      .order("created_at", { ascending: false });
    setRows(data ?? []);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [needId]);

  async function accept(proposalId: string, fromUserId: string, amount: number | null) {
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error: err } = await supabase.rpc("connect_accept_proposal", {
        p_proposal_id: proposalId,
      });
      if (err) throw err;

      // Auto-create first milestone for the engagement (free - tracking only)
      if (requestId) {
        const { error: milestoneErr } = await supabase.from("connect_milestones").insert({
          engagement_request_id: requestId,
          client_user_id: clientUserId,
          freelancer_user_id: freelancerUserId || fromUserId,
          title: "Kickoff milestone",
          amount: amount ?? 0,
          currency: "USD",
          status: "pending",
        });
        if (milestoneErr) {
          setError(`Proposal accepted, but kickoff milestone was not created: ${milestoneErr.message}`);
        }
      }
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not accept proposal");
    } finally {
      setBusy(false);
    }
  }

  async function decline(proposalId: string) {
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error: err } = await supabase.rpc("connect_decline_proposal", {
        p_proposal_id: proposalId,
      });
      if (err) throw err;
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not decline proposal");
    } finally {
      setBusy(false);
    }
  }

  const incoming = rows.filter((r) => r.to_user_id === myUserId);
  if (incoming.length === 0) return null;

  return (
    <div className="space-y-2">
      <p className="text-sm font-bold text-navy">Proposals</p>
      {error && <p className="text-xs text-error">{error}</p>}
      <ul className="space-y-2">
        {incoming.map((p) => (
          <li key={p.id} className="rounded-xl border border-border bg-white px-3 py-2">
            <p className="text-sm text-text-secondary">{p.message || "Proposal"}</p>
            <p className="mt-1 text-xs font-semibold text-navy">
              {p.amount != null ? `$${p.amount} ${p.currency || "USD"}` : "Amount TBD"}
              {p.timeline_days ? ` · ${p.timeline_days} days` : ""}
              {" · "}
              {p.status}
            </p>
            {p.status === "pending" && (
              <div className="mt-2 flex gap-2">
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => accept(p.id, p.from_user_id, p.amount)}
                  className="rounded-lg bg-primary px-2 py-1 text-xs font-bold text-white"
                >
                  {requestId ? "Accept → milestone" : "Accept proposal"}
                </button>
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => decline(p.id)}
                  className="rounded-lg border border-border px-2 py-1 text-xs font-bold"
                >
                  Decline
                </button>
              </div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

export function ConnectTrust({
  requestId,
  myUserId,
  peerId,
  needId,
  clientUserId,
  freelancerUserId,
  existingReviews,
  mode,
}: {
  requestId?: string;
  myUserId: string;
  peerId: string;
  needId?: string | null;
  clientUserId?: string | null;
  freelancerUserId?: string | null;
  existingReviews?: ConnectReview[];
  mode: "accepted" | "jobs";
}) {
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [reviewDone, setReviewDone] = useState(false);
  const [proposalDone, setProposalDone] = useState(false);

  const myReview = existingReviews?.find((r) => r.from_user_id === myUserId);
  const resolvedClient = clientUserId || myUserId;
  const resolvedFreelancer = freelancerUserId || peerId;

  return (
    <div className="mt-3 space-y-3 border-t border-border pt-3">
      {mode === "accepted" && (
        <>
          {!myReview && !reviewDone && !showReviewForm && (
            <button
              type="button"
              onClick={() => setShowReviewForm(true)}
              className="rounded-xl bg-amber-50 px-3 py-1.5 text-xs font-semibold text-amber-800 hover:bg-amber-100"
            >
              ★ Leave review
            </button>
          )}
          {showReviewForm && !reviewDone && (
            <ReviewForm
              requestId={requestId || ""}
              revieweeId={peerId}
              onDone={() => {
                setReviewDone(true);
                setShowReviewForm(false);
              }}
            />
          )}
          {(myReview || reviewDone) && (
            <p className="text-xs font-semibold text-green-700">✓ Review submitted</p>
          )}
          {needId && (
            <ProposalsInbox
              needId={needId}
              myUserId={myUserId}
              requestId={requestId}
              clientUserId={resolvedClient}
              freelancerUserId={resolvedFreelancer}
            />
          )}
          <MilestonesPanel
            requestId={requestId || ""}
            clientUserId={resolvedClient}
            freelancerUserId={resolvedFreelancer}
          />
        </>
      )}

      {mode === "jobs" && needId && (
        <>
          {!proposalDone && (
            <Link
              href={`/app/connect/apply?needId=${encodeURIComponent(needId)}&to=${encodeURIComponent(peerId)}&mode=proposal`}
              className="inline-flex rounded-xl bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary-dark hover:bg-primary/20"
            >
              Open full proposal form →
            </Link>
          )}
          {proposalDone && (
            <p className="text-xs font-semibold text-green-700">✓ Proposal sent</p>
          )}
          <ProposalsInbox
            needId={needId}
            myUserId={myUserId}
            clientUserId={peerId}
          />
        </>
      )}
    </div>
  );
}
