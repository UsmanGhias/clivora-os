import type { Metadata } from "next";
import { AuthAnimatedShell } from "@/components/auth/animated/AuthAnimatedShell";

export const metadata: Metadata = {
  title: "Account",
};

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <AuthAnimatedShell>{children}</AuthAnimatedShell>;
}
