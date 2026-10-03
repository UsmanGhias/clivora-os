import { redirect } from "next/navigation";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { ClientCard, ClientPageHeader, money } from "@/components/client/ui";
import { ArrowLeftRight } from "lucide-react";

export const metadata = { title: "Transactions" };

export default async function TransactionsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (!isClientAccount(profile)) redirect("/app/earnings");

  const supabase = await createClient();
  let rows: Array<{
    share_id: string;
    invoice_number?: string | null;
    total?: number | null;
    status?: string | null;
    updated_at?: string | null;
  }> = [];

  try {
    const invoiceFilter = profile.email
      ? `client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`
      : `client_uid.eq.${profile.id}`;
    const { data } = await supabase
      .from("invoice_shares")
      .select("share_id, invoice_number, total, status, updated_at")
      .or(invoiceFilter)
      .order("updated_at", { ascending: false })
      .limit(40);
    if (data) rows = data;
  } catch {
    rows = [];
  }

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader
        title="Transactions"
        subtitle="A chronological view of invoice-related payment activity."
        icon={ArrowLeftRight}
      />
      <ClientCard>
        {rows.length === 0 ? (
          <p className="text-sm text-text-secondary">No transactions yet.</p>
        ) : (
          <ul className="divide-y divide-border">
            {rows.map((r) => (
              <li key={r.share_id} className="flex items-center justify-between gap-3 py-3">
                <div>
                  <p className="font-semibold text-navy">{r.invoice_number || "Invoice"}</p>
                  <p className="text-xs capitalize text-text-muted">{r.status || "pending"}</p>
                </div>
                <div className="text-right">
                  <p className="font-bold text-navy">{money(Number(r.total) || 0)}</p>
                  <p className="text-xs text-text-muted">
                    {r.updated_at ? new Date(r.updated_at).toLocaleDateString() : "-"}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </ClientCard>
    </div>
  );
}
