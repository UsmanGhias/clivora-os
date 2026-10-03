import { redirect } from "next/navigation";
import { getProfile, isClientAccount } from "@/lib/profile";
import { listClientProposals, listFreelancerProposals } from "@/lib/connect-proposals";
import { ClientProposalsPanel } from "@/components/proposals/ClientProposalsPanel";
import { FreelancerProposalsPanel } from "@/components/proposals/FreelancerProposalsPanel";

export const metadata = { title: "Proposals" };

export default async function ProposalsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const client = isClientAccount(profile);
  const proposals = client
    ? await listClientProposals(profile.id)
    : await listFreelancerProposals(profile.id);

  return client ? (
    <ClientProposalsPanel proposals={proposals} />
  ) : (
    <FreelancerProposalsPanel proposals={proposals} />
  );
}
