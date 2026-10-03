"use client";

import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Logo } from "@/components/ui/Logo";
import { Breadcrumbs, type Crumb } from "@/components/app/Breadcrumbs";
import { SmartAppCtaButton } from "@/components/app/SmartAppCta";
import { cn } from "@/lib/utils";

/**
 * Compact shared chrome for Connect / Pro - AppShell-like feel.
 * Clients: slate header. Freelancers: teal/navy header.
 */
export function SubPageChrome({
  title,
  crumbs,
  backHref = "/app",
  backLabel = "Back to app",
  isClient = false,
  showOpenApp = false,
  children,
  rightSlot,
}: {
  title?: string;
  crumbs: Crumb[];
  backHref?: string;
  backLabel?: string;
  isClient?: boolean;
  showOpenApp?: boolean;
  children: React.ReactNode;
  rightSlot?: React.ReactNode;
}) {
  const headerBg = isClient
    ? "bg-gradient-to-r from-slate-800 via-slate-700 to-slate-800"
    : "bg-gradient-to-r from-navy via-teal-900 to-navy";
  const pageBg = isClient
    ? "bg-gradient-to-b from-slate-100/80 via-background to-background"
    : "bg-gradient-to-b from-teal-50/60 via-background to-background";

  return (
    <div className={cn("min-h-screen text-text-primary", pageBg, isClient && "theme-client")}>
      <header className={cn("sticky top-0 z-40 border-b border-white/10 text-white shadow-lg", headerBg)}>
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3">
          <div className="flex min-w-0 items-center gap-3">
            <Link href={backHref.startsWith("/app") ? "/app" : "/"} aria-label="CLIVORA">
              <Logo size="sm" variant="onDark" />
            </Link>
            <div className="hidden min-w-0 sm:block">
              <Breadcrumbs items={crumbs} light />
              {title && (
                <p className="truncate text-sm font-bold tracking-tight text-white/95">{title}</p>
              )}
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <Link
              href={backHref}
              className={cn(
                "inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-semibold text-white/90",
                isClient ? "bg-white/10 hover:bg-white/15" : "bg-teal-500/20 hover:bg-teal-400/25",
              )}
            >
              <ArrowLeft className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">{backLabel.replace("Back to ", "")}</span>
              <span className="sm:hidden">Back</span>
            </Link>
            {rightSlot}
            {showOpenApp && <SmartAppCtaButton size="sm" />}
          </div>
        </div>
        <div className="border-t border-white/5 px-4 py-1.5 sm:hidden">
          <Breadcrumbs items={crumbs} light />
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6 sm:py-8">{children}</main>
    </div>
  );
}
