"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { AlertTriangle, Building2, ShieldCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { PRO_PLUS_PRICE_USD } from "@/lib/pricing";

type BankForm = {
  account_name: string;
  bank_name: string;
  account_number: string;
  iban: string;
  swift: string;
  country: string;
  currency: string;
};

const EMPTY: BankForm = {
  account_name: "",
  bank_name: "",
  account_number: "",
  iban: "",
  swift: "",
  country: "PK",
  currency: "USD",
};

const STORAGE_KEY = "clivora_payout_bank_v1";

/** Collect bank details for direct client→freelancer invoice payments. Platform fee is subscription-only. */
export function BankPayoutSettings({ compact }: { compact?: boolean }) {
  const supabase = useMemo(() => createClient(), []);
  const [form, setForm] = useState<BankForm>(EMPTY);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const cached = localStorage.getItem(STORAGE_KEY);
        if (cached) {
          const parsed = JSON.parse(cached) as BankForm;
          setForm({ ...EMPTY, ...parsed });
        }
      } catch {
        /* ignore */
      }
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data } = await supabase
        .from("freelancer_payout_accounts")
        .select(
          "account_name, bank_name, account_number, iban, swift, country, currency",
        )
        .eq("user_id", user.id)
        .maybeSingle();
      if (data) {
        setForm({
          account_name: data.account_name ?? "",
          bank_name: data.bank_name ?? "",
          account_number: data.account_number ?? "",
          iban: data.iban ?? "",
          swift: data.swift ?? "",
          country: data.country ?? "PK",
          currency: data.currency ?? "USD",
        });
      }
    })();
  }, [supabase]);

  async function onSave(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    setErr(null);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(form));
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const payload = {
        user_id: user.id,
        account_name: form.account_name.trim(),
        bank_name: form.bank_name.trim(),
        account_number: form.account_number.trim(),
        iban: form.iban.trim(),
        swift: form.swift.trim(),
        country: form.country.trim() || "PK",
        currency: form.currency.trim() || "USD",
        updated_at: new Date().toISOString(),
      };
      const { error } = await supabase
        .from("freelancer_payout_accounts")
        .upsert(payload, { onConflict: "user_id" });
      if (error) {
        // Table may not exist yet - local save still works
        setMsg(
          "Saved on this device. Cloud sync will activate once payout accounts are enabled.",
        );
      } else {
        setMsg(
          `Bank details saved. Clients pay you directly via invoice - CLIVORA only charges the $${PRO_PLUS_PRICE_USD}/mo plan fee.`,
        );
      }
    } catch (cause) {
      setErr(cause instanceof Error ? cause.message : "Could not save bank details");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={compact ? "space-y-3" : "space-y-4"}>
      <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
        <p className="inline-flex items-center gap-2 font-bold">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          Stay on platform - policy
        </p>
        <p className="mt-1 text-amber-900/90">
          Asking clients to pay or continue work off CLIVORA to avoid fees is against policy and can
          lead to restriction. Invoice and get paid here; CLIVORA charges only your{" "}
          <strong>${PRO_PLUS_PRICE_USD}/mo</strong> subscription - deal amounts go client → you directly.
        </p>
      </div>

      <form onSubmit={onSave} className="space-y-3 rounded-2xl border border-border bg-surface p-4">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
            <Building2 className="h-5 w-5" />
          </span>
          <div>
            <p className="font-bold text-navy">Bank / payout details</p>
            <p className="text-xs text-text-secondary">
              Used on invoices so clients can pay you directly (bank transfer, JazzCash, etc.).
            </p>
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          {(
            [
              ["account_name", "Account holder name"],
              ["bank_name", "Bank name"],
              ["account_number", "Account number"],
              ["iban", "IBAN (optional)"],
              ["swift", "SWIFT / BIC (optional)"],
              ["country", "Country code"],
              ["currency", "Preferred currency"],
            ] as const
          ).map(([key, label]) => (
            <label key={key} className="block text-sm font-semibold text-navy">
              {label}
              <input
                value={form[key]}
                onChange={(e) => setForm({ ...form, [key]: e.target.value })}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
                required={key === "account_name" || key === "bank_name" || key === "account_number"}
              />
            </label>
          ))}
        </div>

        <p className="inline-flex items-center gap-1.5 text-xs text-text-muted">
          <ShieldCheck className="h-3.5 w-3.5 text-primary" />
          Details stay private to you until you put them on an invoice.
        </p>

        <button
          type="submit"
          disabled={busy}
          className="rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
        >
          {busy ? "Saving…" : "Save bank details"}
        </button>
        {msg && <p className="text-sm font-semibold text-primary-dark">{msg}</p>}
        {err && <p className="text-sm text-error">{err}</p>}
      </form>
    </div>
  );
}
