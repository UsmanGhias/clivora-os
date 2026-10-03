/** Platform hourly rate bounds (USD). */
export const HOURLY_RATE_MIN = 3;
export const HOURLY_RATE_MAX = 500;

/** Clamp a rate into [$3, $500]. Returns null if not a usable positive number. */
export function clampHourlyRate(n: unknown): number | null {
  const v = typeof n === "number" ? n : Number(n);
  if (!Number.isFinite(v) || v <= 0) return null;
  return Math.min(HOURLY_RATE_MAX, Math.max(HOURLY_RATE_MIN, Math.round(v * 100) / 100));
}

/**
 * Parse Connect `rate_band` strings like "$200-500/hr" or "3-50".
 * Never concatenates range digits (bug that produced 200500).
 */
export function parseHourlyFromRateBand(rateBand: string | null | undefined): number | null {
  const s = String(rateBand ?? "").trim();
  if (!s) return null;

  const range = s.match(/(\d+(?:\.\d+)?)\s*(?:-|to|\/)\s*(\d+(?:\.\d+)?)/i);
  if (range) {
    const a = Number(range[1]);
    const b = Number(range[2]);
    if (Number.isFinite(a) && Number.isFinite(b) && a > 0 && b > 0) {
      // Prefer the lower bound as the working rate ( freelancers often list min-max ).
      return clampHourlyRate(Math.min(a, b));
    }
  }

  const single = s.match(/(\d+(?:\.\d+)?)/);
  if (single) return clampHourlyRate(Number(single[1]));
  return null;
}

/** Resolve billable $/hr for a project: hourly budget when pricing is hourly, else profile default. */
export function resolveProjectHourlyRate(opts: {
  pricingType?: string | null;
  budget?: number | null;
  hourlyRate?: number | null;
  defaultHourlyRate?: number | null;
}): number {
  const explicit = clampHourlyRate(opts.hourlyRate);
  if (explicit != null) return explicit;

  const isHourly = String(opts.pricingType ?? "").toLowerCase() === "hourly";
  if (isHourly) {
    const fromBudget = clampHourlyRate(opts.budget);
    if (fromBudget != null) return fromBudget;
  }

  return clampHourlyRate(opts.defaultHourlyRate) ?? 0;
}
