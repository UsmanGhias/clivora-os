import { redirect } from "next/navigation";
import Link from "next/link";
import { Briefcase, Mail, Users } from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientStatCard,
  ClientStatusPill,
} from "@/components/client/ui";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  PrimaryButton,
  StatusPill,
} from "@/components/freelancer/ui";
import { TeamInviteForm } from "./TeamInviteForm";
import { TeamInviteActions } from "./TeamInviteActions";

export const metadata = { title: "Team" };

type TeamInvite = {
  id: string;
  owner_uid: string;
  invitee_email: string;
  invitee_name: string | null;
  invitee_uid: string | null;
  role: string | null;
  project_name: string | null;
  status: string | null;
  created_at: string | null;
  responded_at: string | null;
};

export default async function TeamPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const isClient = isClientAccount(profile);
  const supabase = await createClient();

  let owned: TeamInvite[] = [];
  let incoming: TeamInvite[] = [];

  try {
    const email = (profile.email || "").toLowerCase();
    const [{ data: ownedRows }, { data: byUid }, { data: byEmail }] = await Promise.all([
      supabase
        .from("team_invites")
        .select(
          "id, owner_uid, invitee_email, invitee_name, invitee_uid, role, project_name, status, created_at, responded_at",
        )
        .eq("owner_uid", profile.id)
        .order("created_at", { ascending: false })
        .limit(50),
      supabase
        .from("team_invites")
        .select(
          "id, owner_uid, invitee_email, invitee_name, invitee_uid, role, project_name, status, created_at, responded_at",
        )
        .eq("invitee_uid", profile.id)
        .order("created_at", { ascending: false })
        .limit(50),
      email
        ? supabase
            .from("team_invites")
            .select(
              "id, owner_uid, invitee_email, invitee_name, invitee_uid, role, project_name, status, created_at, responded_at",
            )
            .ilike("invitee_email", email)
            .order("created_at", { ascending: false })
            .limit(50)
        : Promise.resolve({ data: [] as TeamInvite[] }),
    ]);
    owned = (ownedRows ?? []) as TeamInvite[];
    const map = new Map<string, TeamInvite>();
    for (const row of [...(byUid ?? []), ...(byEmail ?? [])] as TeamInvite[]) {
      if (row.owner_uid === profile.id) continue;
      map.set(row.id, row);
    }
    incoming = [...map.values()];
  } catch {
    owned = [];
    incoming = [];
  }

  const pendingOwned = owned.filter((i) => (i.status || "").toLowerCase() === "pending").length;
  const accepted = owned.filter((i) => (i.status || "").toLowerCase() === "accepted").length;

  if (isClient) {
    return (
      <div className="space-y-6 pb-10">
        <ClientPageHeader
          title="My team"
          subtitle="Invite collaborators and manage who can work on your projects."
          icon={Users}
          actions={
            <ClientPrimaryButton href="/app/messages">
              <Mail className="h-4 w-4" />
              Message team
            </ClientPrimaryButton>
          }
        />

        <div className="grid gap-3 sm:grid-cols-3">
          <ClientStatCard label="Invites sent" value={owned.length} icon={Mail} />
          <ClientStatCard label="Pending" value={pendingOwned} icon={Users} />
          <ClientStatCard label="Accepted" value={accepted} icon={Briefcase} />
        </div>

        <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
          <div className="space-y-4">
            <ClientCard title="Team members & invites">
              {owned.length === 0 ? (
                <p className="rounded-xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
                  No team invites yet. Invite freelancers or collaborators by email.
                </p>
              ) : (
                <ul className="divide-y divide-border">
                  {owned.map((inv) => (
                    <li key={inv.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                      <div className="min-w-0">
                        <p className="font-semibold text-navy">
                          {inv.invitee_name || inv.invitee_email}
                        </p>
                        <p className="truncate text-xs text-text-muted">{inv.invitee_email}</p>
                      </div>
                      <div className="flex items-center gap-2">
                        <ClientStatusPill tone="slate">{inv.role || "member"}</ClientStatusPill>
                        <ClientStatusPill
                          tone={
                            (inv.status || "").toLowerCase() === "accepted"
                              ? "green"
                              : (inv.status || "").toLowerCase() === "declined"
                                ? "red"
                                : "amber"
                          }
                        >
                          {inv.status || "pending"}
                        </ClientStatusPill>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </ClientCard>

            {incoming.length > 0 && (
              <ClientCard title="Invites for you">
                <ul className="space-y-2">
                  {incoming.map((inv) => (
                    <li
                      key={inv.id}
                      className="flex items-center justify-between gap-2 rounded-xl border border-border px-3 py-2"
                    >
                      <div>
                        <p className="text-sm font-semibold text-navy">
                          {inv.project_name || inv.invitee_email}
                        </p>
                        <p className="text-xs text-text-muted">
                          Role: {inv.role || "member"}
                          {inv.project_name ? ` · ${inv.invitee_email}` : ""}
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <ClientStatusPill
                          tone={
                            (inv.status || "").toLowerCase() === "accepted"
                              ? "green"
                              : (inv.status || "").toLowerCase() === "declined"
                                ? "red"
                                : "amber"
                          }
                        >
                          {inv.status || "pending"}
                        </ClientStatusPill>
                        <TeamInviteActions
                          inviteId={inv.id}
                          status={inv.status}
                          isClient
                        />
                      </div>
                    </li>
                  ))}
                </ul>
              </ClientCard>
            )}
          </div>

          <ClientCard title="Invite by email">
            <TeamInviteForm ownerUid={profile.id} isClient />
            <p className="mt-3 text-xs text-text-muted">
              Invites use the <code className="rounded bg-background px-1">team_invites</code> table
              and appear here for both of you.
            </p>
          </ClientCard>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Team"
        subtitle="Invite collaborators and keep shared project access organized."
        icon={Briefcase}
        actions={<PrimaryButton href="/app/hub">Open hub</PrimaryButton>}
      />

      <div className="grid gap-3 sm:grid-cols-3">
        <FreelancerStatCard label="Invites sent" value={owned.length} icon={Mail} />
        <FreelancerStatCard label="Pending" value={pendingOwned} icon={Users} />
        <FreelancerStatCard label="Accepted" value={accepted} icon={Briefcase} />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
        <FreelancerCard title="Your team invites">
          {owned.length === 0 ? (
            <p className="rounded-xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
              No team members yet. Invite by email to share project access.
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {owned.map((inv) => (
                <li key={inv.id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                  <div className="min-w-0">
                    <p className="font-semibold text-navy">
                      {inv.invitee_name || inv.invitee_email}
                    </p>
                    <p className="truncate text-xs text-text-muted">{inv.invitee_email}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <StatusPill tone="blue">{inv.role || "member"}</StatusPill>
                    <StatusPill
                      tone={
                        (inv.status || "").toLowerCase() === "accepted"
                          ? "green"
                          : (inv.status || "").toLowerCase() === "declined"
                            ? "red"
                            : "amber"
                      }
                    >
                      {inv.status || "pending"}
                    </StatusPill>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </FreelancerCard>

        <FreelancerCard title="Invite by email">
          <TeamInviteForm ownerUid={profile.id} isClient={false} />
          <Link href="/app/hub" className="mt-3 inline-block text-sm font-semibold text-primary">
            Back to hub →
          </Link>
        </FreelancerCard>
      </div>

      {incoming.length > 0 && (
        <FreelancerCard title="Invites for you">
          <ul className="space-y-2">
            {incoming.map((inv) => (
              <li
                key={inv.id}
                className="flex items-center justify-between gap-2 rounded-xl border border-border px-3 py-2"
              >
                <div>
                  <p className="text-sm font-semibold text-navy">
                    {inv.project_name || inv.invitee_email}
                  </p>
                  <p className="text-xs text-text-muted">
                    Role: {inv.role || "member"}
                    {inv.project_name ? ` · ${inv.invitee_email}` : ""}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <StatusPill
                    tone={
                      (inv.status || "").toLowerCase() === "accepted"
                        ? "green"
                        : (inv.status || "").toLowerCase() === "declined"
                          ? "red"
                          : "amber"
                    }
                  >
                    {inv.status || "pending"}
                  </StatusPill>
                  <TeamInviteActions inviteId={inv.id} status={inv.status} />
                </div>
              </li>
            ))}
          </ul>
        </FreelancerCard>
      )}
    </div>
  );
}
