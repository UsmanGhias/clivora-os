"use client";

import { SmartAppCta } from "@/components/app/SmartAppCta";

/** @deprecated Prefer SmartAppCta, kept as thin wrapper for existing imports. */
export function DownloadAppCard({
  title = "Full power in the CLIVORA app",
  body = "This area is available on web for viewing. Create, edit, offline CRM, PDF branding, AI, vault, and push notifications work best in the Android app.",
  tone = "freelancer",
}: {
  title?: string;
  body?: string;
  tone?: "freelancer" | "client";
}) {
  return <SmartAppCta title={title} body={body} tone={tone} />;
}
