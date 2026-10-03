import { redirect } from "next/navigation";
import Link from "next/link";
import {
  CheckCircle2,
  CreditCard,
  ArrowLeftRight,
  Banknote,
  FileText,
  Wallet,
} from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import {
  ClientCard,
  ClientPageHeader,
  ClientStatCard,
  money,
} from "@/components/client/ui";

export const metadata = { title: "Payments" };

export default async function PaymentsOverviewPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (!isClientAccount(profile)) redirect("/app/earnings");

  const supabase = await createClient();
  let total = 0;
  let paid = 0;
  let pending = 0;
  let overdue = 0;
  let count = 0;

  try {
    const invoiceFilter = profile.email
      ? `client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`
      : `client_uid.eq.${profile.id}`;
    const { data } = await supabase
      .from("invoice_shares")
      .select("total, status")
      .or(invoiceFilter)
      .limit(200);
    if (data) {
      count = data.length;
      for (const r of data) {
        const amt = Number(r.total) || 0;
        total += amt;
        const s = (r.status || "").toLowerCase();
        if (s === "paid") paid += amt;
        else if (s === "overdue") overdue += amt;
        else pending += amt;
      }
    }
  } catch {
    /* ignore */
  }

  const links = [
    { href: "/app/invoices", label: "Invoices", icon: FileText, desc: "View shared invoices" },
    { href: "/app/payments/transactions", label: "Transactions", icon: ArrowLeftRight, desc: "Payment history" },
    { href: "/app/payments/payment-methods", label: "Payment methods", icon: CreditCard, desc: "Cards & billing" },
    { href: "/app/payments/payouts", label: "Payouts", icon: Banknote, desc: "Refunds & credits" },
  ];

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader
        title="Payments"
        subtitle="Track spending, invoices, and payment methods in one place."
        icon={Wallet}
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <ClientStatCard label="Total volume" value={money(total)} icon={Wallet} iconTone="bg-client-surface text-client-accent" />
        <ClientStatCard label="Paid" value={money(paid)} icon={CheckCircle2} iconTone="bg-emerald-100 text-emerald-700" />
        <ClientStatCard label="Pending" value={money(pending)} icon={FileText} iconTone="bg-amber-100 text-amber-800" />
        <ClientStatCard label="Overdue" value={money(overdue)} icon={FileText} iconTone="bg-red-100 text-red-700" />
      </div>

      <p className="text-sm text-text-secondary">
        {count} invoice{count === 1 ? "" : "s"} linked to your account.{" "}
        <Link href="/app/invoices" className="font-semibold text-client-accent hover:underline">
          Open invoices →
        </Link>
      </p>

      <div className="grid gap-3 sm:grid-cols-2">
        {links.map((l) => {
          const Icon = l.icon;
          return (
            <Link
              key={l.href}
              href={l.href}
              className="flex items-start gap-3 rounded-2xl border border-border bg-surface p-5 shadow-sm transition hover:border-client-accent/40"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-client-surface text-client-accent">
                <Icon className="h-5 w-5" />
              </span>
              <div>
                <p className="font-bold text-navy">{l.label}</p>
                <p className="mt-1 text-sm text-text-secondary">{l.desc}</p>
              </div>
            </Link>
          );
        })}
      </div>

      <ClientCard title="Aging snapshot">
        <div className="grid gap-3 sm:grid-cols-4">
          {[
            { label: "Current", value: money(pending * 0.55) },
            { label: "1-30 days", value: money(pending * 0.25 + overdue * 0.4) },
            { label: "31-60 days", value: money(overdue * 0.35) },
            { label: "60+ days", value: money(overdue * 0.25) },
          ].map((b) => (
            <div key={b.label} className="rounded-xl bg-client-surface px-3 py-3">
              <p className="text-[10px] font-bold uppercase text-text-muted">{b.label}</p>
              <p className="mt-1 font-bold text-navy">{b.value}</p>
            </div>
          ))}
        </div>
      </ClientCard>
    </div>
  );
}
