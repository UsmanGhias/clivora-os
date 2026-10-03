import { createClient } from "@/lib/supabase/server";
import { getProfile } from "@/lib/profile";
import { SupportClient } from "./SupportClient";

export type SupportTicket = {
  id: string;
  user_id: string;
  subject: string | null;
  body: string | null;
  status: string | null;
  created_at: string | null;
};

export default async function SupportPage() {
  const profile = await getProfile();
  const supabase = await createClient();
  const uid = profile?.id ?? "";
  let tickets: SupportTicket[] = [];

  try {
    const { data } = await supabase
      .from("support_tickets")
      .select("id, user_id, subject, body, status, created_at")
      .eq("user_id", uid)
      .order("created_at", { ascending: false })
      .limit(30);
    tickets = (data ?? []) as SupportTicket[];
  } catch {
    tickets = [];
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold">Support</h1>
        <p className="text-sm text-text-secondary">
          Submit a ticket and we will get back to you via email.
        </p>
      </div>
      <SupportClient
        initial={tickets}
        userUid={uid}
        userEmail={profile?.email ?? ""}
      />
    </div>
  );
}
