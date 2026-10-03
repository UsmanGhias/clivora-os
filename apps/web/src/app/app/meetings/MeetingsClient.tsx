"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Calendar, Video, Copy, ExternalLink } from "lucide-react";

type MeetingLink = {
  id: string;
  owner_uid: string;
  room_url: string;
  title: string | null;
  created_at: string | null;
};

function randomRoomId() {
  return (
    Math.random().toString(36).slice(2, 10) + Math.random().toString(36).slice(2, 10)
  );
}

function formatDate(iso?: string | null) {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export function MeetingsClient({
  initial,
  ownerUid,
  googleConfigured = false,
  googleConnected = false,
}: {
  initial: MeetingLink[];
  ownerUid: string;
  googleConfigured?: boolean;
  googleConnected?: boolean;
}) {
  const router = useRouter();
  const params = useSearchParams();
  const [links, setLinks] = useState(initial);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const [calendarMsg, setCalendarMsg] = useState<string | null>(null);
  const [connected, setConnected] = useState(googleConnected);

  useEffect(() => {
    setConnected(googleConnected);
  }, [googleConnected]);

  useEffect(() => {
    if (params.get("connected") === "1") {
      setConnected(true);
      setCalendarMsg("Google Calendar connected. New meeting rooms can be added to your calendar manually; event auto-create uses your OAuth token when sync runs.");
      return;
    }
    const err = params.get("error");
    if (err === "not_configured") {
      setCalendarMsg(
        "Google OAuth is not configured on this deployment. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET, then try again.",
      );
      return;
    }
    if (err) {
      setCalendarMsg(`Google Calendar connect failed: ${err}`);
      return;
    }
    if (params.get("calendar") === "google" && !googleConfigured) {
      setCalendarMsg(
        "Configure Google OAuth (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET) to enable calendar connect. Until then, create a Jitsi room and paste the link into Google Calendar.",
      );
    }
  }, [params, googleConfigured]);

  async function createRoom(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const roomId = `clivora-${randomRoomId()}`;
      const roomUrl = `https://meet.jit.si/${roomId}`;
      const supabase = createClient();
      const { data, error: err } = await supabase
        .from("meeting_links")
        .insert({
          owner_uid: ownerUid,
          room_url: roomUrl,
          title: title.trim() || null,
        })
        .select()
        .single();
      if (err) throw err;
      setLinks((prev) => [data as MeetingLink, ...prev]);
      setTitle("");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create room");
    } finally {
      setBusy(false);
    }
  }

  async function copyUrl(url: string) {
    await navigator.clipboard.writeText(url).catch(() => {});
    setCopied(url);
    setTimeout(() => setCopied(null), 2000);
  }

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="inline-flex items-center gap-2 font-bold text-navy">
              <Calendar className="h-4 w-4 text-primary" />
              Google Calendar
            </p>
            <p className="mt-1 text-sm text-text-secondary">
              {googleConfigured
                ? connected
                  ? "Connected for this account. Create rooms below and keep invites in sync."
                  : "OAuth is configured. Connect your Google account to authorize calendar access."
                : "Google OAuth is not configured for this workspace yet."}
            </p>
            <p className="mt-2 text-xs font-semibold text-text-muted">
              Status: {connected ? "Connected" : googleConfigured ? "Not connected" : "Not configured"}
            </p>
          </div>
          {googleConfigured ? (
            connected ? (
              <a
                href="/api/integrations/google/calendar/start"
                className="rounded-xl border border-border px-4 py-2 text-sm font-semibold text-navy"
              >
                Reconnect
              </a>
            ) : (
              <a
                href="/api/integrations/google/calendar/start"
                className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white"
              >
                Connect Google Calendar
              </a>
            )
          ) : (
            <span className="rounded-xl border border-dashed border-border px-4 py-2 text-sm font-semibold text-text-muted">
              Configure Google OAuth
            </span>
          )}
        </div>
        {calendarMsg && (
          <p className="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-sm text-amber-950">
            {calendarMsg}
          </p>
        )}
      </div>

      <form
        onSubmit={createRoom}
        className="flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4 shadow-sm sm:flex-row sm:items-end"
      >
        <label className="block flex-1 text-sm font-semibold text-navy">
          Meeting title
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Client kickoff"
            className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
          />
        </label>
        <button
          type="submit"
          disabled={busy}
          className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
        >
          <Video className="h-4 w-4" />
          {busy ? "Creating…" : "Create Jitsi room"}
        </button>
      </form>
      {error && <p className="text-sm text-error">{error}</p>}

      <ul className="space-y-2">
        {links.length === 0 ? (
          <li className="rounded-2xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
            No meeting rooms yet.
          </li>
        ) : (
          links.map((link) => (
            <li
              key={link.id}
              className="flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4 shadow-sm sm:flex-row sm:items-center sm:justify-between"
            >
              <div className="min-w-0">
                <p className="font-semibold text-navy">{link.title || "Untitled meeting"}</p>
                <p className="mt-1 truncate text-xs text-text-muted">{link.room_url}</p>
                <p className="mt-1 text-[11px] text-text-muted">{formatDate(link.created_at)}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => void copyUrl(link.room_url)}
                  className="inline-flex items-center gap-1.5 rounded-xl border border-border px-3 py-2 text-xs font-semibold text-navy"
                >
                  <Copy className="h-3.5 w-3.5" />
                  {copied === link.room_url ? "Copied" : "Copy"}
                </button>
                <a
                  href={link.room_url}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1.5 rounded-xl bg-primary px-3 py-2 text-xs font-semibold text-white"
                >
                  <ExternalLink className="h-3.5 w-3.5" />
                  Join
                </a>
              </div>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
