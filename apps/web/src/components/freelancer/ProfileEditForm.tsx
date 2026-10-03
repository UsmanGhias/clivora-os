"use client";

import { FormEvent, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Camera, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { OutlineButton, PrimaryButton } from "@/components/freelancer/ui";
import type { Profile } from "@/lib/profile-types";

const AVATAR_BUCKET = "avatars";

async function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error("Could not read file"));
    reader.readAsDataURL(file);
  });
}

async function uploadAvatar(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  file: File,
): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
  const path = `${userId}/${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from(AVATAR_BUCKET).upload(path, file, {
    upsert: true,
    contentType: file.type || "image/jpeg",
  });
  if (error) {
    throw new Error(`Could not upload avatar to storage: ${error.message}`);
  }
  const { data } = supabase.storage.from(AVATAR_BUCKET).getPublicUrl(path);
  if (!data?.publicUrl) throw new Error("Could not create a public avatar URL.");
  const bust = `v=${Date.now()}`;
  return data.publicUrl.includes("?") ? `${data.publicUrl}&${bust}` : `${data.publicUrl}?${bust}`;
}

export function ProfileEditForm({
  profile,
  onSaved,
  onCancel,
}: {
  profile: Profile;
  onSaved?: () => void;
  onCancel?: () => void;
}) {
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [name, setName] = useState(profile.name || "");
  const [avatarUrl, setAvatarUrl] = useState(profile.avatar_url || "");
  const [preview, setPreview] = useState(profile.avatar_url || "");
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function onPickFile(file: File | null) {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      setError("Please choose an image file.");
      return;
    }
    if (file.size > 2_000_000) {
      setError("Image must be under 2MB.");
      return;
    }
    setError(null);
    setPendingFile(file);
    void fileToDataUrl(file).then(setPreview);
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");

      let nextAvatar = avatarUrl;
      if (pendingFile) {
        nextAvatar = await uploadAvatar(supabase, user.id, pendingFile);
      }

      const patch: Record<string, string> = {
        name: name.trim(),
        updated_at: new Date().toISOString(),
      };
      if (nextAvatar) patch.avatar_url = nextAvatar;

      const { error: err } = await supabase.from("profiles").update(patch).eq("id", user.id);
      if (err) throw err;

      setAvatarUrl(nextAvatar);
      setPendingFile(null);
      onSaved?.();
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Could not save profile");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-center">
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="group relative h-20 w-20 overflow-hidden rounded-full border-2 border-dashed border-primary/40 bg-primary/5"
        >
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={preview} alt="" className="h-full w-full object-cover" onError={() => setPreview("")} />
          ) : (
            <span className="flex h-full w-full items-center justify-center text-2xl font-bold text-primary">
              {(name || "?").charAt(0).toUpperCase()}
            </span>
          )}
          <span className="absolute inset-0 flex items-center justify-center bg-navy/50 opacity-0 transition group-hover:opacity-100">
            <Camera className="h-5 w-5 text-white" />
          </span>
        </button>
        <div>
          <p className="text-sm font-semibold text-navy">Profile photo</p>
          <p className="text-xs text-text-secondary">JPG or PNG, under 2MB</p>
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            className="mt-2 text-sm font-semibold text-primary"
          >
            Upload photo
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => onPickFile(e.target.files?.[0] ?? null)}
          />
        </div>
      </div>

      <label className="block text-sm font-semibold text-navy">
        Display name
        <input
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="mt-1 w-full rounded-xl border border-border px-3 py-2.5"
          placeholder="Your name"
        />
      </label>

      <p className="text-xs text-text-muted">
        Email is managed via your login provider and cannot be changed here.
      </p>

      {error && <p className="text-sm text-error">{error}</p>}

      <div className="flex flex-wrap gap-2">
        <PrimaryButton type="submit" disabled={busy}>
          {busy ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" /> Saving…
            </>
          ) : (
            "Save profile"
          )}
        </PrimaryButton>
        {onCancel && (
          <OutlineButton onClick={onCancel} disabled={busy}>
            Cancel
          </OutlineButton>
        )}
      </div>
    </form>
  );
}
