import { createBrowserSupabaseClient } from "@/lib/supabase-browser";

type InvoiceShare = {
  invoice_number: string | null;
  total: number | null;
  currency: string | null;
  status: string | null;
  due_date: string | null;
  payment_method: string | null;
};

// Guest lookup goes through invoice_share_by_token, not a table read. A table
// read here would be authorised by RLS before the token filter is applied, so
// the filter would be advisory only and any anon caller could enumerate every
// shared invoice. The function takes the token as an argument and returns at
// most the one matching row, display columns only.
async function loadShare(token: string): Promise<InvoiceShare | null> {
  const supabase = createBrowserSupabaseClient();
  const { data, error } = await supabase.rpc("invoice_share_by_token", {
    p_token: token,
  });

  if (error) return null;
  const row = Array.isArray(data) ? data[0] : data;
  return (row as InvoiceShare) ?? null;
}

export default async function PublicInvoicePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const resolved = await params;
  const share = await loadShare(resolved.token);

  if (!share) {
    return (
      <main className="min-h-screen bg-slate-50 px-6 py-16 text-slate-900">
        <div className="mx-auto max-w-lg rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
          <h1 className="text-2xl font-semibold tracking-tight">Invoice not found</h1>
          <p className="mt-3 text-sm text-slate-600">
            This public invoice link is invalid or has expired.
          </p>
        </div>
      </main>
    );
  }

  const due = share.due_date
    ? new Date(share.due_date).toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "numeric",
      })
    : "-";
  const total = Number(share.total ?? 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return (
    <main className="min-h-screen bg-slate-50 px-6 py-16 text-slate-900">
      <div className="mx-auto max-w-lg rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
        <p className="text-xs font-medium uppercase tracking-[0.2em] text-teal-700">
          CLIVORA
        </p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight">
          {share.invoice_number || "Invoice"}
        </h1>
        <p className="mt-2 text-sm text-slate-600">Read-only guest view</p>

        <dl className="mt-8 space-y-4 text-sm">
          <div className="flex items-baseline justify-between gap-4 border-b border-slate-100 pb-3">
            <dt className="text-slate-500">Total</dt>
            <dd className="text-xl font-semibold">
              {share.currency || "USD"} {total}
            </dd>
          </div>
          <div className="flex items-baseline justify-between gap-4 border-b border-slate-100 pb-3">
            <dt className="text-slate-500">Status</dt>
            <dd className="font-medium capitalize">
              {(share.status || "unknown").replaceAll("_", " ")}
            </dd>
          </div>
          <div className="flex items-baseline justify-between gap-4 border-b border-slate-100 pb-3">
            <dt className="text-slate-500">Due date</dt>
            <dd className="font-medium">{due}</dd>
          </div>
          {share.payment_method ? (
            <div className="flex items-baseline justify-between gap-4">
              <dt className="text-slate-500">Payment method</dt>
              <dd className="font-medium">{share.payment_method}</dd>
            </div>
          ) : null}
        </dl>
      </div>
    </main>
  );
}
