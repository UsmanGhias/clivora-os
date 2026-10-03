"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function ClientTimesheetActions({
  entryId,
  status,
}: {
  entryId: string;
  status: string | null;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const current = (status || "pending").toLowerCase();
  if (current !== "pending") return null;

  async function update(next: "approved" | "rejected") {
    setBusy(true);
    try {
      const supabase = createClient();
      // Support both legacy `status` and schema `approval_status`
      const { error } = await supabase
        .from("crm_time_entries")
        .update({ status: next, approval_status: next })
        .eq("id", entryId);
      if (error) {
        await supabase.from("crm_time_entries").update({ approval_status: next }).eq("id", entryId);
      }
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        disabled={busy}
        onClick={() => void update("approved")}
        className="rounded-lg bg-emerald-600 px-2 py-0.5 text-[10px] font-bold text-white disabled:opacity-50"
      >
        Approve
      </button>
      <button
        type="button"
        disabled={busy}
        onClick={() => void update("rejected")}
        className="rounded-lg bg-red-600 px-2 py-0.5 text-[10px] font-bold text-white disabled:opacity-50"
      >
        Reject
      </button>
    </div>
  );
}
