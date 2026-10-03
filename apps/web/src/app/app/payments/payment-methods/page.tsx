import { CreditCard } from "lucide-react";
import { redirect } from "next/navigation";
import { getProfile, isClientAccount } from "@/lib/profile";
import { ClientCard, ClientPageHeader } from "@/components/client/ui";

export const dynamic = "force-dynamic";

export default async function PaymentMethodsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (!isClientAccount(profile)) redirect("/app");
  return (
    <div className="space-y-6">
      <ClientPageHeader
        title="Payment methods"
        subtitle="How invoices are paid on this deployment."
        icon={CreditCard}
      />
      <ClientCard title="Direct settlement">
        <p className="text-sm text-text-secondary">
          CLIVORA does not hold or route funds. Clients pay freelancers directly using the bank, card or wallet details
          shown on each invoice, and both sides record the payment against the invoice and its milestone.
        </p>
      </ClientCard>
    </div>
  );
}
