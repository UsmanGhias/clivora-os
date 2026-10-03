import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { Suspense } from "react";
import {
  listMyConnectRequests,
  listPublicConnectNeeds,
  listPublicConnectProfiles,
} from "@/lib/connect";
import {
  getProfile,
  isBlocked,
  isClientAccount,
  isProPlus,
  isRestricted,
} from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { MarketingNav } from "@/components/marketing/MarketingNav";
import { MarketingFooter } from "@/components/marketing/MarketingFooter";
import { MarketingJsonLd } from "@/components/marketing/MarketingJsonLd";
import { ConnectMarketingHero } from "@/components/connect/ConnectMarketingHero";
import { ConnectBoard } from "@/components/connect/ConnectBoard";
import { Lock, ShieldCheck, Building2 } from "lucide-react";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "CLIVORA Connect - Private marketplace",
  description:
    "Hire freelancers and find clients on CLIVORA Connect. Private contact until mutual accept, then continue in the same CRM. Browse free.",
  alternates: { canonical: `${site.url}/connect` },
  keywords: [
    "Clivora Connect",
    "freelancer platform",
    "hire freelancers",
    "freelance marketplace",
  ],
};

export default async function ConnectPage({
  searchParams,
}: {
  searchParams?: Promise<{ tab?: string }>;
}) {
  const profile = await getProfile();
  if (profile && isBlocked(profile)) redirect("/blocked");
  const sp = searchParams ? await searchParams : undefined;
  const tabParam = String(sp?.tab ?? "").toLowerCase();
  const defaultTab =
    tabParam === "jobs" || tabParam === "talent" || tabParam === "inbox"
      ? (tabParam as "jobs" | "talent" | "inbox")
      : "talent";
  let profiles: Awaited<ReturnType<typeof listPublicConnectProfiles>> = [];
  let needs: Awaited<ReturnType<typeof listPublicConnectNeeds>> = [];
  let requests: Awaited<ReturnType<typeof listMyConnectRequests>> = [];
  let loadError: string | null = null;
  try {
    [profiles, needs, requests] = await Promise.all([
      listPublicConnectProfiles(),
      listPublicConnectNeeds(),
      listMyConnectRequests(),
    ]);
  } catch {
    loadError = "Could not load Connect right now. Refresh to try again.";
  }
  const signedIn = !!profile;
  const plus = isProPlus(profile);
  const client = isClientAccount(profile);
  const restricted = isRestricted(profile);
  const supabase = await createClient();
  let savedBookmarkIds: string[] = [];
  if (profile) {
    try {
      const { data } = await supabase
        .from("freelancer_bookmarks")
        .select("target_id")
        .eq("user_id", profile.id)
        .in("target_type", ["freelancer", "job"])
        .limit(500);
      savedBookmarkIds = (data ?? []).map((row) => String(row.target_id));
    } catch {
      savedBookmarkIds = [];
    }
  }

  let jobCount = 1120;
  try {
    const { count } = await supabase
      .from("connect_jobs")
      .select("*", { count: "exact", head: true })
      .eq("is_public", true)
      .eq("status", "published");
    if (count && count > 0) jobCount = count;
  } catch {
    jobCount = 1120;
  }
  const liveJobsDisplay = `${jobCount.toLocaleString()}+`;

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-navy antialiased">
      <MarketingJsonLd />
      <MarketingNav />
      <main className="mx-auto max-w-7xl space-y-8 px-5 py-8 lg:px-8 lg:py-12">
        <ConnectMarketingHero signedIn={signedIn} isClient={client} />

        {/* Remote Jobs Direct Bridge */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 rounded-2xl border border-teal-200/90 bg-gradient-to-r from-teal-50/80 via-white to-teal-50/80 p-5 shadow-xs">
          <div className="flex items-center gap-3.5">
            <div className="h-11 w-11 rounded-xl bg-teal-700 text-white flex items-center justify-center font-bold text-xs shadow-sm">
              {liveJobsDisplay}
            </div>
            <div>
              <p className="text-sm font-bold text-navy">{liveJobsDisplay} Remote Engineering, Design & Tech Roles Available</p>
              <p className="text-xs text-slate-500">Apply with 1-click tailored proposals. Keep 100% of your negotiated deal.</p>
            </div>
          </div>
          <Link
            href="/jobs"
            className="inline-flex items-center justify-center gap-2 rounded-xl bg-teal-700 px-5 py-2.5 text-xs font-bold text-white shadow-sm hover:bg-teal-800 transition-colors shrink-0 w-full sm:w-auto"
          >
            Browse {liveJobsDisplay} Remote Jobs
            <span aria-hidden="true">→</span>
          </Link>
        </div>

        {restricted && (
          <p className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            Your account is restricted - browsing works, posting/contact is paused. Contact support
            if this is unexpected.
          </p>
        )}

        <div id="board" className="scroll-mt-24">
          <Suspense fallback={<div className="rounded-2xl border border-border bg-surface p-8 text-sm text-text-secondary">Loading Connect…</div>}>
            <ConnectBoard
              profiles={profiles}
              needs={needs}
              requests={requests}
              signedIn={signedIn}
              isProPlus={plus}
              isClient={client}
              isRestricted={restricted}
              myUserId={profile?.id}
              accent={client ? "slate" : "teal"}
              defaultTab={defaultTab}
              loadError={loadError}
              savedBookmarkIds={savedBookmarkIds}
            />
          </Suspense>
        </div>

        <section className="grid gap-4 rounded-2xl border border-slate-200 bg-white p-6 sm:grid-cols-3">
          <div>
            <Lock className="mb-2 h-5 w-5 text-primary" />
            <p className="text-sm font-bold text-navy">How Connect works</p>
            <p className="mt-1 text-sm text-slate-500">
              Both sides must accept a request before contact details unlock.
            </p>
          </div>
          <div>
            <ShieldCheck className="mb-2 h-5 w-5 text-primary" />
            <p className="text-sm font-bold text-navy">Why professionals love it</p>
            <p className="mt-1 text-sm text-slate-500">
              Zero fees on negotiated rates, privacy by default, and full control.
            </p>
          </div>
          <div>
            <Building2 className="mb-2 h-5 w-5 text-primary" />
            <p className="text-sm font-bold text-navy">Need a team workspace?</p>
            <p className="mt-1 text-sm text-slate-500">
              Start free on CLIVORA, then grow into Pro tools when you need them.{" "}
              <Link href="/edition" className="font-semibold text-primary hover:underline">
                Contact sales
              </Link>
            </p>
          </div>
        </section>
      </main>
      <MarketingFooter />
    </div>
  );
}
