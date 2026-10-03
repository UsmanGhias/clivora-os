"use client";

import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import { useEffect, useState, Suspense } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { CheckCircle, AlertCircle, Loader2 } from "lucide-react";

function ClaimContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const token = searchParams.get("token");

  const [status, setStatus] = useState<"loading" | "success" | "error" | "no-token">(
    token ? "loading" : "no-token"
  );
  const [message, setMessage] = useState("");
  const [jobTitle, setJobTitle] = useState("");

  useEffect(() => {
    if (!token) return;

    async function claimJob() {
      const supabase = createBrowserClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
      );

      // Check if user is logged in
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        // Redirect to signup with claim token preserved
        router.push(`/signup?next=/connect/claim?token=${token}&role=client`);
        return;
      }

      // Call the claim RPC
      const { data, error } = await supabase.rpc("connect_job_claim", {
        p_token: token,
      });

      if (error) {
        setStatus("error");
        setMessage("Failed to claim this listing. Please try again or contact support.");
        return;
      }

      const result = data as { ok: boolean; error?: string; job_id?: string; title?: string };
      if (result?.ok) {
        setStatus("success");
        setJobTitle(result.title || "Your job listing");
        setMessage("You can now review applicants and manage this listing from your dashboard.");
      } else {
        setStatus("error");
        setMessage(
          result?.error === "invalid_or_claimed"
            ? "This claim link is invalid or the listing has already been claimed."
            : "An unexpected error occurred. Please contact support."
        );
      }
    }

    claimJob();
  }, [token, router]);

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-2xl shadow-lg border border-gray-200 p-8 text-center">
        {/* Logo */}
        <div className="w-14 h-14 mx-auto mb-6 rounded-xl bg-gradient-to-br from-[#0F172A] to-[#0F766E] flex items-center justify-center">
          <span className="text-white text-2xl font-extrabold">C</span>
        </div>

        {status === "loading" && (
          <>
            <Loader2 className="w-12 h-12 text-teal-700 animate-spin mx-auto mb-4" />
            <h1 className="text-xl font-bold text-gray-900">Claiming your listing...</h1>
            <p className="text-gray-500 mt-2">Please wait while we verify your claim token.</p>
          </>
        )}

        {status === "success" && (
          <>
            <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-gray-900">Listing Claimed!</h1>
            <p className="text-lg text-teal-700 font-semibold mt-2">{jobTitle}</p>
            <p className="text-gray-500 mt-3">{message}</p>
            <div className="mt-6 space-y-3">
              <Link
                href="/app/connect/manage"
                className="block w-full py-3 px-6 bg-teal-700 text-white font-semibold rounded-xl hover:bg-teal-800 transition-colors"
              >
                View Your Listings
              </Link>
              <Link
                href="/app"
                className="block w-full py-3 px-6 border border-gray-300 text-gray-700 font-medium rounded-xl hover:bg-gray-50 transition-colors"
              >
                Go to Dashboard
              </Link>
            </div>
          </>
        )}

        {status === "error" && (
          <>
            <AlertCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-gray-900">Claim Failed</h1>
            <p className="text-gray-500 mt-3">{message}</p>
            <div className="mt-6">
              <Link
                href="/edition"
                className="inline-block py-3 px-6 bg-gray-900 text-white font-semibold rounded-xl hover:bg-gray-800 transition-colors"
              >
                Contact Support
              </Link>
            </div>
          </>
        )}

        {status === "no-token" && (
          <>
            <AlertCircle className="w-16 h-16 text-amber-500 mx-auto mb-4" />
            <h1 className="text-2xl font-bold text-gray-900">No Claim Token</h1>
            <p className="text-gray-500 mt-3">
              This page requires a valid claim token. Check your email for the claim link.
            </p>
            <div className="mt-6">
              <Link
                href="/"
                className="inline-block py-3 px-6 bg-teal-700 text-white font-semibold rounded-xl hover:bg-teal-800 transition-colors"
              >
                Go to Homepage
              </Link>
            </div>
          </>
        )}

        <p className="text-xs text-gray-400 mt-8">
          CLIVORA - The World&apos;s #1 Open-Source, $0-Fee Freelancer Business OS
        </p>
      </div>
    </div>
  );
}

export default function ClaimPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-teal-700 animate-spin" />
      </div>
    }>
      <ClaimContent />
    </Suspense>
  );
}
