import { redirect } from "next/navigation";
import { getProfile, isClientAccount } from "@/lib/profile";
import { ClientCard, ClientPageHeader } from "@/components/client/ui";
import { Banknote } from "lucide-react";

export const metadata = { title: "Payouts" };

export default async function PayoutsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (!isClientAccount(profile)) redirect("/app/earnings");

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader
        title="Payouts"
        subtitle="Refunds, credits, and adjustments related to your hiring activity."
        icon={Banknote}
      />
      <ClientCard>
        <p className="text-sm text-text-secondary">
          No payouts or refunds recorded yet. When a freelancer issues a refund or credit, it will
          appear here.
        </p>
      </ClientCard>
    </div>
  );
}
