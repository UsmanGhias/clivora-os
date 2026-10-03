"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function MessageCompose({
  fromEmail,
  defaultTo = "",
}: {
  fromEmail: string;
  defaultTo?: string;
}) {
  const router = useRouter();
  const [toEmail, setToEmail] = useState(defaultTo);
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  async function onSend(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setOk(false);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const to = toEmail.trim().toLowerCase();
      let toUid: string | null = null;

      // Prefer linked-email resolver (Connect accept / shares / prior thread)
      const { data: linkedUid } = await supabase.rpc("uid_for_linked_email", {
        p_email: to,
      });
      if (typeof linkedUid === "string" && linkedUid) {
        toUid = linkedUid;
      }

      if (!toUid) {
        const { data: peerByEmail } = await supabase
          .from("connect_request_details")
          .select("from_user_id, to_user_id, from_email, to_email, status")
          .eq("status", "accepted")
          .or(`from_email.eq.${to},to_email.eq.${to}`)
          .limit(5);
        const hit = (peerByEmail ?? []).find((r) => {
          const from = (r.from_email || "").toLowerCase();
          const toE = (r.to_email || "").toLowerCase();
          return from === to || toE === to;
        });
        if (hit) {
          toUid =
            (hit.from_email || "").toLowerCase() === to
              ? hit.from_user_id
              : hit.to_user_id;
        }
      }

      const { error: err } = await supabase.from("client_messages").insert({
        from_uid: user.id,
        from_email: fromEmail || user.email || "",
        to_email: to,
        to_uid: toUid,
        subject: subject.trim() || "Message",
        body: body.trim(),
        is_read: false,
        read_at: null,
      });
      if (err) throw err;
      setSubject("");
      setBody("");
      setOk(true);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Send failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSend} className="rounded-2xl border border-border bg-surface p-4 space-y-3">
      <p className="text-sm font-semibold text-navy">Send message</p>
      <input
        required
        type="email"
        placeholder="To email"
        value={toEmail}
        onChange={(e) => setToEmail(e.target.value)}
        className="w-full rounded-xl border border-border px-3 py-2 text-sm"
      />
      <input
        placeholder="Subject"
        value={subject}
        onChange={(e) => setSubject(e.target.value)}
        className="w-full rounded-xl border border-border px-3 py-2 text-sm"
      />
      <textarea
        required
        rows={3}
        placeholder="Message"
        value={body}
        onChange={(e) => setBody(e.target.value)}
        className="w-full rounded-xl border border-border px-3 py-2 text-sm"
      />
      {error && <p className="text-sm text-error">{error}</p>}
      {ok && <p className="text-sm text-green-700">Sent. Live updates arrive automatically.</p>}
      <button
        type="submit"
        disabled={busy}
        className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
      >
        {busy ? "Sending…" : "Send"}
      </button>
    </form>
  );
}
