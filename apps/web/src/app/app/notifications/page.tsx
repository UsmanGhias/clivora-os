import { redirect } from "next/navigation";
import { Bell } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { getProfile, isClientAccount } from "@/lib/profile";
import { FreelancerPageHeader } from "@/components/freelancer/ui";
import { ClientPageHeader } from "@/components/client/ui";
import { NotificationsClient, type NotificationRow } from "./NotificationsClient";

export const metadata = { title: "Notifications" };

export default async function NotificationsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");

  const isClient = isClientAccount(profile);
  const supabase = await createClient();
  let rows: NotificationRow[] = [];

  try {
    const { data, error } = await supabase
      .from("notifications")
      .select("id, title, body, created_at, is_read, user_uid")
      .eq("user_uid", profile.id)
      .order("created_at", { ascending: false })
      .limit(40);
    if (!error && data) rows = data;
  } catch {
    rows = [];
  }

  const Header = isClient ? ClientPageHeader : FreelancerPageHeader;

  return (
    <div className="space-y-6 pb-10">
      <Header
        title="Notifications"
        subtitle="Cloud notifications synced from the same Supabase project."
        icon={Bell}
      />
      <NotificationsClient initial={rows} isClient={isClient} />
    </div>
  );
}
