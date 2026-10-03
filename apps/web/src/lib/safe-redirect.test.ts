import { describe, expect, it } from "vitest";

import { safeNextPath } from "./safe-redirect";

describe("safeNextPath", () => {
  it("keeps same-origin paths", () => {
    expect(safeNextPath("/app/invoices?tab=due")).toBe("/app/invoices?tab=due");
    expect(safeNextPath("/connect/manage")).toBe("/connect/manage");
  });

  it("falls back for missing or off-site targets", () => {
    expect(safeNextPath(null)).toBe("/app");
    expect(safeNextPath("")).toBe("/app");
    expect(safeNextPath("https://evil.example")).toBe("/app");
    expect(safeNextPath("//evil.example")).toBe("/app");
    expect(safeNextPath("/\\evil.example")).toBe("/app");
    expect(safeNextPath("javascript:alert(1)")).toBe("/app");
  });
});
