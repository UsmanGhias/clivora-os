"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Crown, Sparkles, UserPlus, Coins } from "lucide-react";
import { site } from "@/lib/site";
import { createClient } from "@/lib/supabase/client";
import {
  CONNECT_CREDIT_COSTS,
  formatConnectCredits,
  type ConnectCreditSummary,
} from "@/lib/connect-credits";

export function ConnectActions({
  signedIn,
  isProPlus,
  isClient,
}: {
  signedIn: boolean;
  isProPlus: boolean;
  isClient: boolean;
}) {
  const [summary, setSummary] = useState<ConnectCreditSummary | null>(null);

  useEffect(() => {
    if (!signedIn || !isProPlus) return;
    let cancelled = false;
    (async () => {
      try {
        const supabase = createClient();
        const { data, error } = await supabase.rpc("connect_credit_summary");
        if (cancelled) return;
        if (!error && Array.isArray(data) && data[0]) {
          setSummary(data[0] as ConnectCreditSummary);
          return;
        }
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (!user) return;
        const { data: row } = await supabase
          .from("connect_credit_accounts")
          .select(
            "plan, allowance, balance, current_period_start, current_period_end, legacy_unlimited, grandfather_until",
          )
          .eq("user_id", user.id)
          .maybeSingle();
        if (cancelled || !row) return;
        setSummary({
          plan: row.plan,
          allowance: row.allowance,
          balance: row.balance,
          period_start: row.current_period_start,
          period_end: row.current_period_end,
          legacy_unlimited: row.legacy_unlimited,
          grandfather_until: row.grandfather_until,
        });
      } catch {
        /* ignore */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [signedIn, isProPlus]);

  if (!signedIn) {
    return (
      <div className="rounded-2xl border border-violet-100 bg-gradient-to-br from-violet-50 to-white p-5 shadow-sm">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-violet-100 text-violet-700">
            <Crown className="h-5 w-5" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="font-bold text-navy">Browse free. Upgrade only when you need Connect credits.</p>
            <p className="mt-1 text-sm text-text-secondary">
              Explore talent and jobs with $0 platform fees on your deals. Pro Plus unlocks monthly
              Connect credits for contact, proposals, and posting when you are ready.
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
              <Link
                href="/signup?next=/connect"
                className="inline-flex min-h-11 items-center gap-1.5 rounded-xl bg-navy px-5 py-2.5 text-sm font-bold text-white"
              >
                <UserPlus className="h-4 w-4" />
                Create free account
              </Link>
              <Link
                href="/login?next=/connect"
                className="inline-flex min-h-11 items-center rounded-xl border-2 border-navy/15 bg-white px-5 py-2.5 text-sm font-semibold text-navy"
              >
                Sign in
              </Link>
              <Link
                href="/edition"
                className="inline-flex min-h-11 items-center rounded-xl px-4 py-2.5 text-sm font-semibold text-teal-700 hover:underline"
              >
                Zero-fee comparison
              </Link>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!isProPlus) {
    return (
      <div className="rounded-2xl border border-primary/30 bg-primary/5 p-5">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary-dark">
            <Sparkles className="h-5 w-5" />
          </span>
          <div>
            <p className="font-bold text-navy">Unlock Connect credits with Pro Plus</p>
            <p className="mt-1 text-sm text-text-secondary">
              You can browse as a {isClient ? "client" : "freelancer"}. Contact (−
              {CONNECT_CREDIT_COSTS.contact}), proposals (−{CONNECT_CREDIT_COSTS.proposal}), and
              publish (−{CONNECT_CREDIT_COSTS.publish_need}/−{CONNECT_CREDIT_COSTS.publish_profile})
              use monthly credits. Keep 100% of negotiated rates ($0 platform fee).
            </p>
            <Link
              href="/edition"
              className="mt-3 inline-flex min-h-11 items-center rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white"
            >
              Upgrade to Pro Plus · {site.pricing.proPlusMonthlyLabel}/mo
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-border bg-white p-5 shadow-sm">
      <div className="flex items-start gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-navy/10 text-navy">
          <Coins className="h-5 w-5" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="font-bold text-navy">Your Connect credits</p>
          <p className="mt-1 text-lg font-extrabold text-primary">
            {formatConnectCredits(summary)}
          </p>
          <p className="mt-1 text-sm text-text-secondary">
            Costs: contact {CONNECT_CREDIT_COSTS.contact} · proposal {CONNECT_CREDIT_COSTS.proposal}{" "}
            · publish job/profile {CONNECT_CREDIT_COSTS.publish_need}. Replies, accept/decline,
            messaging after accept, and milestone tracking are free. $0 platform commission.
          </p>
          {summary?.legacy_unlimited && (
            <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-xs font-medium text-amber-900">
              Grandfathered unlimited access until your conversion date. After that you receive a
              full 100-credit Pro Plus allowance each month.
            </p>
          )}
          <Link
            href="/app/connect/manage"
            className="mt-3 inline-flex min-h-11 items-center rounded-xl bg-navy px-4 py-2 text-sm font-semibold text-white"
          >
            Manage listing
          </Link>
        </div>
      </div>
    </div>
  );
}
