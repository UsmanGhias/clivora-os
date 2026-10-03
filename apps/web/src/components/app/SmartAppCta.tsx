"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

const PREF_KEY = "clivora_has_app";

function intentUrl(path = "open") {
  const fallback = encodeURIComponent(site.playStoreUrl);
  // Custom scheme opens the installed app; Play Store is the browser fallback.
  return `intent://${path}#Intent;scheme=clivora;package=${site.appPackage};S.browser_fallback_url=${fallback};end`;
}

export function markHasAppInstalled() {
  try {
    localStorage.setItem(PREF_KEY, "1");
  } catch {
    /* ignore */
  }
}

export function useHasAppPreference() {
  const [hasApp, setHasApp] = useState(false);
  useEffect(() => {
    try {
      setHasApp(localStorage.getItem(PREF_KEY) === "1");
    } catch {
      setHasApp(false);
    }
  }, []);
  return hasApp;
}

/** Compact header button: Open app (if preferred) or Get app. */
export function SmartAppCtaButton({
  size = "md",
  className,
  deepPath = "open",
}: {
  size?: "sm" | "md";
  className?: string;
  deepPath?: string;
}) {
  const hasApp = useHasAppPreference();

  function onOpen() {
    markHasAppInstalled();
    window.location.href = intentUrl(deepPath);
  }

  if (hasApp) {
    return (
      <button
        type="button"
        onClick={onOpen}
        className={cn(
          "rounded-full bg-white/15 font-semibold text-white hover:bg-white/25",
          size === "sm" ? "px-3 py-1.5 text-xs" : "px-4 py-2 text-sm",
          className,
        )}
      >
        Open app
      </button>
    );
  }

  return (
    <a
      href={site.playStoreUrl}
      target="_blank"
      rel="noreferrer"
      onClick={() => markHasAppInstalled()}
      className={cn(
        "rounded-full bg-primary font-semibold text-white hover:bg-primary-dark",
        size === "sm" ? "px-3 py-1.5 text-xs" : "px-4 py-2 text-sm",
        className,
      )}
    >
      Get app
    </a>
  );
}

/**
 * Feature card: explain app-preferred work, then Install or Open.
 * If user already marked “I have the app”, primary action opens the app via intent.
 */
export function SmartAppCta({
  title = "Full power in the CLIVORA app",
  body = "Offline CRM, PDF branding, AI, vault, biometrics, and push notifications work best on Android.",
  deepPath = "open",
  className,
  tone = "freelancer",
}: {
  title?: string;
  body?: string;
  deepPath?: string;
  className?: string;
  tone?: "freelancer" | "client";
}) {
  const hasApp = useHasAppPreference();
  const border =
    tone === "client" ? "border-client-accent/40 bg-client-surface" : "border-primary/40 bg-primary/5";

  function onOpenApp() {
    markHasAppInstalled();
    window.location.href = intentUrl(deepPath);
  }

  return (
    <div className={cn("rounded-2xl border border-dashed p-5", border, className)}>
      <p className="font-bold text-navy">{title}</p>
      <p className="mt-1 text-sm text-text-secondary">{body}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        {hasApp ? (
          <button
            type="button"
            onClick={onOpenApp}
            className={cn(
              "rounded-full px-4 py-2 text-sm font-semibold text-white",
              tone === "client" ? "bg-client-accent" : "bg-navy",
            )}
          >
            Open CLIVORA app
          </button>
        ) : (
          <>
            <a
              href={site.playStoreUrl}
              target="_blank"
              rel="noreferrer"
              className={cn(
                "rounded-full px-4 py-2 text-sm font-semibold text-white",
                tone === "client" ? "bg-client-accent" : "bg-navy",
              )}
            >
              Install from Play Store
            </a>
            <button
              type="button"
              onClick={onOpenApp}
              className="rounded-full border border-navy/20 px-4 py-2 text-sm font-semibold text-navy"
            >
              I already have the app, open it
            </button>
          </>
        )}
        <Link href="/app" className="rounded-full border border-navy/20 px-4 py-2 text-sm font-semibold text-navy">
          Stay on web
        </Link>
      </div>
    </div>
  );
}
