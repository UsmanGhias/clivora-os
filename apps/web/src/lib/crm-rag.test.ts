import { describe, expect, it } from "vitest";

import {
  customerIndexText,
  formatEmbeddingChunk,
  invoiceIndexText,
  joinRetrievedContext,
  projectIndexText,
  sanitizeIlikeTerm,
} from "./crm-rag";

describe("crm-rag formatters", () => {
  it("strips ilike wildcards from user questions", () => {
    expect(sanitizeIlikeTerm("100% overdue, _draft")).toBe("100 overdue draft");
  });

  it("formats chunks from entity_type (not the old source_type-only path)", () => {
    expect(formatEmbeddingChunk({ entity_type: "invoice", content: "INV-1 paid 200" })).toBe(
      "[invoice] INV-1 paid 200",
    );
    expect(formatEmbeddingChunk({ content: "   " })).toBe("");
  });

  it("joins retrieved rows and caps length", () => {
    const text = joinRetrievedContext(
      [
        { entity_type: "customer", content: "Ada" },
        { entity_type: "invoice", content: "INV-9" },
      ],
      40,
    );
    expect(text).toContain("[customer] Ada");
    expect(text.length).toBeLessThanOrEqual(40);
  });

  it("builds index text for CRM entities without inventing amounts", () => {
    expect(customerIndexText({ contact_person: "Ada", company: "Nova" })).toBe(
      "Client · Ada · Nova",
    );
    expect(projectIndexText({ name: "Site", budget: 1200 })).toContain("1200");
    expect(invoiceIndexText({ invoice_number: "INV-2", status: "sent", total: 90 })).toContain(
      "INV-2",
    );
  });
});
