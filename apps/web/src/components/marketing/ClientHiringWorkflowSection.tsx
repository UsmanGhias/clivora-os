import Link from "next/link";
import { PlusCircle, FileText, Users, ShieldCheck, ArrowRight, CheckCircle2, Sparkles, Building2 } from "lucide-react";

export function ClientHiringWorkflowSection() {
  return (
    <section className="relative overflow-hidden bg-white py-20 border-t border-slate-100">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Section Heading */}
        <div className="mx-auto max-w-3xl text-center">
          <div className="inline-flex items-center gap-2 rounded-full border border-teal-200 bg-teal-50/70 px-3.5 py-1 text-xs font-semibold text-teal-800">
            <Sparkles className="h-3.5 w-3.5 text-teal-600" />
            100% Free Employer Hiring Desk · $0 Platform Fees
          </div>
          <h2 className="mt-4 text-3xl font-extrabold tracking-tight text-slate-900 sm:text-4xl">
            Post Remote Jobs &amp; Hire Engineers at 0% Commission
          </h2>
          <p className="mt-4 text-base leading-relaxed text-slate-600 sm:text-lg">
            Traditional freelance platforms charge employers 5% to 10% payment fees and deduct up to 20% from talent.
            Clivora is built on an open zero-cut architecture: post unlimited free job listings, review inbound candidate proposals, and hire directly.
          </p>
        </div>

        {/* 3 Step Flow Cards */}
        <div className="mt-14 grid grid-cols-1 gap-8 md:grid-cols-3">
          
          {/* Step 1 */}
          <div className="relative flex flex-col justify-between rounded-2xl border border-slate-200 bg-slate-50/60 p-7 transition hover:border-teal-300 hover:shadow-md">
            <div>
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-teal-600 text-white shadow-sm">
                <PlusCircle className="h-6 w-6" />
              </div>
              <span className="mt-4 inline-block text-xs font-bold uppercase tracking-wider text-teal-700">Step 1</span>
              <h3 className="mt-1 text-xl font-bold text-slate-900">Post Free Remote Roles</h3>
              <p className="mt-3 text-sm leading-relaxed text-slate-600">
                Publish software engineering, design, or technical contracts with budget guidelines, required skills, and timeline expectations. No listing fees, no paywalls.
              </p>
            </div>
            <div className="mt-6 border-t border-slate-200/80 pt-4">
              <span className="text-xs font-semibold text-teal-700 flex items-center gap-1.5">
                <CheckCircle2 className="h-4 w-4" /> Live on public job feed &amp; SEO index
              </span>
            </div>
          </div>

          {/* Step 2 */}
          <div className="relative flex flex-col justify-between rounded-2xl border border-slate-200 bg-slate-50/60 p-7 transition hover:border-teal-300 hover:shadow-md">
            <div>
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-slate-900 text-white shadow-sm">
                <FileText className="h-6 w-6" />
              </div>
              <span className="mt-4 inline-block text-xs font-bold uppercase tracking-wider text-teal-700">Step 2</span>
              <h3 className="mt-1 text-xl font-bold text-slate-900">Review Inbound Proposals</h3>
              <p className="mt-3 text-sm leading-relaxed text-slate-600">
                Verified freelancers submit cover letters, bids, and portfolios directly through your listing. Review proposals inside your dedicated client hiring console.
              </p>
            </div>
            <div className="mt-6 border-t border-slate-200/80 pt-4">
              <span className="text-xs font-semibold text-teal-700 flex items-center gap-1.5">
                <CheckCircle2 className="h-4 w-4" /> Instant email alerts with magic review links
              </span>
            </div>
          </div>

          {/* Step 3 */}
          <div className="relative flex flex-col justify-between rounded-2xl border border-slate-200 bg-slate-50/60 p-7 transition hover:border-teal-300 hover:shadow-md">
            <div>
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-teal-800 text-white shadow-sm">
                <ShieldCheck className="h-6 w-6" />
              </div>
              <span className="mt-4 inline-block text-xs font-bold uppercase tracking-wider text-teal-700">Step 3</span>
              <h3 className="mt-1 text-xl font-bold text-slate-900">Direct Chat &amp; Milestones</h3>
              <p className="mt-3 text-sm leading-relaxed text-slate-600">
                Accept a proposal to unlock private direct chat, track milestones, and pay invoices directly. 100% of your payment reaches the engineer with 0% platform deductions.
              </p>
            </div>
            <div className="mt-6 border-t border-slate-200/80 pt-4">
              <span className="text-xs font-semibold text-teal-700 flex items-center gap-1.5">
                <CheckCircle2 className="h-4 w-4" /> 0% middleman cut on contract value
              </span>
            </div>
          </div>

        </div>

        {/* Outreach / Existing Employer Access Notice */}
        <div className="mt-12 rounded-3xl border border-slate-800 bg-slate-950 p-8 text-white shadow-xl sm:p-10">
          <div className="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
            <div className="max-w-2xl">
              <div className="flex items-center gap-2 text-teal-400 text-xs font-bold uppercase tracking-widest">
                <Building2 className="h-4 w-4" />
                Partner Companies &amp; Reached-Out Hiring Teams
              </div>
              <h3 className="mt-2 text-2xl font-extrabold text-white sm:text-3xl">
                Have you already received an outreach invite from Usman Ghias?
              </h3>
              <p className="mt-3 text-sm leading-relaxed text-slate-300 sm:text-base">
                Your company profile and free hiring desk have been pre-provisioned on Clivora under the Founder Launch initiative ($0 fees forever). Sign in or set your password to manage your active listings and review candidate bids.
              </p>
            </div>

            <div className="flex flex-col sm:flex-row gap-3.5 shrink-0">
              <Link
                href="/login?next=/app/connect/manage"
                className="inline-flex items-center justify-center rounded-xl bg-teal-600 px-6 py-3.5 text-sm font-bold text-white shadow-sm transition hover:bg-teal-500"
              >
                Sign In to Hiring Desk
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
              <Link
                href="/auth/reset-password"
                className="inline-flex items-center justify-center rounded-xl border border-slate-700 bg-slate-900 px-5 py-3.5 text-sm font-semibold text-slate-200 transition hover:bg-slate-800 hover:text-white"
              >
                Set / Reset Password
              </Link>
              <Link
                href="/signup?role=client&next=/app/connect/manage"
                className="inline-flex items-center justify-center rounded-xl border border-teal-500/30 bg-teal-950/40 px-5 py-3.5 text-sm font-semibold text-teal-300 transition hover:bg-teal-900/50"
              >
                Post New Free Role
              </Link>
            </div>
          </div>
        </div>

      </div>
    </section>
  );
}
