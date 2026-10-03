"use client";

import { useRouter } from "next/navigation";
import { ProfileEditForm } from "@/components/freelancer/ProfileEditForm";
import type { Profile } from "@/lib/profile-types";

/** Client wrapper so cancel can clear ?edit=1 without a full server round-trip. */
export function AccountProfileEditor({ profile }: { profile: Profile }) {
  const router = useRouter();
  return (
    <ProfileEditForm
      profile={profile}
      onCancel={() => router.push("/app/account")}
      onSaved={() => router.push("/app/account")}
    />
  );
}
