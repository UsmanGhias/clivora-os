"use client";

import { site } from "@/lib/site";
import { useState } from "react";
import Link from "next/link";
import {
  Send,
  ExternalLink,
  Mail,
  Copy,
  Check,
  ShieldCheck,
  Sparkles,
  MessageSquare,
  MessageCircle,
  Share2,
  ArrowUpRight,
  Briefcase,
} from "lucide-react";

interface DirectClientContactCardProps {
  jobId: string;
  jobTitle: string;
  companyName: string;
  companyDomain?: string | null;
  companyEmail?: string | null;
  sourceUrl?: string | null;
  location?: string;
  salaryText?: string;
}

export function DirectClientContactCard({
  jobId,
  jobTitle,
  companyName,
  companyDomain,
  companyEmail,
  sourceUrl,
  location = "Remote",
  salaryText = "Competitive Pay",
}: DirectClientContactCardProps) {
  const [copiedPitch, setCopiedPitch] = useState(false);
  const [copiedJobUrl, setCopiedJobUrl] = useState(false);
  const [showPitchModal, setShowPitchModal] = useState(false);

  const cleanPitch = `Hi ${companyName} Hiring Team,

I noticed your opening for ${jobTitle} on CLIVORA Connect. With proven experience delivering high-ticket, scalable systems, I would love to explore how I can add immediate value to this project.

Key Strengths:
- Rapid project execution & clean, production-grade architecture
- Direct milestone delivery with 100% transparency
- Available for ${location.includes("Remote") ? "remote" : location} engagement

Looking forward to connecting!

Best regards,`;

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(cleanPitch);
      setCopiedPitch(true);
      setTimeout(() => setCopiedPitch(false), 2500);
    } catch {
      // fallback
    }
  };

  const shareJob = async () => {
    const url = typeof window !== "undefined" ? window.location.href : `${site.url}/jobs/view/${jobId}`;
    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: `${jobTitle} at ${companyName}`,
          text: `Remote role on CLIVORA: ${jobTitle} at ${companyName} (${salaryText}) - $0 Platform Fee: ${url}`,
          url,
        });
        return;
      } catch {
        // Fallback to clipboard
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      setCopiedJobUrl(true);
      setTimeout(() => setCopiedJobUrl(false), 2000);
    } catch {
      // fallback
    }
  };

  const sharePitchOnWhatsApp = () => {
    window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(cleanPitch)}`, "_blank", "noopener,noreferrer");
  };

  return (
    <div className="space-y-5">
      {/* Primary Apply Card */}
      <div className="rounded-3xl border border-teal-500/40 bg-gradient-to-b from-white via-teal-50/10 to-teal-50/30 p-6 shadow-sm">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 text-teal-800">
            <Send className="h-5 w-5 text-teal-600" />
            <h3 className="text-base font-bold">Apply & Contact</h3>
          </div>
          <span className="inline-flex items-center gap-1 rounded-full bg-teal-100/80 px-2.5 py-0.5 text-[11px] font-bold text-teal-800">
            {sourceUrl ? "Curated Opening" : "Clivora Client"}
          </span>
        </div>

        <p className="mt-2.5 text-xs text-slate-600 leading-relaxed">
          {sourceUrl
            ? `Apply directly with ${companyName} on their official portal, or submit your proposal directly on Clivora with $0 platform take rates.`
            : "Submit your proposal directly to the client. Zero platform commissions, direct milestone tracking, and 100% retained earnings."}
        </p>

        {/* Action Buttons */}
        <div className="mt-5 space-y-2.5">
          {/* Action 1: Official Portal (if external) or Submit on Clivora (if internal) */}
          {sourceUrl ? (
            <>
              <a
                href={sourceUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex w-full items-center justify-center gap-2 rounded-2xl bg-teal-600 px-5 py-3.5 text-sm font-bold text-white shadow-sm transition-all hover:bg-teal-700 hover:shadow active:scale-98"
              >
                <ExternalLink className="h-4 w-4" />
                Apply on Official Company Portal
              </a>
              <Link
                href={`/app/connect/apply?job_id=${jobId}&title=${encodeURIComponent(jobTitle)}`}
                className="flex w-full items-center justify-center gap-2 rounded-2xl border border-slate-300 bg-white px-5 py-3 text-xs font-bold text-slate-700 shadow-2xs transition-all hover:border-teal-500 hover:bg-slate-50 hover:text-teal-700"
              >
                <Send className="h-3.5 w-3.5 text-teal-600" />
                Submit via Clivora Connect ($0 Fee)
              </Link>
            </>
          ) : (
            <Link
              href={`/app/connect/apply?job_id=${jobId}&title=${encodeURIComponent(jobTitle)}`}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-teal-600 px-5 py-3.5 text-sm font-bold text-white shadow-sm transition-all hover:bg-teal-700 hover:shadow active:scale-98"
            >
              <Send className="h-4 w-4" />
              Submit Proposal ($0 Fee)
            </Link>
          )}

          {/* Action 2: Direct Email (if available) */}
          {companyEmail && (
            <a
              href={`mailto:${companyEmail}?subject=Application for ${encodeURIComponent(jobTitle)} via CLIVORA`}
              className="flex w-full items-center justify-center gap-2 rounded-2xl border border-teal-200 bg-teal-50/80 px-5 py-3 text-xs font-bold text-teal-800 transition-all hover:bg-teal-100"
            >
              <Mail className="h-3.5 w-3.5 text-teal-600" />
              Email Hiring Contact Directly
            </a>
          )}

          {/* Action 3: Quick Share & Copy Link */}
          <button
            type="button"
            onClick={shareJob}
            className="flex w-full items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-5 py-2.5 text-xs font-bold text-slate-700 shadow-2xs transition-all hover:bg-slate-50 hover:text-navy hover:border-slate-300"
          >
            {copiedJobUrl ? (
              <>
                <Check className="h-4 w-4 text-emerald-600" />
                <span className="text-emerald-700 font-bold">Link Copied to Clipboard!</span>
              </>
            ) : (
              <>
                <Share2 className="h-4 w-4 text-slate-500" />
                <span>Share Opportunity Link</span>
              </>
            )}
          </button>
        </div>

        {/* 1-Click Tailored Outreach Pitch Assistant */}
        <div className="mt-5 border-t border-slate-200/80 pt-4">
          <button
            type="button"
            onClick={() => setShowPitchModal(!showPitchModal)}
            className="flex w-full items-center justify-between text-xs font-semibold text-teal-700 hover:text-teal-800"
          >
            <span className="flex items-center gap-1.5">
              <Sparkles className="h-3.5 w-3.5 text-teal-600" />
              {showPitchModal ? "Hide Client Outreach Pitch" : "Generate 1-Click Client Outreach Pitch"}
            </span>
            <span className="text-[11px] text-slate-400">{showPitchModal ? "▲" : "▼"}</span>
          </button>

          {showPitchModal && (
            <div className="mt-3 rounded-2xl border border-slate-200 bg-slate-50/90 p-3.5">
              <p className="text-[11px] font-semibold text-slate-600 mb-2">
                Copy and send this tailored pitch directly to {companyName}:
              </p>
              <div className="rounded-xl bg-white p-3 text-[11px] text-slate-700 leading-relaxed font-mono whitespace-pre-line border border-slate-200/80 shadow-2xs max-h-48 overflow-y-auto">
                {cleanPitch}
              </div>
              <div className="mt-2.5 grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={copyToClipboard}
                  className="flex items-center justify-center gap-1.5 rounded-xl bg-slate-900 py-2 text-xs font-semibold text-white hover:bg-slate-800 transition-colors"
                >
                  {copiedPitch ? (
                    <>
                      <Check className="h-3.5 w-3.5 text-emerald-400" />
                      Copied!
                    </>
                  ) : (
                    <>
                      <Copy className="h-3.5 w-3.5 text-slate-300" />
                      Copy Pitch
                    </>
                  )}
                </button>
                <button
                  type="button"
                  onClick={sharePitchOnWhatsApp}
                  className="flex items-center justify-center gap-1.5 rounded-xl bg-[#25D366] py-2 text-xs font-bold text-white hover:bg-[#20ba59] transition-colors shadow-2xs"
                >
                  <MessageCircle className="h-3.5 w-3.5" />
                  WhatsApp
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Value Props Checklist */}
        <div className="mt-5 space-y-2 border-t border-slate-200/80 pt-4 text-xs text-slate-600">
          <div className="flex items-center gap-2">
            <span className="flex h-4 w-4 items-center justify-center rounded-full bg-emerald-100 text-emerald-700 text-[10px] font-bold">✓</span>
            <span>100% direct client payout (0% platform cut vs 10-20% on legacy sites)</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="flex h-4 w-4 items-center justify-center rounded-full bg-emerald-100 text-emerald-700 text-[10px] font-bold">✓</span>
            <span>Milestone contract tracking & direct settlement</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="flex h-4 w-4 items-center justify-center rounded-full bg-emerald-100 text-emerald-700 text-[10px] font-bold">✓</span>
            <span>Integrated invoicing, CRM & timesheets</span>
          </div>
        </div>
      </div>

      {/* About Company Card */}
      <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-2xs">
        <h4 className="text-[11px] font-bold uppercase tracking-wider text-slate-400">About the Employer</h4>
        <p className="mt-2 text-sm font-bold text-slate-900">{companyName}</p>
        {companyDomain && (
          <a
            href={companyDomain.startsWith("http") ? companyDomain : `https://${companyDomain}`}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-1 inline-flex items-center gap-1 text-xs text-teal-700 hover:underline font-mono"
          >
            <span>{companyDomain}</span>
            <ExternalLink className="h-3 w-3" />
          </a>
        )}
        <div className="mt-3 flex items-center gap-1.5 text-xs text-teal-700 font-medium">
          <ShieldCheck className="h-4 w-4 text-teal-600" />
          <span>Verified Organization</span>
        </div>
      </div>

      {/* Claim Employer Listing Loop (for curated jobs) */}
      {sourceUrl && (
        <div className="rounded-2xl border border-dashed border-teal-300 bg-teal-50/40 p-4">
          <p className="text-[11px] font-bold uppercase tracking-wider text-teal-800">
            Hiring for {companyName}?
          </p>
          <p className="mt-1 text-xs text-slate-600 leading-relaxed">
            Claim this listing to review inbound proposals directly, message candidates with zero intermediary fees, and manage contracts inside Clivora.
          </p>
          <Link
            href={`/signup?role=client&claim_company=${encodeURIComponent(companyName)}&job_id=${encodeURIComponent(jobId)}`}
            className="mt-3 inline-flex items-center gap-1.5 text-xs font-bold text-teal-800 hover:text-teal-950 underline underline-offset-2"
          >
            <span>Claim this employer profile →</span>
          </Link>
        </div>
      )}
    </div>
  );
}
