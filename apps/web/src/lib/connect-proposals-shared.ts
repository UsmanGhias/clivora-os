import type { ConnectProposal } from "@/lib/connect";

export type ProposalRow = ConnectProposal & {
  need_title?: string | null;
  need_budget?: string | null;
  from_name?: string | null;
  to_name?: string | null;
  from_headline?: string | null;
};

export function proposalStatusLabel(status: string) {
  const s = status.toLowerCase();
  if (s === "pending") return "Pending";
  if (s === "accepted") return "Hired";
  if (s === "shortlisted") return "Shortlisted";
  if (s === "declined") return "Declined";
  if (s === "withdrawn") return "Withdrawn";
  if (s === "viewed") return "Viewed";
  return status;
}
