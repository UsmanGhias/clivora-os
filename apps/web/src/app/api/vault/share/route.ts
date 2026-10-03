import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { isFeatureEnabled } from "@/lib/feature-flags";
import { getPublicSiteUrl } from "@/lib/site-url";
import { randomBytes } from "crypto";

// VAULT hardening (VAULT-001..004):
// - resolve an owner-scoped record server-side before issuing a link
// - clamp expiry to a bounded integer
// - build the public URL only from a trusted server-side base URL
// - return stable public error codes; keep raw details in server logs

const MIN_EXPIRY_HOURS = 1;
const MAX_EXPIRY_HOURS = 720; // 30 days
const DEFAULT_EXPIRY_HOURS = 72;

function trustedBaseUrl(): string {
  return getPublicSiteUrl();
}

function randomToken(length = 40): string {
  return randomBytes(Math.ceil(length * 0.75))
    .toString("base64url")
    .slice(0, length);
}

function clampExpiryHours(raw: unknown): number {
  const n = Math.floor(Number(raw));
  if (!Number.isFinite(n)) return DEFAULT_EXPIRY_HOURS;
  return Math.min(MAX_EXPIRY_HOURS, Math.max(MIN_EXPIRY_HOURS, n));
}

function fail(code: string, status: number, detail?: unknown) {
  if (detail) console.error(`[vault/share] ${code}`, detail);
  return NextResponse.json({ error: code }, { status });
}

export async function POST(req: NextRequest) {
  try {
    const vaultOn =
      (await isFeatureEnabled("vault_cloud")) || (await isFeatureEnabled("phase5_vault_cloud"));
    if (!vaultOn) return fail("vault_disabled", 503);

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const body = (await req.json().catch(() => null)) as {
      file_id?: string;
      file_path?: string;
      expires_in_hours?: number;
    } | null;
    if (!body) return fail("invalid_body", 400);

    // Resolve a canonical, owner-scoped storage path. Prefer file_id -> vault_attachments.
    let storagePath: string | null = null;
    let fileName = "file";

    if (body.file_id) {
      const { data: att, error: attErr } = await supabase
        .from("vault_attachments")
        .select("id, owner_uid, storage_path, file_name")
        .eq("id", body.file_id)
        .eq("owner_uid", user.id)
        .maybeSingle();
      if (attErr) return fail("lookup_failed", 400, attErr.message);
      if (!att?.storage_path) return fail("file_not_found", 404);
      storagePath = att.storage_path as string;
      fileName = (att.file_name as string | null) || storagePath.split("/").pop() || "file";
    } else if (body.file_path) {
      // Fallback: only allow paths under the caller's own uid prefix.
      const path = body.file_path.replace(/^\/+/, "");
      if (!path.startsWith(`${user.id}/`)) return fail("forbidden_path", 403);
      storagePath = path;
      fileName = path.split("/").pop() || "file";
    } else {
      return fail("file_id_required", 400);
    }

    const expiresAt = new Date(
      Date.now() + clampExpiryHours(body.expires_in_hours ?? DEFAULT_EXPIRY_HOURS) * 3600 * 1000,
    ).toISOString();
    const token = randomToken(40);

    const { data, error } = await supabase
      .from("vault_share_links")
      .insert({
        owner_uid: user.id,
        storage_path: storagePath,
        file_path: storagePath,
        file_id: body.file_id ?? null,
        file_name: fileName,
        token,
        expires_at: expiresAt,
      })
      .select("id, token, expires_at")
      .single();

    if (error) {
      const missing =
        /schema cache|does not exist|Could not find the table/i.test(error.message || "");
      return fail(missing ? "vault_not_provisioned" : "share_failed", missing ? 503 : 400, error.message);
    }

    const shareUrl = `${trustedBaseUrl()}/vault/s/${data.token}`;
    return NextResponse.json({
      id: data.id,
      token: data.token,
      expires_at: data.expires_at,
      url: shareUrl,
    });
  } catch (err) {
    return fail("internal_error", 500, err);
  }
}
