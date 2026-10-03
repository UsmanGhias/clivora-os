import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { site } from "@/lib/site";
import { earlyAccessPlanForSignup } from "@/lib/early-access";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/app";
  const accountTypeParam = searchParams.get("account_type");
  // Always land on production host (never localhost from email templates).
  const base = site.url.replace(/\/$/, "");

  if (code) {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error && data.user) {
      const meta = data.user.user_metadata ?? {};
      const accountType =
        accountTypeParam ||
        (meta.account_type as string | undefined) ||
        (meta.accountType as string | undefined) ||
        "freelancer";
      const { data: existingProfile } = await supabase
        .from("profiles")
        .select("id, subscription_plan")
        .eq("id", data.user.id)
        .maybeSingle();

      const patch: Record<string, unknown> = {
        id: data.user.id,
        email: data.user.email ?? "",
        name:
          (meta.full_name as string | undefined) ||
          (meta.name as string | undefined) ||
          data.user.email?.split("@")[0] ||
          "",
        account_type: accountType === "client" ? "client" : "freelancer",
        updated_at: new Date().toISOString(),
      };

      // Never overwrite an existing paid (or free) plan on login - only set plan for brand-new profiles.
      if (!existingProfile) {
        patch.subscription_plan = earlyAccessPlanForSignup();
      }

      await supabase.from("profiles").upsert(patch);
      return NextResponse.redirect(`${base}${next.startsWith("/") ? next : `/${next}`}`);
    }
  }

  return NextResponse.redirect(`${base}/login?error=auth_callback`);
}
