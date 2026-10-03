import { describe, expect, it } from "vitest";
import { canCreateCustomer, canCreateInvoice, canCreateProject, invoicesCreatedThisMonth } from "./plan-gates";

describe("plan gates (Community edition)", () => {
  it("never blocks creating clients, projects or invoices", () => {
    expect(canCreateCustomer(null, 10_000).ok).toBe(true);
    expect(canCreateProject(null, 10_000).ok).toBe(true);
    expect(canCreateInvoice(null, 10_000).ok).toBe(true);
  });

  it("counts invoices created in the current UTC month", () => {
    const now = new Date();
    const lastYear = new Date(Date.UTC(now.getUTCFullYear() - 1, now.getUTCMonth(), 1));
    expect(invoicesCreatedThisMonth([{ created_at: now.toISOString() }, { created_at: lastYear.toISOString() }, {}])).toBe(1);
  });
});
