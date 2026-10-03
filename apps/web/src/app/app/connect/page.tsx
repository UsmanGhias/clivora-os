import {
  listMyConnectRequests,
  listPublicConnectNeeds,
  listPublicConnectProfiles,
} from "@/lib/connect";
import { getProfile, isClientAccount, isProPlus, isRestricted } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { ConnectBoard } from "@/components/connect/ConnectBoard";
import { ConnectCreditsWidget } from "@/components/connect/ConnectCreditsWidget";
import { ClientCard } from "@/components/client/ui";
import { redirect } from "next/navigation";
import Link from "next/link";
import { Suspense } from "react";
import { CheckCircle2, Headphones, Shield, Sparkles, Zap } from "lucide-react";

export const metadata = { title: "Marketplace / Connect" };

export default async function AppConnectPage({
  searchParams,
}: {
  searchParams?: Promise<{ tab?: string }>;
}) {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const client = isClientAccount(profile);
  const sp = searchParams ? await searchParams : undefined;
  const tabParam = String(sp?.tab ?? "").toLowerCase();
  const defaultTab =
    tabParam === "jobs" || tabParam === "talent" || tabParam === "inbox"
      ? (tabParam as "jobs" | "talent" | "inbox")
      : client
        ? "talent"
        : "jobs";
  const [profiles, needs, requests] = await Promise.all([
    listPublicConnectProfiles(),
    listPublicConnectNeeds(),
    listMyConnectRequests(),
  ]);
  let savedBookmarkIds: string[] = [];
  try {
    const supabase = await createClient();
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

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">
            {client ? "Marketplace / Connect" : "Find jobs"}
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            {client
              ? "Find and connect with top freelance talent to get your work done."
              : "Browse open jobs and submit proposals with Connect credits."}
          </p>
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_280px]">
        <Suspense fallback={<div className="rounded-2xl border border-border bg-surface p-8 text-sm text-text-secondary">Loading Connect…</div>}>
          <ConnectBoard
            profiles={profiles}
            needs={needs}
            requests={requests}
            signedIn
            isProPlus={isProPlus(profile)}
            isClient={client}
            isRestricted={isRestricted(profile)}
            myUserId={profile.id}
            portalMode
            accent={client ? "slate" : "teal"}
            defaultTab={defaultTab}
            savedBookmarkIds={savedBookmarkIds}
          />
        </Suspense>
        <div className="hidden xl:block">
          <div className="sticky top-24 space-y-4">
            <ConnectCreditsWidget signedIn isClient={client} />
            {client && (
              <>
                <ClientCard
                  title="Open jobs on CLIVORA"
                  action={
                    <Link href="/app/connect/manage" className="text-xs font-semibold text-client-accent">
                      View all jobs →
                    </Link>
                  }
                >
                  <ul className="space-y-3">
                    {(needs.length ? needs : []).slice(0, 4).map((n) => (
                      <li key={n.id} className="rounded-xl border border-border px-3 py-2.5">
                        <p className="truncate text-sm font-semibold text-navy">
                          {n.title || "Open job"}
                        </p>
                        <p className="mt-0.5 text-xs text-text-muted">
                          {n.budget_band || "Budget TBD"} · recent
                        </p>
                      </li>
                    ))}
                    {needs.length === 0 && (
                      <li className="text-sm text-text-secondary">
                        No open jobs yet.{" "}
                        <Link href="/app/connect/manage" className="font-semibold text-client-accent">
                          Post one →
                        </Link>
                      </li>
                    )}
                  </ul>
                </ClientCard>

                <ClientCard title="Why clients love CLIVORA">
                  <div className="grid grid-cols-2 gap-3">
                    {[
                      { icon: CheckCircle2, label: "Verified Talent" },
                      { icon: Shield, label: "Safe & Secure" },
                      { icon: Zap, label: "No Platform Fee" },
                      { icon: Headphones, label: "24/7 Support" },
                    ].map((f) => {
                      const Icon = f.icon;
                      return (
                        <div
                          key={f.label}
                          className="rounded-xl bg-client-surface px-3 py-3 text-center"
                        >
                          <Icon className="mx-auto h-5 w-5 text-client-accent" />
                          <p className="mt-1.5 text-[11px] font-bold text-navy">{f.label}</p>
                        </div>
                      );
                    })}
                  </div>
                </ClientCard>
              </>
            )}
            {!client && (
              <div className="rounded-2xl border border-primary/20 bg-primary/5 p-4">
                <Sparkles className="h-5 w-5 text-primary" />
                <p className="mt-2 text-sm font-semibold text-navy">Stand out on Connect</p>
                <p className="mt-1 text-xs text-text-secondary">
                  Complete your profile to unlock more invites.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
