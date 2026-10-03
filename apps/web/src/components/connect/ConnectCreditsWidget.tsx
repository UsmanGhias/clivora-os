"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Coins, Info } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatConnectCredits, type ConnectCreditSummary } from "@/lib/connect-credits";
import { cn } from "@/lib/utils";

export function ConnectCreditsWidget({
  signedIn,
  isClient,
}: {
  signedIn: boolean;
  isClient: boolean;
}) {
  const [summary, setSummary] = useState<ConnectCreditSummary | null>(null);

  useEffect(() => {
    if (!signedIn) return;
    let cancelled = false;
    (async () => {
      try {
        const supabase = createClient();
        const { data } = await supabase.rpc("connect_credit_summary");
        if (!cancelled && Array.isArray(data) && data[0]) {
          setSummary(data[0] as ConnectCreditSummary);
        }
      } catch {
        /* ignore */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [signedIn]);

  const renewLabel = summary?.period_end
    ? new Date(summary.period_end).toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric",
      })
    : null;

  return (
    <div
      className={cn(
        "rounded-2xl border p-5 shadow-sm",
        isClient && summary?.legacy_unlimited
          ? "border-navy/20 bg-navy text-white"
          : "border-border bg-surface",
      )}
    >
      <div className="flex items-center gap-2">
        <Coins
          className={cn(
            "h-5 w-5",
            isClient && summary?.legacy_unlimited
              ? "text-emerald-300"
              : isClient
                ? "text-client-accent"
                : "text-primary",
          )}
        />
        <h3
          className={cn(
            "font-display font-bold",
            isClient && summary?.legacy_unlimited ? "text-white" : "text-navy",
          )}
        >
          Connect credits
        </h3>
        <Info
          className={cn(
            "ml-auto h-4 w-4",
            isClient && summary?.legacy_unlimited ? "text-white/50" : "text-text-muted",
          )}
        />
      </div>
      <p
        className={cn(
          "mt-3 font-display text-2xl font-extrabold",
          summary?.legacy_unlimited
            ? isClient
              ? "text-emerald-300"
              : "text-success"
            : isClient
              ? "text-client-accent"
              : "text-primary",
        )}
      >
        {signedIn
          ? summary?.legacy_unlimited
            ? "Unlimited"
            : formatConnectCredits(summary)
          : "Sign in"}
      </p>
      {renewLabel && (
        <p
          className={cn(
            "mt-1 text-xs",
            isClient && summary?.legacy_unlimited ? "text-white/60" : "text-text-secondary",
          )}
        >
          Renews on {renewLabel}
        </p>
      )}
      {isClient && summary?.legacy_unlimited && (
        <ul className="mt-3 space-y-1.5 text-xs text-white/70">
          <li>✓ Unlimited invites</li>
          <li>✓ Direct contact with talent</li>
          <li>✓ No platform fees</li>
        </ul>
      )}
      <Link
        href="/edition"
        className={cn(
          "mt-4 inline-flex w-full items-center justify-center rounded-xl px-4 py-2.5 text-sm font-semibold",
          isClient && summary?.legacy_unlimited
            ? "bg-white text-navy hover:bg-white/90"
            : isClient
              ? "bg-client-accent text-white hover:bg-client-header"
              : "bg-primary text-white hover:bg-primary-dark",
        )}
      >
        Manage plan
      </Link>
    </div>
  );
}
