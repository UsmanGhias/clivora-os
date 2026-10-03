"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function TeamInviteActions({
  inviteId,
  status,
  isClient = false,
}: {
  inviteId: string;
  status?: string | null;
  isClient?: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState<"accepted" | "declined" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const pending = (status || "pending").toLowerCase() === "pending";

  if (!pending) return null;

  async function respond(next: "accepted" | "declined") {
    setBusy(next);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      const { error: err } = await supabase
        .from("team_invites")
        .update({
          status: next,
          invitee_uid: user?.id ?? null,
          responded_at: new Date().toISOString(),
        })
        .eq("id", inviteId);
      if (err) throw err;
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update invite");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex items-center gap-2">
        <button
          type="button"
          disabled={busy != null}
          onClick={() => void respond("accepted")}
          className={`rounded-lg px-3 py-1.5 text-xs font-bold text-white disabled:opacity-50 ${
            isClient
              ? "bg-client-accent hover:bg-client-header"
              : "bg-primary hover:bg-primary-dark"
          }`}
        >
          {busy === "accepted" ? "…" : "Accept"}
        </button>
        <button
          type="button"
          disabled={busy != null}
          onClick={() => void respond("declined")}
          className="rounded-lg border border-border bg-background px-3 py-1.5 text-xs font-bold text-text-secondary hover:bg-surface disabled:opacity-50"
        >
          {busy === "declined" ? "…" : "Decline"}
        </button>
      </div>
      {error && <p className="text-[10px] text-error">{error}</p>}
    </div>
  );
}
