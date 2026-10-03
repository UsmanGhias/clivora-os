/**
 * Integer minor-unit money helpers (Phase 0 dual-write).
 * Source of truth remains numeric columns until cutover flag; always write both.
 */
export function toMinorUnits(amount: number | string | null | undefined, fractionDigits = 2): number {
  const n = typeof amount === "string" ? Number(amount) : Number(amount ?? 0);
  if (!Number.isFinite(n)) return 0;
  // Exponential form avoids IEEE 754 cases like 1.005 * 100 === 100.4999…
  return Math.round(Number(`${n}e${fractionDigits}`));
}

export function fromMinorUnits(minor: number | null | undefined, fractionDigits = 2): number {
  const n = Number(minor ?? 0);
  if (!Number.isFinite(n)) return 0;
  const factor = 10 ** fractionDigits;
  return n / factor;
}

export function invoiceMinorFields(input: {
  subtotal?: number | null;
  taxRate?: number | null;
  discount?: number | null;
  total?: number | null;
  amountPaid?: number | null;
}) {
  const subtotal = Number(input.subtotal ?? 0);
  const taxRate = Number(input.taxRate ?? 0);
  const discount = Number(input.discount ?? 0);
  const total = Number(input.total ?? 0);
  const amountPaid = Number(input.amountPaid ?? 0);
  const taxAmount = (subtotal * taxRate) / 100;
  
  const subtotal_minor = toMinorUnits(subtotal);
  const tax_minor = toMinorUnits(taxAmount);
  const discount_minor = toMinorUnits(discount);
  // Compute total from integer minor units to guarantee arithmetic closure
  const total_minor = subtotal_minor - discount_minor + tax_minor;
  const amount_paid_minor = toMinorUnits(amountPaid);
  
  return {
    subtotal_minor,
    tax_minor,
    discount_minor,
    total_minor,
    amount_paid_minor,
  };
}
