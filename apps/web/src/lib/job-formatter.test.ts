import { describe, expect, it } from "vitest";
import { cleanText } from "./clean-text";
import { parseJobIntoSections, getJobExecutiveSummary, formatJobDescription } from "./job-formatter";

describe("Job Formatter with Real World Crawled Job Data", () => {
  it("cleans HTML-entity encoded jobs like IonQ", () => {
    const raw = `&lt;div class=&quot;content-intro&quot;&gt;&lt;p&gt;&lt;strong&gt;About IonQ:&amp;nbsp;&lt;/strong&gt;&lt;strong&gt;&lt;br&gt;&lt;/strong&gt;&lt;/p&gt;
&lt;p&gt;IonQ is the world leader in quantum computing.&lt;/p&gt;
&lt;p&gt;&lt;strong&gt;What to expect:&lt;/strong&gt;&lt;/p&gt;
&lt;p&gt;We are looking for a Senior FPGA Verification Engineer.&lt;/p&gt;
&lt;p&gt;&lt;strong&gt;What you&#39;ll be responsible for:&lt;/strong&gt;&lt;/p&gt;
&lt;ul&gt;&lt;li&gt;Architect, develop, and maintain advanced UVM environments.&lt;/li&gt;&lt;li&gt;Define and execute verification plans.&lt;/li&gt;&lt;/ul&gt;
&lt;p&gt;&lt;strong&gt;Requirements:&lt;/strong&gt;&lt;/p&gt;
&lt;ul&gt;&lt;li&gt;Strong proficiency in SystemVerilog.&lt;/li&gt;&lt;/ul&gt;
&lt;p&gt;&lt;strong&gt;Benefits&lt;/strong&gt;&lt;/p&gt;
&lt;p&gt;Comprehensive health and stock options.&lt;/p&gt;`;

    const cleaned = cleanText(raw);
    expect(cleaned).not.toContain("&lt;");
    expect(cleaned).not.toContain("&gt;");
    expect(cleaned).not.toContain("&quot;");
    expect(cleaned).not.toContain("&amp;");
    expect(cleaned).not.toContain("<div");
    expect(cleaned).not.toContain("<p");

    const sections = parseJobIntoSections(raw);
    const titles = sections.map((s) => s.title);
    expect(titles).toContain("Key Responsibilities");
    expect(titles).toContain("Requirements & Qualifications");
    expect(titles).toContain("Benefits & Perks");

    const respSection = sections.find((s) => s.title === "Key Responsibilities");
    expect(respSection?.bullets.length).toBeGreaterThanOrEqual(2);
    expect(respSection?.bullets[0]).toContain("Architect, develop, and maintain");

    const summary = getJobExecutiveSummary(raw);
    expect(summary).not.toContain("###");
    expect(summary).not.toContain("<");
    expect(summary).not.toContain("&");
    expect(summary.length).toBeGreaterThan(20);
  });

  it("extracts sections from plain text jobs with curly apostrophes like Legora", () => {
    const raw = `About Us Legora is redefining how legal work gets done. Not built for lawyers, built with them.
The Role We are looking for a Value Engineer to join Legora in the UK.
What You’ll Do Accelerate strategic deals by partnering with Account Executives. Translate customer workflows into value.
What You’ll Bring Experience translating quantitative results. Strong communication skills.
Preferred Qualifications Fluency in French or German.
Benefits & Perks Flexible work and competitive salary.
Find Jobs in United Kingdom on Arbeitnow`;

    const cleaned = cleanText(raw);
    expect(cleaned).not.toContain("Arbeitnow");
    const sections = parseJobIntoSections(raw);
    const titles = sections.map((s) => s.title);
    expect(titles).toContain("Key Responsibilities");
    expect(titles).toContain("Requirements & Qualifications");
    expect(titles).toContain("Preferred Skills & Bonus Points");

    const summary = getJobExecutiveSummary(raw);
    expect(summary).not.toContain("###");
    expect(summary).not.toContain("Arbeitnow");
    expect(summary.length).toBeGreaterThan(20);
  });

  it("handles non-breaking hyphens, em-dashes and scraper footers like Mistral.ai", () => {
    const raw = `About Mistral Mistral provides full-stack AI solutions—across high-stakes industries.
Role summary As a Research Engineer on Forge, you’ll work end‑to‑end across model adaptation.
What you will do Build and improve post‑training and evaluation workflows. Develop tools and pipelines for synthetic data.
About you Strong Python engineering skills. Hands‑on experience with PyTorch.
Nice to have Distributed training experience (FSDP, DeepSpeed).
What We Offer Comprehensive healthcare coverage.
Find more English Speaking Jobs in France on Arbeitnow`;

    const cleaned = cleanText(raw);
    expect(cleaned).not.toContain("Arbeitnow");
    expect(cleaned).not.toContain("—"); // No em-dashes

    const sections = parseJobIntoSections(raw);
    const titles = sections.map((s) => s.title);
    expect(titles).toContain("Role Overview");
    expect(titles).toContain("Key Responsibilities");
    expect(titles).toContain("Requirements & Qualifications");
    expect(titles).toContain("Preferred Skills & Bonus Points");
    expect(titles).toContain("Benefits & Perks");

    const summary = getJobExecutiveSummary(raw);
    expect(summary).not.toContain("###");
    expect(summary).not.toContain("Arbeitnow");
    expect(summary).not.toContain("—");
  });
});
