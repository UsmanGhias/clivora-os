/** Fail-open CRM RAG helpers. Never throw into Ask AI or CRM saves. */

export type CrmEmbeddingRow = {
  content?: string | null;
  entity_type?: string | null;
  source_type?: string | null;
};

export function sanitizeIlikeTerm(query: string): string {
  return query.replace(/[%_,]/g, " ").replace(/\s+/g, " ").trim().slice(0, 80);
}

export function formatEmbeddingChunk(row: CrmEmbeddingRow): string {
  const kind = row.entity_type || row.source_type || "crm";
  const content = (row.content ?? "").trim();
  if (!content) return "";
  return `[${kind}] ${content}`;
}

export function joinRetrievedContext(rows: CrmEmbeddingRow[], maxChars = 4000): string {
  return rows
    .map(formatEmbeddingChunk)
    .filter(Boolean)
    .join("\n")
    .slice(0, maxChars);
}

export function customerIndexText(row: {
  contact_person?: string | null;
  company?: string | null;
  notes?: string | null;
  status?: string | null;
}): string {
  return [
    "Client",
    row.contact_person,
    row.company,
    row.status ? `status ${row.status}` : "",
    row.notes,
  ]
    .filter((p) => p && String(p).trim())
    .join(" · ");
}

export function projectIndexText(row: {
  name?: string | null;
  description?: string | null;
  status?: string | null;
  budget?: number | null;
}): string {
  return [
    "Project",
    row.name,
    row.status ? `status ${row.status}` : "",
    row.budget != null ? `budget ${row.budget}` : "",
    row.description,
  ]
    .filter((p) => p && String(p).trim())
    .join(" · ");
}

export function invoiceIndexText(row: {
  invoice_number?: string | null;
  status?: string | null;
  total?: number | null;
  due_date?: string | null;
}): string {
  return [
    "Invoice",
    row.invoice_number,
    row.status ? `status ${row.status}` : "",
    row.total != null ? `total ${row.total}` : "",
    row.due_date ? `due ${row.due_date}` : "",
  ]
    .filter((p) => p && String(p).trim())
    .join(" · ");
}
