import { redirect } from "next/navigation";
import { FileText } from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { ContractsClient, type ContractRow } from "./ContractsClient";

export const metadata = { title: "Contracts" };

const CONTRACT_PREFIX = "[Contract]";
const SIGNED_PREFIX = "[Contract Signed]";

function parseContract(row: {
  id: string;
  subject?: string | null;
  body?: string | null;
  created_at?: string | null;
  from_email?: string | null;
  to_email?: string | null;
}): ContractRow | null {
  const subject = (row.subject || "").trim();
  if (!subject.startsWith(CONTRACT_PREFIX) && !subject.startsWith(SIGNED_PREFIX)) {
    return null;
  }
  const signed = subject.startsWith(SIGNED_PREFIX);
  const title = subject
    .replace(SIGNED_PREFIX, "")
    .replace(CONTRACT_PREFIX, "")
    .trim();
  return {
    id: row.id,
    title: title || "Agreement",
    status: signed ? "signed" : "sent",
    body: row.body || "",
    created_at: row.created_at || null,
    from_email: row.from_email || null,
    to_email: row.to_email || null,
  };
}

export default async function ContractsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const isClient = isClientAccount(profile);
  const supabase = await createClient();
  const uid = profile.id;
  const email = (profile.email || "").trim().toLowerCase();

  let contracts: ContractRow[] = [];
  try {
    let q = supabase
      .from("client_messages")
      .select("id, subject, body, created_at, from_email, to_email, from_uid, to_uid")
      .order("created_at", { ascending: false })
      .limit(200);
    if (email) {
      q = q.or(
        `from_uid.eq.${uid},to_uid.eq.${uid},from_email.eq.${email},to_email.eq.${email}`,
      );
    } else {
      q = q.or(`from_uid.eq.${uid},to_uid.eq.${uid}`);
    }
    const { data, error } = await q;
    if (!error && data) {
      const byTitle = new Map<string, ContractRow>();
      for (const row of data) {
        const parsed = parseContract(row);
        if (!parsed) continue;
        const existing = byTitle.get(parsed.title);
        if (!existing) {
          byTitle.set(parsed.title, parsed);
          continue;
        }
        const preferSigned =
          parsed.status === "signed" && existing.status !== "signed";
        const preferNewer =
          (parsed.created_at || "") > (existing.created_at || "") &&
          !(existing.status === "signed" && parsed.status !== "signed");
        if (preferSigned || preferNewer) {
          byTitle.set(parsed.title, parsed);
        }
      }
      contracts = [...byTitle.values()].sort((a, b) =>
        (b.created_at || "").localeCompare(a.created_at || ""),
      );
    }
  } catch {
    contracts = [];
  }

  return (
    <div className="space-y-6 pb-10">
      <div>
        <h1 className="flex items-center gap-2 font-display text-2xl font-extrabold text-navy sm:text-3xl">
          <FileText className="h-7 w-7" />
          Contracts
        </h1>
        <p className="mt-1 text-sm text-text-secondary">
          {isClient
            ? "Agreements sent by freelancers. Signed contracts are read-only."
            : "Contracts you sent to clients. Signed agreements stay locked."}
        </p>
      </div>
      <ContractsClient initial={contracts} isClient={isClient} />
    </div>
  );
}
