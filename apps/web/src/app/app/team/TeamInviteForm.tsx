"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type ProjectOption = {
  id: string;
  name: string;
  source: "share" | "crm";
};

export function TeamInviteForm({
  ownerUid,
  isClient,
}: {
  ownerUid: string;
  isClient: boolean;
}) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState("member");
  const [projectId, setProjectId] = useState("");
  const [projects, setProjects] = useState<ProjectOption[]>([]);
  const [loadingProjects, setLoadingProjects] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoadingProjects(true);
      try {
        const supabase = createClient();
        const options: ProjectOption[] = [];

        const { data: shares } = await supabase
          .from("project_shares")
          .select("share_id, project_name")
          .eq("freelancer_uid", ownerUid)
          .order("updated_at", { ascending: false })
          .limit(50);
        for (const s of shares ?? []) {
          if (!s.share_id) continue;
          options.push({
            id: s.share_id,
            name: s.project_name || "Untitled project",
            source: "share",
          });
        }

        if (options.length === 0) {
          const { data: crm } = await supabase
            .from("crm_projects")
            .select("id, name")
            .eq("owner_uid", ownerUid)
            .order("updated_at", { ascending: false })
            .limit(50);
          for (const p of crm ?? []) {
            if (!p.id) continue;
            options.push({
              id: String(p.id),
              name: p.name || "Untitled project",
              source: "crm",
            });
          }
        }

        // Clients may own shares via client_uid
        if (options.length === 0) {
          const { data: clientShares } = await supabase
            .from("project_shares")
            .select("share_id, project_name")
            .eq("client_uid", ownerUid)
            .order("updated_at", { ascending: false })
            .limit(50);
          for (const s of clientShares ?? []) {
            if (!s.share_id) continue;
            options.push({
              id: s.share_id,
              name: s.project_name || "Untitled project",
              source: "share",
            });
          }
        }

        if (!cancelled) {
          setProjects(options);
          if (options.length === 1) setProjectId(options[0].id);
        }
      } catch {
        if (!cancelled) setProjects([]);
      } finally {
        if (!cancelled) setLoadingProjects(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [ownerUid]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setOk(false);
    try {
      const supabase = createClient();
      const inviteeEmail = email.trim().toLowerCase();
      if (!inviteeEmail) throw new Error("Email is required");
      const selected = projects.find((p) => p.id === projectId);
      if (!selected) throw new Error("Select a project for this invite");

      const { data: prof } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", inviteeEmail)
        .maybeSingle();

      const insert: Record<string, unknown> = {
        owner_uid: ownerUid,
        invitee_email: inviteeEmail,
        invitee_name: name.trim(),
        invitee_uid: prof?.id ?? null,
        role: role || "member",
        status: "pending",
        project_name: selected.name,
      };
      if (selected.source === "share") {
        insert.project_share_id = selected.id;
      } else {
        insert.project_share_id = selected.id;
      }

      const { error: err } = await supabase.from("team_invites").insert(insert);
      if (err) throw err;
      setEmail("");
      setName("");
      setOk(true);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invite failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <div className="grid gap-2 sm:grid-cols-2">
        <label className="block text-xs font-semibold text-text-secondary">
          Email
          <input
            required
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="teammate@company.com"
            className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-xs font-semibold text-text-secondary">
          Name (optional)
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Alex Rivera"
            className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
          />
        </label>
      </div>
      <label className="block text-xs font-semibold text-text-secondary">
        Project <span className="text-error">*</span>
        <select
          required
          value={projectId}
          onChange={(e) => setProjectId(e.target.value)}
          disabled={loadingProjects || projects.length === 0}
          className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
        >
          <option value="">
            {loadingProjects
              ? "Loading projects…"
              : projects.length === 0
                ? "No projects found"
                : "Select a project"}
          </option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
      </label>
      <label className="block text-xs font-semibold text-text-secondary">
        Role
        <select
          value={role}
          onChange={(e) => setRole(e.target.value)}
          className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
        >
          <option value="member">Member</option>
          <option value="admin">Admin</option>
          <option value="viewer">Viewer</option>
        </select>
      </label>
      {error && <p className="text-sm text-error">{error}</p>}
      {ok && <p className="text-sm text-green-700">Invite sent.</p>}
      <button
        type="submit"
        disabled={busy || !projectId || projects.length === 0}
        className={`rounded-xl px-4 py-2.5 text-sm font-bold text-white disabled:opacity-50 ${
          isClient ? "bg-client-accent hover:bg-client-header" : "bg-primary hover:bg-primary-dark"
        }`}
      >
        {busy ? "Sending…" : "Send invite"}
      </button>
    </form>
  );
}
