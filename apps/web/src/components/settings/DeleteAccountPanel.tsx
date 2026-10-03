"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function DeleteAccountPanel({ email }: { email: string }) {
  const router = useRouter();
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onDelete() {
    setError(null);
    if (confirm.trim().toLowerCase() !== email.trim().toLowerCase()) {
      setError("Type your account email exactly to confirm.");
      return;
    }
    setBusy(true);
    try {
      const supabase = createClient();
      const { error: rpcError } = await supabase.rpc("request_account_deletion");
      if (rpcError) throw rpcError;
      await supabase.auth.signOut();
      router.replace("/login?deleted=1");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Deletion request failed. Try again or email support.");
      setBusy(false);
    }
  }

  return (
    <div id="delete-account" className="rounded-2xl border border-rose-200 bg-rose-50/60 p-5">
      <h3 className="font-display text-lg font-bold text-rose-900">Delete account</h3>
      <p className="mt-2 text-sm leading-relaxed text-rose-900/80">
        This requests cloud account deletion, restricts access, and signs you out. Full
        anonymization completes within 30 days. CLIVORA does not hold escrow funds - cancel any
        external payment arrangements with clients separately.
      </p>
      <label className="mt-4 block text-xs font-semibold uppercase tracking-wide text-rose-900/70">
        Type {email} to confirm
      </label>
      <input
        type="email"
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
        className="mt-1 w-full rounded-xl border border-rose-200 bg-white px-3 py-2 text-sm text-navy outline-none focus:border-rose-400"
        placeholder={email}
        autoComplete="off"
      />
      {error && <p className="mt-2 text-sm font-medium text-rose-700">{error}</p>}
      <button
        type="button"
        disabled={busy}
        onClick={() => void onDelete()}
        className="mt-4 inline-flex rounded-xl bg-rose-700 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-rose-800 disabled:opacity-60"
      >
        {busy ? "Requesting deletion…" : "Delete my account"}
      </button>
    </div>
  );
}
