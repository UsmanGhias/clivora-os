"use client";

import { FormEvent, useEffect, useState } from "react";
import { MessageSquare, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { asStringList } from "@/lib/crm/api";
import {
  OutlineButton,
  PrimaryButton,
  StatusPill,
} from "@/components/freelancer/ui";

type CustomerOption = {
  id: string;
  label: string;
  email: string;
};

export function RequestReviewButton({
  fromEmail,
  variant = "primary",
}: {
  fromEmail: string;
  variant?: "primary" | "outline";
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      {variant === "primary" ? (
        <PrimaryButton onClick={() => setOpen(true)}>
          <MessageSquare className="h-4 w-4" />
          Request a Review
        </PrimaryButton>
      ) : (
        <OutlineButton onClick={() => setOpen(true)}>
          <MessageSquare className="h-4 w-4" />
          Request a Review
        </OutlineButton>
      )}
      {open && (
        <RequestReviewModal fromEmail={fromEmail} onClose={() => setOpen(false)} />
      )}
    </>
  );
}

function RequestReviewModal({
  fromEmail,
  onClose,
}: {
  fromEmail: string;
  onClose: () => void;
}) {
  const [customers, setCustomers] = useState<CustomerOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedEmail, setSelectedEmail] = useState("");
  const [body, setBody] = useState(
    "Hi! If you were happy with our work together, would you mind leaving a short review on CLIVORA? It helps my Connect profile a lot. Thank you!",
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  useEffect(() => {
    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        setLoading(false);
        return;
      }
      const { data } = await supabase
        .from("crm_customers")
        .select("id, contact_person, company, emails")
        .eq("owner_uid", user.id)
        .order("updated_at", { ascending: false })
        .limit(100);
      const opts: CustomerOption[] = [];
      for (const row of data ?? []) {
        const emails = asStringList(row.emails).filter(Boolean);
        const email = emails[0];
        if (!email) continue;
        opts.push({
          id: row.id,
          email,
          label: row.contact_person || row.company || email,
        });
      }
      setCustomers(opts);
      if (opts[0]) setSelectedEmail(opts[0].email);
      setLoading(false);
    })();
  }, []);

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
      const to = selectedEmail.trim().toLowerCase();
      if (!to) throw new Error("Select a client with an email");
      const { data: profile } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", to)
        .maybeSingle();
      const { error: err } = await supabase.from("client_messages").insert({
        from_uid: user.id,
        from_email: fromEmail || user.email || "",
        to_email: to,
        to_uid: profile?.id ?? null,
        subject: "Review request",
        body: body.trim(),
        is_read: false,
      });
      if (err) throw err;
      setOk(true);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Could not send request");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-navy/40 p-4 backdrop-blur-sm">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="request-review-title"
        className="w-full max-w-lg rounded-2xl border border-border bg-surface p-5 shadow-xl"
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="request-review-title" className="font-display text-lg font-bold text-navy">
              Request a Review
            </h2>
            <p className="mt-1 text-sm text-text-secondary">
              Sends a message with subject &ldquo;Review request&rdquo; to a CRM client.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1 text-text-muted hover:bg-background"
            aria-label="Close"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <form onSubmit={onSend} className="mt-4 space-y-3">
          <label className="block text-sm font-semibold text-navy">
            Client
            {loading ? (
              <p className="mt-2 text-sm font-normal text-text-muted">Loading clients…</p>
            ) : customers.length === 0 ? (
              <p className="mt-2 text-sm font-normal text-text-secondary">
                No CRM clients with email yet. Add one under Clients first.
              </p>
            ) : (
              <select
                required
                value={selectedEmail}
                onChange={(e) => setSelectedEmail(e.target.value)}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
              >
                {customers.map((c) => (
                  <option key={c.id} value={c.email}>
                    {c.label} · {c.email}
                  </option>
                ))}
              </select>
            )}
          </label>

          <div className="flex items-center gap-2">
            <StatusPill tone="teal">Subject: Review request</StatusPill>
          </div>

          <label className="block text-sm font-semibold text-navy">
            Message
            <textarea
              required
              rows={5}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
            />
          </label>

          {error && <p className="text-sm text-error">{error}</p>}
          {ok && (
            <p className="rounded-lg bg-success/10 px-3 py-2 text-sm text-success">
              Review request sent. They will see it in Messages.
            </p>
          )}

          <div className="flex flex-wrap justify-end gap-2 pt-1">
            <OutlineButton onClick={onClose}>Close</OutlineButton>
            <PrimaryButton type="submit" disabled={busy || customers.length === 0}>
              {busy ? "Sending…" : "Send request"}
            </PrimaryButton>
          </div>
        </form>
      </div>
    </div>
  );
}
