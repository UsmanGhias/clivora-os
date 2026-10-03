import Link from "next/link";
import { Lock, ShieldCheck, Sparkles, UserRound, Users } from "lucide-react";
import { marketing } from "@/lib/marketing";

/** Light Connect hero matching marketing mockup - free-first CTAs. */
export function ConnectMarketingHero({
  signedIn,
  isClient,
}: {
  signedIn: boolean;
  isClient: boolean;
}) {
  const c = marketing.connect;

  return (
    <section className="relative overflow-hidden rounded-[2rem] border border-slate-200 bg-white p-6 shadow-sm sm:p-10">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_60%_50%_at_90%_10%,rgba(13,148,136,0.12),transparent_55%)]" />
      <div className="relative grid items-center gap-10 lg:grid-cols-[1.1fr_0.9fr]">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-navy sm:text-4xl lg:text-5xl">
            Hire top <span className="text-sky-600">talent</span>. Get hired for{" "}
            <span className="text-primary">great work.</span>
          </h1>
          <p className="mt-4 max-w-xl text-base leading-relaxed text-slate-600">{c.body}</p>

          <div className="mt-7 flex flex-col gap-3 sm:flex-row">
            <Link
              href={
                signedIn
                  ? isClient
                    ? "#board"
                    : "/signup?role=client&next=/connect"
                  : c.primaryCta.href
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-navy px-5 py-3.5 text-sm font-bold text-white"
            >
              <Users className="h-4 w-4" />
              {c.primaryCta.label}
            </Link>
            <Link
              href={
                signedIn
                  ? !isClient
                    ? "#board"
                    : "/signup?role=freelancer&next=/connect"
                  : c.secondaryCta.href
              }
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-navy/20 bg-white px-5 py-3.5 text-sm font-bold text-navy"
            >
              <UserRound className="h-4 w-4" />
              {c.secondaryCta.label}
            </Link>
          </div>

          <div className="mt-7 flex flex-wrap gap-4">
            {[
              { icon: Lock, title: "100% Private", body: "Contact only after mutual approval." },
              { icon: ShieldCheck, title: "No Platform Fees", body: "Keep more of what you earn." },
              { icon: Sparkles, title: "Pro Tools", body: "CRM after you connect." },
            ].map((f) => (
              <div key={f.title} className="flex min-w-[160px] flex-1 items-start gap-2.5">
                <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-teal-50 text-primary">
                  <f.icon className="h-4 w-4" />
                </span>
                <div>
                  <p className="text-sm font-bold text-navy">{f.title}</p>
                  <p className="text-xs text-slate-500">{f.body}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="relative mx-auto hidden h-[280px] w-full max-w-md sm:block sm:h-[320px]">
          <div className="absolute right-2 top-2 z-10 w-[200px] rounded-2xl border border-slate-200 bg-white p-3 shadow-xl">
            <p className="text-[10px] font-semibold text-slate-400">Billed this month</p>
            <p className="text-lg font-extrabold text-navy">$4,180</p>
            <p className="text-[10px] font-semibold text-emerald-600">+12.4%</p>
            <svg viewBox="0 0 120 28" className="mt-1 h-6 w-full text-emerald-500" aria-hidden>
              <polyline fill="none" stroke="currentColor" strokeWidth="2" points="0,22 20,18 40,16 60,10 80,12 100,6 120,4" />
            </svg>
          </div>
          <div className="absolute left-0 top-16 z-10 w-[210px] rounded-2xl border border-slate-200 bg-white p-3 shadow-xl">
            <div className="flex items-center gap-2">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-teal-100 text-xs font-bold text-primary">
                SA
              </span>
              <div>
                <p className="text-sm font-bold text-navy">Sara Ahmed</p>
                <p className="text-[10px] text-slate-500">UI/UX Designer · 4.9 ★</p>
              </div>
            </div>
            <span className="mt-2 inline-flex rounded-full bg-sky-50 px-2 py-0.5 text-[10px] font-bold text-sky-700">
              Verified
            </span>
          </div>
          <div className="absolute bottom-8 right-0 z-10 w-[230px] rounded-2xl border border-slate-200 bg-white p-3 shadow-xl">
            <p className="text-xs font-bold text-navy">New Connect request</p>
            <p className="mt-0.5 text-[10px] text-slate-500">James Wilson wants to connect</p>
            <div className="mt-2 flex gap-2">
              <span className="rounded-lg bg-navy px-2.5 py-1 text-[10px] font-bold text-white">View</span>
              <span className="rounded-lg border border-slate-200 px-2.5 py-1 text-[10px] font-semibold text-slate-500">
                Ignore
              </span>
            </div>
          </div>
          <div className="absolute bottom-0 left-6 z-10 rounded-2xl border border-slate-200 bg-white p-3 shadow-xl">
            <p className="text-[10px] text-slate-400">Completed projects</p>
            <p className="text-xl font-extrabold text-navy">36</p>
          </div>
        </div>
        {/* Mobile preview cards - stacked, no overlap */}
        <div className="grid gap-3 sm:hidden">
          <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <p className="text-[10px] font-semibold text-slate-400">Billed this month</p>
            <p className="text-lg font-extrabold text-navy">$4,180</p>
            <p className="text-[10px] font-semibold text-emerald-600">+12.4%</p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <div className="flex items-center gap-2">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-teal-100 text-xs font-bold text-primary">
                SA
              </span>
              <div>
                <p className="text-sm font-bold text-navy">Sara Ahmed</p>
                <p className="text-[10px] text-slate-500">UI/UX Designer · 4.9 ★</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
