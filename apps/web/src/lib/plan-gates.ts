import type { Profile } from "@/lib/profile-types";

/** Result of a create gate. Community never returns the blocked shape. */
export type GateResult = { ok: true } | { ok: false; reason: string; upgradeHref: string };

/**
 * Create gates. The Community edition imposes no client, project or invoice
 * limits, so every check succeeds. The functions remain so that callers keep a
 * single place to enforce limits if a deployment wants them.
 */
export function canCreateCustomer(_profile: Profile | null, _currentCount: number): GateResult {
  return { ok: true };
}

export function canCreateProject(_profile: Profile | null, _currentCount: number): GateResult {
  return { ok: true };
}

export function canCreateInvoice(_profile: Profile | null, _invoicesThisMonth: number): GateResult {
  return { ok: true };
}

export function invoicesCreatedThisMonth(rows: Array<{ created_at?: string | null }>) {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth();
  return rows.filter((r) => {
    if (!r.created_at) return false;
    const d = new Date(r.created_at);
    return d.getUTCFullYear() === y && d.getUTCMonth() === m;
  }).length;
}
