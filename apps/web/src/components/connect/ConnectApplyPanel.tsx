"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  FileText,
  Link2,
  Send,
  ShieldAlert,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { CONNECT_CREDIT_COSTS, parseConnectCreditError } from "@/lib/connect-credits";
import { cn } from "@/lib/utils";

type NeedDetail = {
  id: string;
  title: string;
  summary: string;
  skills: string[];
  budget_band: string | null;
  client_user_id: string;
};

const URL_REGEX = /https?:\/\/[^\s]+|www\.[^\s]+/gi;

function detectUrls(text: string): string[] {
  return Array.from(new Set((text.match(URL_REGEX) ?? []).map((u) => u.trim())));
}

export function ConnectApplyPanel() {
  const router = useRouter();
  const params = useSearchParams();
  const needId = params.get("needId") ?? "";
  const jobId = params.get("job_id") ?? params.get("jobId") ?? "";
  const peerId = params.get("to") ?? "";
  const mode = (params.get("mode") ?? "proposal") as "proposal" | "contact";

  const [loading, setLoading] = useState(true);
  const [need, setNeed] = useState<NeedDetail | null>(null);
  const [jobInfo, setJobInfo] = useState<{
    id: string;
    title: string;
    company_name: string;
    company_email?: string | null;
    description: string;
    salary?: string;
    posted_by?: string | null;
    source_url?: string | null;
  } | null>(null);
  const [amount, setAmount] = useState("");
  const [timelineDays, setTimelineDays] = useState("");
  const [coverLetter, setCoverLetter] = useState("");
  const [portfolioLinks, setPortfolioLinks] = useState("");
  const [approach, setApproach] = useState("");
  const [milestones, setMilestones] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [planOk, setPlanOk] = useState(false);
  const [reviewUrl, setReviewUrl] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const combinedText = useMemo(
    () => [coverLetter, approach, portfolioLinks, milestones].join("\n"),
    [coverLetter, approach, portfolioLinks, milestones],
  );
  const foundUrls = useMemo(() => detectUrls(combinedText), [combinedText]);

  useEffect(() => {
    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.replace(`/login?next=/app/connect/apply?job_id=${encodeURIComponent(jobId)}&needId=${encodeURIComponent(needId)}&mode=${mode}`);
        return;
      }
      const { data: profile } = await supabase
        .from("profiles")
        .select("subscription_plan, account_type, is_blocked, is_restricted")
        .eq("id", user.id)
        .maybeSingle();
      if (profile?.is_blocked) {
        router.replace("/blocked");
        return;
      }
      setPlanOk(true);

      if (jobId) {
        const { data: jData } = await supabase
          .from("connect_jobs")
          .select("id, title, company_name, company_email, description, salary_min, salary_max, currency, posted_by, source_url")
          .eq("id", jobId)
          .maybeSingle();
        if (jData) {
          const salary = jData.salary_min && jData.salary_max
            ? `$${jData.salary_min.toLocaleString()} - $${jData.salary_max.toLocaleString()} USD`
            : jData.salary_min
              ? `$${jData.salary_min.toLocaleString()} USD`
              : undefined;
          setJobInfo({
            id: jData.id,
            title: jData.title,
            company_name: jData.company_name,
            company_email: jData.company_email,
            description: jData.description,
            salary,
            posted_by: jData.posted_by,
            source_url: jData.source_url,
          });
        }
      }

      if (needId) {
        const { data } = await supabase
          .from("connect_need_posts")
          .select("id, title, summary, skills, budget_band, client_user_id")
          .eq("id", needId)
          .maybeSingle();
        if (data) {
          setNeed({
            id: data.id,
            title: data.title ?? "",
            summary: data.summary ?? "",
            skills: Array.isArray(data.skills)
              ? data.skills
              : String(data.skills ?? "")
                  .split(",")
                  .map((s) => s.trim())
                  .filter(Boolean),
            budget_band: data.budget_band,
            client_user_id: data.client_user_id,
          });
        }
      }
      setLoading(false);
    })();
  }, [jobId, needId, mode, router]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!planOk) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setBusy(false);
      return;
    }

    const targetUserId = peerId || need?.client_user_id || jobInfo?.posted_by || null;

    if (!targetUserId && !jobInfo) {
      setError("Missing recipient. Open this page from a Connect job card.");
      setBusy(false);
      return;
    }

    if (mode === "contact") {
      if (!targetUserId) {
        setError("This role accepts direct proposals. Please use the Submit Proposal tab.");
        setBusy(false);
        return;
      }
      if (coverLetter.trim().length < 20) {
        setError("Add a short introduction (at least a couple of sentences).");
        setBusy(false);
        return;
      }
      const contactMessage = [
        coverLetter.trim(),
        approach.trim() ? `\n\nWhy this job:\n${approach.trim()}` : "",
        timelineDays ? `\n\nAvailable to start in: ${timelineDays} day(s)` : "",
        portfolioLinks.trim() ? `\n\nProof / links:\n${portfolioLinks.trim()}` : "",
        "\n\n- CLIVORA Contact request (emails unlock after mutual accept)",
      ]
        .filter(Boolean)
        .join("");
      const { error: err } = await supabase.rpc("connect_send_request", {
        p_to_user_id: targetUserId,
        p_message: contactMessage.trim(),
        p_target_need_id: needId || null,
      });
      setBusy(false);
      if (err) {
        setError(parseConnectCreditError(err).message);
        return;
      }
      setDone(true);
      return;
    }

    const messageParts = [
      coverLetter.trim(),
      approach.trim() ? `\n\nApproach:\n${approach.trim()}` : "",
      milestones.trim() ? `\n\nMilestones:\n${milestones.trim()}` : "",
      portfolioLinks.trim() ? `\n\nLinks:\n${portfolioLinks.trim()}` : "",
      foundUrls.length
        ? `\n\n[Note: URLs included - CLIVORA may analyze links and remove listings that violate trust & safety.]`
        : "",
    ]
      .filter(Boolean)
      .join("");

    if (messageParts.trim().length < 40) {
      setError("Please share a stronger proposal (at least a few sentences of detail).");
      setBusy(false);
      return;
    }

    let proposalId: string | undefined;

    if (jobInfo) {
      const { data: pData, error: pErr } = await supabase
        .from("connect_proposals")
        .insert({
          from_user_id: user.id,
          to_user_id: targetUserId,
          job_id: jobInfo.id,
          amount: amount ? Number(amount) : 0,
          currency: "USD",
          timeline_days: timelineDays ? Number(timelineDays) : 7,
          message: messageParts.trim(),
          status: "pending",
          client_name: jobInfo.company_name,
          client_email: jobInfo.company_email,
        })
        .select("id")
        .single();

      if (pErr) {
        setBusy(false);
        setError(pErr.message || "Failed to submit proposal");
        return;
      }
      proposalId = pData?.id;
    } else {
      const { data: pRes, error: err } = await supabase.rpc("connect_submit_proposal", {
        p_to_user_id: targetUserId || user.id,
        p_need_id: needId || null,
        p_amount: amount ? Number(amount) : 0,
        p_currency: "USD",
        p_timeline_days: timelineDays ? Number(timelineDays) : null,
        p_message: messageParts.trim(),
      });
      if (err) {
        setBusy(false);
        setError(parseConnectCreditError(err).message);
        return;
      }
      proposalId = typeof pRes === "string" ? pRes : undefined;
    }

    // Dispatch background client notification email
    if (proposalId) {
      void (async () => {
        try {
          const res = await fetch("/api/connect/notify-client-proposal", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              proposalId,
              jobId: jobInfo?.id,
              toUserId: targetUserId,
              companyEmail: jobInfo?.company_email,
              companyName: jobInfo?.company_name,
              jobTitle: jobInfo?.title || need?.title,
              amount: amount ? Number(amount) : 0,
              timelineDays: timelineDays ? Number(timelineDays) : 7,
              pitchMessage: messageParts.trim(),
            }),
          });
          const data = await res.json().catch(() => ({}));
          if (data?.reviewUrl) {
            setReviewUrl(data.reviewUrl);
          }
        } catch (e) {
          console.error("Client email notification error:", e);
        }
      })();
    }

    setBusy(false);
    setDone(true);
  }

  if (loading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center text-sm text-text-secondary">
        Loading application…
      </div>
    );
  }

  if (done) {
    return (
      <div className="mx-auto max-w-2xl rounded-2xl border border-border bg-surface p-8 text-center shadow-sm">
        <CheckCircle2 className="mx-auto h-12 w-12 text-primary" />
        <h1 className="mt-4 font-display text-2xl font-extrabold text-navy">
          {mode === "contact" ? "Contact request sent" : "Proposal submitted"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          (−{CONNECT_CREDIT_COSTS[mode === "contact" ? "contact" : "proposal"]} Connect credit)
          The hiring team is notified to review your proposal privately.
        </p>

        {reviewUrl && (
          <div className="mt-6 rounded-xl border border-border bg-slate-50 p-4 text-left">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-500">
              1-Click Client Review Link
            </p>
            <p className="mt-1 text-xs text-slate-600">
              Share this link directly with the hiring manager or in external outreach. It tracks views automatically and lets the client review your bid with $0 platform fees.
            </p>
            <div className="mt-3 flex items-center gap-2">
              <input
                type="text"
                readOnly
                value={reviewUrl}
                className="flex-1 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-mono text-slate-700 select-all"
              />
              <button
                type="button"
                onClick={() => {
                  void navigator.clipboard.writeText(reviewUrl);
                  setCopied(true);
                  setTimeout(() => setCopied(false), 2500);
                }}
                className="rounded-lg bg-teal-700 px-3 py-2 text-xs font-bold text-white hover:bg-teal-800 transition-colors shrink-0"
              >
                {copied ? "Copied!" : "Copy Link"}
              </button>
            </div>
          </div>
        )}

        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link
            href="/app/proposals"
            className="rounded-xl bg-primary px-5 py-2.5 text-sm font-bold text-white"
          >
            View proposals
          </Link>
          <Link
            href="/app/connect"
            className="rounded-xl border border-border px-5 py-2.5 text-sm font-semibold text-navy"
          >
            Back to Connect
          </Link>
        </div>
      </div>
    );
  }

  if (!jobInfo && !need && !peerId) {
    return (
      <div className="space-y-6 pb-10">
        <div>
          <Link
            href="/app/connect"
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Connect
          </Link>
          <h1 className="mt-3 font-display text-2xl font-extrabold text-navy sm:text-3xl">
            Submit a Proposal
          </h1>
          <p className="mt-2 max-w-2xl text-sm text-text-secondary">
            Proposals are attached to specific job briefs or client needs.
          </p>
        </div>

        <div className="mx-auto max-w-2xl rounded-3xl border border-border bg-surface p-8 text-center shadow-xs space-y-4">
          <div className="mx-auto h-14 w-14 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center">
            <FileText className="h-7 w-7" />
          </div>
          <h2 className="text-xl font-bold text-navy">Choose an Open Job First</h2>
          <p className="text-sm text-text-secondary max-w-md mx-auto leading-relaxed">
            To submit a tailored proposal with milestones and pricing, browse our open remote roles or client briefs and click &quot;Apply ($0 Fee)&quot;.
          </p>
          <div className="pt-3 flex flex-wrap justify-center gap-3">
            <Link
              href="/app/connect?tab=jobs"
              className="rounded-xl bg-teal-700 hover:bg-teal-800 px-5 py-2.5 text-sm font-bold text-white shadow-xs transition-colors"
            >
              Browse Connect Jobs
            </Link>
            <Link
              href="/jobs"
              className="rounded-xl border border-border bg-white px-5 py-2.5 text-sm font-semibold text-navy hover:bg-slate-50 transition-colors"
            >
              Browse Remote Jobs Board
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 pb-10">
      <div>
        <Link
          href="/app/connect"
          className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to Connect
        </Link>
        <h1 className="mt-3 font-display text-2xl font-extrabold text-navy sm:text-3xl">
          {mode === "contact" ? "Contact the client" : "Submit a proposal"}
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-text-secondary">
          {mode === "contact"
            ? "Send a private Connect request. Emails unlock only after both sides accept. Use Submit proposal when you have a priced offer."
            : "Share a complete pitch with scope, timeline, milestones, and proof of fit - not just a one-line hello."}
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)]">
        <form onSubmit={onSubmit} className="space-y-5 rounded-2xl border border-border bg-surface p-5 shadow-sm sm:p-6">
          {jobInfo && (
            <div className="rounded-2xl border border-teal-200 bg-gradient-to-br from-teal-50 to-white p-5 shadow-xs">
              <div className="flex items-center justify-between">
                <p className="text-xs font-bold uppercase tracking-wider text-teal-700">Marketplace Role</p>
                <span className="text-xs font-bold text-teal-800 bg-teal-100 px-2.5 py-0.5 rounded-full">$0 Platform Fee</span>
              </div>
              <p className="mt-1.5 font-display text-lg font-extrabold text-navy">{jobInfo.title}</p>
              <p className="text-xs font-semibold text-slate-500 mt-0.5">{jobInfo.company_name}</p>
              {jobInfo.salary && (
                <p className="mt-2 text-xs font-bold text-teal-700 font-mono">{jobInfo.salary}</p>
              )}
              {jobInfo.source_url && (
                <div className="mt-2.5 pt-2 border-t border-teal-200/60">
                  <a
                    href={jobInfo.source_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-[11px] font-semibold text-teal-700 hover:text-teal-800 underline"
                  >
                    View Original Employer Post &rarr;
                  </a>
                </div>
              )}
            </div>
          )}

          {need && !jobInfo && (
            <div className="rounded-xl border border-teal-100 bg-teal-50/60 p-4">
              <p className="text-xs font-bold uppercase tracking-wide text-primary">Applying to</p>
              <p className="mt-1 font-display text-lg font-bold text-navy">{need.title}</p>
              <p className="mt-2 text-sm text-text-secondary line-clamp-4">{need.summary}</p>
              <div className="mt-3 flex flex-wrap gap-2">
                {need.budget_band && (
                  <span className="rounded-full bg-white px-2.5 py-1 text-xs font-semibold text-navy">
                    {need.budget_band}
                  </span>
                )}
                {need.skills.slice(0, 6).map((s) => (
                  <span key={s} className="rounded-full bg-white px-2.5 py-1 text-xs text-slate-600">
                    {s}
                  </span>
                ))}
              </div>
            </div>
          )}

          <label className="block">
            <span className="text-sm font-semibold text-navy">
              {mode === "contact" ? "Introduction *" : "Cover letter *"}
            </span>
            <textarea
              required
              rows={mode === "contact" ? 5 : 6}
              value={coverLetter}
              onChange={(e) => setCoverLetter(e.target.value)}
              placeholder={
                mode === "contact"
                  ? "Who you are, why this job fits, and one relevant win…"
                  : "Why you're the right fit, relevant experience, and how you'll deliver…"
              }
              className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
            />
          </label>

          <label className="block">
            <span className="text-sm font-semibold text-navy">
              {mode === "contact" ? "Why this job / fit" : "Your approach"}
            </span>
            <textarea
              rows={4}
              value={approach}
              onChange={(e) => setApproach(e.target.value)}
              placeholder={
                mode === "contact"
                  ? "What you'd clarify on a call, questions, or how you'd help…"
                  : "Phases, tools, communication cadence…"
              }
              className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
            />
          </label>

          {mode === "proposal" && (
            <label className="block">
              <span className="text-sm font-semibold text-navy">Suggested milestones</span>
              <textarea
                rows={3}
                value={milestones}
                onChange={(e) => setMilestones(e.target.value)}
                placeholder={"1. Discovery & wireframes\n2. Build & review\n3. Launch & handoff"}
                className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
              />
            </label>
          )}

          {mode === "contact" && (
            <label className="block">
              <span className="text-sm font-semibold text-navy">Days until you can start</span>
              <input
                type="number"
                min={0}
                step="1"
                value={timelineDays}
                onChange={(e) => setTimelineDays(e.target.value)}
                placeholder="e.g. 3"
                className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
              />
            </label>
          )}

          {mode === "proposal" && (
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="block">
                <span className="text-sm font-semibold text-navy">Proposed amount (USD)</span>
                <input
                  type="number"
                  min={0}
                  step="1"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="e.g. 2500"
                  className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
                />
              </label>
              <label className="block">
                <span className="text-sm font-semibold text-navy">Timeline (days)</span>
                <input
                  type="number"
                  min={1}
                  step="1"
                  value={timelineDays}
                  onChange={(e) => setTimelineDays(e.target.value)}
                  placeholder="e.g. 21"
                  className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
                />
              </label>
            </div>
          )}

          <label className="block">
            <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-navy">
              <Link2 className="h-4 w-4" />
              Portfolio / reference links
            </span>
            <textarea
              rows={3}
              value={portfolioLinks}
              onChange={(e) => setPortfolioLinks(e.target.value)}
              placeholder="https://… (optional - one per line)"
              className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm"
            />
          </label>

          {foundUrls.length > 0 && (
            <div className="flex gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
              <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-amber-600" />
              <div>
                <p className="font-bold">URL safety notice</p>
                <p className="mt-1 text-amber-900/90">
                  We detected {foundUrls.length} link{foundUrls.length === 1 ? "" : "s"}. CLIVORA may
                  analyze shared URLs for phishing, spam, or policy abuse. Profiles or posts that
                  share harmful links can be removed and accounts restricted.
                </p>
              </div>
            </div>
          )}

          {error && (
            <p className="rounded-xl bg-error/10 px-3 py-2 text-sm text-error">{error}</p>
          )}

          <button
            type="submit"
            disabled={busy}
            className={cn(
              "inline-flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-bold text-white shadow-md shadow-primary/20 sm:w-auto",
              busy && "opacity-70",
            )}
          >
            <Send className="h-4 w-4" />
            {busy
              ? "Sending…"
              : mode === "contact"
                ? `Send contact (−${CONNECT_CREDIT_COSTS.contact} credit)`
                : `Submit proposal (−${CONNECT_CREDIT_COSTS.proposal} credit)`}
          </button>
        </form>

        <aside className="space-y-4">
          <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
            <p className="inline-flex items-center gap-2 text-sm font-bold text-navy">
              <FileText className="h-4 w-4 text-primary" />
              What great proposals include
            </p>
            <ul className="mt-3 space-y-2 text-sm text-text-secondary">
              <li>• Clear understanding of the brief</li>
              <li>• Relevant past work (links welcome)</li>
              <li>• Realistic timeline & budget</li>
              <li>• Milestone plan the client can approve</li>
              <li>• No spam - quality over speed</li>
            </ul>
          </div>
          <div className="rounded-2xl border border-amber-100 bg-amber-50/80 p-5">
            <p className="inline-flex items-center gap-2 text-sm font-bold text-amber-950">
              <AlertTriangle className="h-4 w-4 text-amber-600" />
              Trust & privacy
            </p>
            <p className="mt-2 text-sm text-amber-950/90">
              Contact details unlock only after mutual acceptance. Sharing phone/email in the pitch
              may be filtered. Malicious URLs can trigger profile removal.
            </p>
          </div>
        </aside>
      </div>
    </div>
  );
}
