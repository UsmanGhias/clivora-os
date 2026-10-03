import { describe, expect, it } from "vitest";
import { isPro, isProPlus, planLabel, isClientAccount } from "./plan";
import type { Profile } from "./profile-types";

const profile = (overrides: Partial<Profile> = {}) => ({ subscription_plan: "free", ...overrides }) as Profile;

describe("plan (Community edition)", () => {
  it("treats every account as having every feature", () => {
    expect(isPro(null)).toBe(true);
    expect(isPro(profile())).toBe(true);
    expect(isProPlus(profile({ subscription_plan: "free" }))).toBe(true);
  });

  it("labels the plan as Community", () => {
    expect(planLabel(profile())).toBe("Community");
  });

  it("still distinguishes client accounts", () => {
    expect(isClientAccount(profile({ account_type: "client" } as Partial<Profile>))).toBe(true);
    expect(isClientAccount(profile({ account_type: "freelancer" } as Partial<Profile>))).toBe(false);
  });
});
