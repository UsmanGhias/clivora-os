"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  deleteCrmRow,
  upsertCustomerClient,
  upsertInvoiceClient,
  upsertProjectClient,
  asStringList,
  type CrmCustomer,
  type CrmInvoice,
  type CrmProject,
} from "@/lib/crm/api";
import { createClient } from "@/lib/supabase/client";

type CustomFields = Record<string, string>;

const PROJECT_STATUS_LABELS: Record<string, string> = {
  not_started: "Backlog",
  in_progress: "In progress",
  on_hold: "On hold",
  completed: "Done",
};

const PROJECT_PROGRESS: Record<string, number> = {
  not_started: 10,
  in_progress: 55,
  on_hold: 35,
  completed: 100,
};

function normalizeProjectStatus(status?: string | null) {
  const value = (status || "not_started").toLowerCase().replace(/\s+/g, "_");
  if (value === "active" || value === "ongoing") return "in_progress";
  if (value === "done" || value === "complete") return "completed";
  if (value in PROJECT_STATUS_LABELS) return value;
  return "not_started";
}

function ProjectStatusPill({ status }: { status?: string | null }) {
  const normalized = normalizeProjectStatus(status);
  const className =
    normalized === "completed"
      ? "bg-success/10 text-success"
      : normalized === "in_progress"
        ? "bg-primary/10 text-primary-dark"
        : normalized === "on_hold"
          ? "bg-amber-100 text-amber-900"
          : "bg-slate-100 text-slate-700";
  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-bold ${className}`}>
      {PROJECT_STATUS_LABELS[normalized]}
    </span>
  );
}

function ProjectProgress({ status }: { status?: string | null }) {
  const normalized = normalizeProjectStatus(status);
  const pct = PROJECT_PROGRESS[normalized] ?? 10;
  return (
    <div className="mt-2 flex items-center gap-2">
      <div className="h-1.5 w-28 overflow-hidden rounded-full bg-background">
        <div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} />
      </div>
      <span className="text-[11px] font-semibold text-text-muted">{pct}%</span>
    </div>
  );
}

function parseCustomFields(raw: unknown): CustomFields {
  if (!raw) return {};
  if (typeof raw === "object" && !Array.isArray(raw)) {
    const out: CustomFields = {};
    for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
      if (typeof k === "string" && k.trim()) out[k] = v == null ? "" : String(v);
    }
    return out;
  }
  if (typeof raw === "string" && raw.trim().startsWith("{")) {
    try {
      return parseCustomFields(JSON.parse(raw));
    } catch {
      return {};
    }
  }
  return {};
}

function CustomFieldsEditor({ customerId, initialFields }: { customerId: string; initialFields: CustomFields }) {
  const router = useRouter();
  const [fields, setFields] = useState<CustomFields>(initialFields);
  const [newKey, setNewKey] = useState("");
  const [newVal, setNewVal] = useState("");
  const [busy, setBusy] = useState(false);
  const [ok, setOk] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(updated: CustomFields) {
    setBusy(true);
    setOk(false);
    setError(null);
    try {
      const supabase = createClient();
      const { error: err } = await supabase
        .from("crm_customers")
        .update({ custom_fields: updated, updated_at: new Date().toISOString() })
        .eq("id", customerId);
      if (err) {
        // Fallback: persist as JSON in notes prefix if column/RLS blocks custom_fields
        const marker = "<!--CLIVORA_CUSTOM_FIELDS-->";
        const { data: row } = await supabase
          .from("crm_customers")
          .select("notes")
          .eq("id", customerId)
          .maybeSingle();
        const notes = String(row?.notes || "");
        const cleaned = notes.includes(marker)
          ? notes.slice(0, notes.indexOf(marker)).trimEnd()
          : notes;
        const nextNotes = `${cleaned}\n${marker}${JSON.stringify(updated)}`.trim();
        const { error: noteErr } = await supabase
          .from("crm_customers")
          .update({ notes: nextNotes, updated_at: new Date().toISOString() })
          .eq("id", customerId);
        if (noteErr) {
          throw new Error(
            err.message?.includes("custom_fields")
              ? `Custom fields unavailable (${err.message}). Also could not save to notes: ${noteErr.message}`
              : err.message || "Save failed",
          );
        }
        setFields(updated);
        setOk(true);
        router.refresh();
        return;
      }
      setFields(updated);
      setOk(true);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  function addField() {
    if (!newKey.trim()) return;
    const updated = { ...fields, [newKey.trim()]: newVal };
    setNewKey("");
    setNewVal("");
    save(updated);
  }

  function removeField(key: string) {
    const updated = { ...fields };
    delete updated[key];
    save(updated);
  }

  return (
    <div className="mt-2 space-y-2 rounded-xl border border-dashed border-border bg-background p-3">
      <p className="text-xs font-semibold text-text-secondary">Custom fields</p>
      {Object.entries(fields).map(([k, v]) => (
        <div key={k} className="flex items-center gap-2">
          <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-mono text-slate-700">{k}</span>
          <span className="flex-1 text-xs text-text-primary truncate">{v}</span>
          <button
            type="button"
            onClick={() => removeField(k)}
            disabled={busy}
            className="text-[10px] text-error hover:underline"
          >
            ×
          </button>
        </div>
      ))}
      <div className="flex gap-1">
        <input
          placeholder="key"
          value={newKey}
          onChange={(e) => setNewKey(e.target.value)}
          className="w-24 rounded-lg border border-border px-2 py-1 text-xs"
        />
        <input
          placeholder="value"
          value={newVal}
          onChange={(e) => setNewVal(e.target.value)}
          className="flex-1 rounded-lg border border-border px-2 py-1 text-xs"
          onKeyDown={(e) => e.key === "Enter" && addField()}
        />
        <button
          type="button"
          onClick={addField}
          disabled={busy || !newKey.trim()}
          className="rounded-lg bg-navy px-2 py-1 text-[10px] font-semibold text-white disabled:opacity-50"
        >
          Add
        </button>
      </div>
      {ok && <p className="text-[10px] text-green-700">Saved.</p>}
      {error && <p className="text-[10px] text-error">{error}</p>}
    </div>
  );
}

export function CustomersCrmPanel({
  initial,
  canCreate,
  gateReason,
  upgradeHref,
}: {
  initial: CrmCustomer[];
  canCreate: boolean;
  gateReason?: string;
  upgradeHref?: string;
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [name, setName] = useState("");
  const [company, setCompany] = useState("");
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!canCreate) return;
    setBusy(true);
    setError(null);
    try {
      const id = await upsertCustomerClient({
        contact_person: name,
        company,
        emails: email.trim() ? [email.trim().toLowerCase()] : [],
      });
      setRows((prev) => [
        {
          id,
          owner_uid: "",
          local_id: null,
          contact_person: name.trim(),
          company: company.trim(),
          emails: email.trim() ? [email.trim().toLowerCase()] : [],
          phones: [],
          whatsapp: "",
          address: "",
          city: "",
          postal_code: "",
          country: "",
          notes: "",
          status: "active",
          updated_at: new Date().toISOString(),
        },
        ...prev,
      ]);
      setName("");
      setCompany("");
      setEmail("");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save client");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(id: string) {
    if (!confirm("Delete this client from cloud CRM?")) return;
    setBusy(true);
    try {
      await deleteCrmRow("crm_customers", id);
      setRows((prev) => prev.filter((r) => r.id !== id));
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <form onSubmit={onCreate} className="rounded-2xl border border-border bg-surface p-4 space-y-3">
        <p className="text-sm font-semibold text-navy">Add client (cloud)</p>
        {!canCreate && (
          <p className="rounded-lg bg-primary/10 px-3 py-2 text-sm text-navy">
            {gateReason}{" "}
            {upgradeHref && (
              <Link href={upgradeHref} className="font-semibold text-primary underline">
                Upgrade
              </Link>
            )}
          </p>
        )}
        <div className="grid gap-2 sm:grid-cols-3">
          <label className="block text-xs font-semibold text-text-secondary">
            Contact name
            <input
              required
              disabled={!canCreate || busy}
              placeholder="Jane Client"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Company
            <input
              disabled={!canCreate || busy}
              placeholder="Company name"
              value={company}
              onChange={(e) => setCompany(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Email
            <input
              type="email"
              disabled={!canCreate || busy}
              placeholder="client@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
        </div>
        {error && <p className="text-sm text-error">{error}</p>}
        <button
          type="submit"
          disabled={!canCreate || busy}
          className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Saving…" : "Save client"}
        </button>
      </form>

      {rows.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
          <p className="font-semibold">No cloud clients yet</p>
          <p className="mt-2 text-sm text-text-secondary">
            Add one here or sync from the Android app after sign-in.
          </p>
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => {
            const emails = asStringList(r.emails);
            return (
              <CustomerRow
                key={r.id}
                r={r}
                busy={busy}
                onDelete={onDelete}
                emails={emails}
              />
            );
          })}
        </ul>
      )}
    </div>
  );
}

function CustomerRow({
  r,
  busy,
  onDelete,
  emails,
}: {
  r: CrmCustomer;
  busy: boolean;
  onDelete: (id: string) => void;
  emails: string[];
}) {
  const [showFields, setShowFields] = useState(false);
  const marker = "<!--CLIVORA_CUSTOM_FIELDS-->";
  const notesFallback =
    typeof r.notes === "string" && r.notes.includes(marker)
      ? parseCustomFields(r.notes.slice(r.notes.indexOf(marker) + marker.length))
      : {};
  const customFields = {
    ...notesFallback,
    ...parseCustomFields(r.custom_fields),
  };

  return (
    <li className="rounded-xl border border-border bg-surface px-4 py-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-semibold">{r.contact_person || "Client"}</p>
          <p className="text-sm text-text-secondary">
            {[r.company, emails[0]].filter(Boolean).join(" · ") || "No email"}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => setShowFields((v) => !v)}
            className="text-xs font-semibold text-primary"
          >
            {showFields ? "Hide fields" : "Custom fields"}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => onDelete(r.id)}
            className="text-xs font-semibold text-error"
          >
            Delete
          </button>
        </div>
      </div>
      {showFields && (
        <CustomFieldsEditor customerId={r.id} initialFields={customFields} />
      )}
    </li>
  );
}

export function ProjectsCrmPanel({
  initial,
  customers,
  canCreate,
  gateReason,
  upgradeHref,
}: {
  initial: CrmProject[];
  customers: CrmCustomer[];
  canCreate: boolean;
  gateReason?: string;
  upgradeHref?: string;
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [name, setName] = useState("");
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? "");
  const [budget, setBudget] = useState("");
  const [pricingType, setPricingType] = useState<"fixed" | "hourly">("fixed");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!canCreate) return;
    setBusy(true);
    setError(null);
    try {
      const id = await upsertProjectClient({
        name,
        customer_id: customerId || null,
        budget: Number(budget) || 0,
        pricing_type: pricingType,
      });
      setRows((prev) => [
        {
          id,
          owner_uid: "",
          local_id: null,
          customer_id: customerId || null,
          name: name.trim(),
          description: "",
          budget: Number(budget) || 0,
          currency: "USD",
          status: "not_started",
          priority: "medium",
          pricing_type: pricingType,
          deadline: null,
          updated_at: new Date().toISOString(),
        },
        ...prev,
      ]);
      setName("");
      setBudget("");
      setPricingType("fixed");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save project");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(id: string) {
    if (!confirm("Delete this project from cloud CRM?")) return;
    setBusy(true);
    try {
      await deleteCrmRow("crm_projects", id);
      setRows((prev) => prev.filter((r) => r.id !== id));
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  const customerName = (id: string | null) =>
    customers.find((c) => c.id === id)?.contact_person || "Unassigned";

  return (
    <div className="space-y-4">
      <form onSubmit={onCreate} className="rounded-2xl border border-border bg-surface p-4 space-y-3">
        <p className="text-sm font-semibold text-navy">Add project (cloud)</p>
        {!canCreate && (
          <p className="rounded-lg bg-primary/10 px-3 py-2 text-sm text-navy">
            {gateReason}{" "}
            {upgradeHref && (
              <Link href={upgradeHref} className="font-semibold text-primary underline">
                Upgrade
              </Link>
            )}
          </p>
        )}
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          <label className="block text-xs font-semibold text-text-secondary">
            Project name
            <input
              required
              disabled={!canCreate || busy}
              placeholder="Website redesign"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Client
            <select
              disabled={!canCreate || busy || customers.length === 0}
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            >
              {customers.length === 0 ? (
                <option value="">Add a client first</option>
              ) : (
                customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.contact_person}
                  </option>
                ))
              )}
            </select>
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Pricing
            <select
              disabled={!canCreate || busy}
              value={pricingType}
              onChange={(e) => setPricingType(e.target.value as "fixed" | "hourly")}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            >
              <option value="fixed">Fixed budget</option>
              <option value="hourly">Hourly ($3-$500)</option>
            </select>
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            {pricingType === "hourly" ? "Hourly rate (USD)" : "Budget"}
            <input
              disabled={!canCreate || busy}
              inputMode="decimal"
              placeholder={pricingType === "hourly" ? "45" : "2500"}
              value={budget}
              onChange={(e) => setBudget(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
        </div>
        {error && <p className="text-sm text-error">{error}</p>}
        <button
          type="submit"
          disabled={!canCreate || busy || customers.length === 0}
          className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Saving…" : "Save project"}
        </button>
      </form>

      {rows.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
          <p className="font-semibold">No cloud projects yet</p>
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => (
            <li
              key={r.id}
              className="flex items-start justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-3"
            >
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-semibold">{r.name}</p>
                  <ProjectStatusPill status={r.status} />
                </div>
                <p className="mt-1 text-sm text-text-secondary">
                  {customerName(r.customer_id)}
                  {r.budget ? ` · ${r.currency} ${r.budget}` : ""}
                </p>
                <ProjectProgress status={r.status} />
              </div>
              <button
                type="button"
                disabled={busy}
                onClick={() => onDelete(r.id)}
                className="text-xs font-semibold text-error"
              >
                Delete
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export function InvoicesCrmPanel({
  initial,
  customers,
  projects,
  canCreate,
  gateReason,
  upgradeHref,
}: {
  initial: CrmInvoice[];
  customers: CrmCustomer[];
  projects: CrmProject[];
  canCreate: boolean;
  gateReason?: string;
  upgradeHref?: string;
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [number, setNumber] = useState(`INV-${Date.now().toString().slice(-6)}`);
  const [customerId, setCustomerId] = useState(customers[0]?.id ?? "");
  const [projectId, setProjectId] = useState("");
  const [total, setTotal] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [draftImportNotice, setDraftImportNotice] = useState<{
    invoiceNumber: string;
    clientName: string;
    total: number;
    currency: string;
  } | null>(null);

  useEffect(() => {
    try {
      const raw = localStorage.getItem("clivora_draft_invoice");
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed?.invoiceNumber || parsed?.total) {
          setDraftImportNotice({
            invoiceNumber: parsed.invoiceNumber || "INV-DRAFT",
            clientName: parsed.clientName || "Client",
            total: parsed.total || 0,
            currency: parsed.currency || "USD",
          });
        }
      }
    } catch {
      // ignore
    }
  }, []);

  function applyDraftImport() {
    try {
      const raw = localStorage.getItem("clivora_draft_invoice");
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed.invoiceNumber) setNumber(parsed.invoiceNumber);
        if (parsed.total) setTotal(String(parsed.total));
        if (parsed.clientName && customers.length > 0) {
          const match = customers.find(
            (c) =>
              (c.company && c.company.toLowerCase() === parsed.clientName.toLowerCase()) ||
              (c.contact_person && c.contact_person.toLowerCase() === parsed.clientName.toLowerCase())
          );
          if (match) setCustomerId(match.id);
        }
      }
      localStorage.removeItem("clivora_draft_invoice");
      setDraftImportNotice(null);
    } catch {
      // ignore
    }
  }

  function dismissDraftImport() {
    try {
      localStorage.removeItem("clivora_draft_invoice");
      setDraftImportNotice(null);
    } catch {
      // ignore
    }
  }

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!canCreate) return;
    setBusy(true);
    setError(null);
    try {
      const id = await upsertInvoiceClient({
        invoice_number: number,
        customer_id: customerId || null,
        project_id: projectId || null,
        total: Number(total) || 0,
        status: "draft",
      });
      setRows((prev) => [
        {
          id,
          owner_uid: "",
          local_id: null,
          customer_id: customerId || null,
          project_id: projectId || null,
          invoice_number: number.trim(),
          status: "draft",
          total: Number(total) || 0,
          currency: "USD",
          line_items: [],
          due_date: null,
          updated_at: new Date().toISOString(),
        },
        ...prev,
      ]);
      setNumber(`INV-${Date.now().toString().slice(-6)}`);
      setTotal("");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save invoice");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete(id: string) {
    if (!confirm("Delete this invoice from cloud CRM?")) return;
    setBusy(true);
    try {
      await deleteCrmRow("crm_invoices", id);
      setRows((prev) => prev.filter((r) => r.id !== id));
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      {draftImportNotice && (
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 rounded-2xl border border-teal-200 bg-teal-50/90 p-4 text-xs text-teal-950 shadow-xs">
          <div className="flex items-center gap-2.5">
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-teal-600 text-white font-bold text-[10px]">
              ✓
            </span>
            <span>
              Found draft invoice <strong>{draftImportNotice.invoiceNumber}</strong> ({draftImportNotice.currency} {Number(draftImportNotice.total).toLocaleString()}) from the Free Invoice Generator.
            </span>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              onClick={applyDraftImport}
              className="rounded-xl bg-teal-700 px-3 py-1.5 font-bold text-white hover:bg-teal-800 transition shadow-2xs"
            >
              Populate Form
            </button>
            <button
              type="button"
              onClick={dismissDraftImport}
              className="rounded-xl border border-slate-300 bg-white px-3 py-1.5 font-semibold text-slate-600 hover:bg-slate-50 transition"
            >
              Dismiss
            </button>
          </div>
        </div>
      )}

      <form onSubmit={onCreate} className="rounded-2xl border border-border bg-surface p-4 space-y-3">
        <p className="text-sm font-semibold text-navy">Add invoice (cloud)</p>
        {!canCreate && (
          <p className="rounded-lg bg-primary/10 px-3 py-2 text-sm text-navy">
            {gateReason}{" "}
            {upgradeHref && (
              <Link href={upgradeHref} className="font-semibold text-primary underline">
                Upgrade
              </Link>
            )}
          </p>
        )}
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          <label className="block text-xs font-semibold text-text-secondary">
            Invoice number
            <input
              required
              disabled={!canCreate || busy}
              placeholder="INV-001"
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Client
            <select
              disabled={!canCreate || busy || customers.length === 0}
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            >
              {customers.length === 0 ? (
                <option value="">Add a client first</option>
              ) : (
                customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.contact_person}
                  </option>
                ))
              )}
            </select>
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Project
            <select
              disabled={!canCreate || busy}
              value={projectId}
              onChange={(e) => setProjectId(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            >
              <option value="">No project</option>
              {projects.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Total
            <input
              disabled={!canCreate || busy}
              inputMode="decimal"
              placeholder="1200"
              value={total}
              onChange={(e) => setTotal(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            />
          </label>
        </div>
        {error && <p className="text-sm text-error">{error}</p>}
        <button
          type="submit"
          disabled={!canCreate || busy || customers.length === 0}
          className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Saving…" : "Save invoice"}
        </button>
      </form>

      {rows.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
          <p className="font-semibold">No cloud invoices yet</p>
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => (
            <li
              key={r.id}
              className="flex items-center justify-between rounded-xl border border-border bg-surface px-4 py-3"
            >
              <div>
                <p className="font-semibold">{r.invoice_number}</p>
                <p className="text-sm text-text-secondary">{r.status}</p>
              </div>
              <div className="flex items-center gap-3">
                <p className="font-bold">
                  {r.currency} {Number(r.total ?? 0).toFixed(2)}
                </p>
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => onDelete(r.id)}
                  className="text-xs font-semibold text-error"
                >
                  Delete
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
