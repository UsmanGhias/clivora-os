import { createClient } from "@/lib/supabase/server";
import { getProfile, isClientAccount } from "@/lib/profile";
import { MessagesThreadView } from "./MessagesThreadView";

export type MessageRow = {
  id: string;
  body?: string | null;
  subject?: string | null;
  created_at?: string | null;
  from_email?: string | null;
  to_email?: string | null;
  from_uid?: string | null;
  to_uid?: string | null;
  parent_message_id?: string | null;
  read_at?: string | null;
  is_read?: boolean | null;
  attachments?: unknown;
};

export default async function MessagesPage({
  searchParams,
}: {
  searchParams?: Promise<{ to?: string }>;
}) {
  const profile = await getProfile();
  const supabase = await createClient();
  const uid = profile?.id ?? "";
  const isClient = isClientAccount(profile);
  let rows: MessageRow[] = [];
  const params = (await searchParams) ?? {};
  const prefillToUid = params.to?.trim() || null;

  try {
    const email = (profile?.email || "").trim().toLowerCase();
    let q = supabase
      .from("client_messages")
      .select(
        "id, body, subject, created_at, from_email, to_email, from_uid, to_uid, parent_message_id, read_at, is_read, attachments",
      )
      .order("created_at", { ascending: true })
      .limit(200);
    if (email) {
      q = q.or(
        `from_uid.eq.${uid},to_uid.eq.${uid},from_email.eq.${email},to_email.eq.${email}`,
      );
    } else {
      q = q.or(`from_uid.eq.${uid},to_uid.eq.${uid}`);
    }
    const { data, error } = await q;
    if (!error && data) rows = data;
  } catch {
    rows = [];
  }

  return (
    <div className="flex min-h-[calc(100vh-7.5rem)] flex-col gap-4 pb-4">
      <div className="shrink-0">
        <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">Messages</h1>
        <p className="mt-1 text-sm text-text-secondary">
          {isClient
            ? "Talk with freelancers after Connect accept or on shared work."
            : "Talk with clients after Connect accept, share files, and keep conversations in one place."}
        </p>
      </div>
      <div className="min-h-0 flex-1">
        <MessagesThreadView
          rows={rows}
          fromEmail={profile?.email ?? ""}
          myUid={uid}
          isClient={isClient}
          prefillToUid={prefillToUid}
        />
      </div>
    </div>
  );
}
