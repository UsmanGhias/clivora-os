import { MarketingNav } from "@/components/marketing/MarketingNav";
import { MarketingFooter } from "@/components/marketing/MarketingFooter";
import { MarketingJsonLd } from "@/components/marketing/MarketingJsonLd";
import React from "react";

export default function JobsLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-[#F8FAFC] text-navy antialiased">
      <MarketingJsonLd />
      <MarketingNav />
      {children}
      <MarketingFooter />
    </div>
  );
}
