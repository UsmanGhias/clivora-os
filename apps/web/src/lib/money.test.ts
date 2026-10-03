import { describe, expect, it } from "vitest";
import { fromMinorUnits, invoiceMinorFields, toMinorUnits } from "./money";

describe("toMinorUnits", () => {
  it("converts major units to integer cents", () => {
    expect(toMinorUnits(12.34)).toBe(1234);
    expect(toMinorUnits("99.99")).toBe(9999);
    expect(toMinorUnits(null)).toBe(0);
    expect(toMinorUnits(Number.NaN)).toBe(0);
  });

  it("rounds half-up at the fraction boundary", () => {
    expect(toMinorUnits(1.005)).toBe(101);
  });
});

describe("fromMinorUnits", () => {
  it("converts cents back to major units", () => {
    expect(fromMinorUnits(1234)).toBe(12.34);
    expect(fromMinorUnits(undefined)).toBe(0);
  });
});

describe("invoiceMinorFields", () => {
  it("dual-writes all money fields as integers", () => {
    const fields = invoiceMinorFields({
      subtotal: 100,
      taxRate: 10,
      discount: 5,
      total: 105,
      amountPaid: 20,
    });
    expect(fields).toEqual({
      subtotal_minor: 10000,
      tax_minor: 1000,
      discount_minor: 500,
      total_minor: 10500,
      amount_paid_minor: 2000,
    });
  });
});
