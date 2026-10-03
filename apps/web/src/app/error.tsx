"use client";

import { useEffect } from "react";
import Link from "next/link";
import { AlertTriangle, Home, RefreshCw, LifeBuoy } from "lucide-react";

export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Safely log error for diagnostics without crashing
    console.error("[Clivora Error Boundary Caught Exception]:", error);
  }, [error]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] px-4 py-16 text-slate-900 antialiased">
      <div className="w-full max-w-md rounded-3xl border border-slate-200/90 bg-white p-6 sm:p-8 shadow-xl text-center">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-teal-50 text-teal-700 border border-teal-100">
          <AlertTriangle className="h-7 w-7" />
        </div>

        <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-slate-900">
          Something unexpected happened
        </h1>

        <p className="mt-2 text-sm text-slate-600 leading-relaxed">
          We encountered a brief hiccup while loading this section. Your account data and session remain completely safe.
        </p>

        {error?.digest && (
          <p className="mt-2 text-[11px] font-mono text-slate-400">
            Error ID: {error.digest}
          </p>
        )}

        <div className="mt-6 flex flex-col sm:flex-row items-center justify-center gap-2.5">
          <button
            type="button"
            onClick={() => reset()}
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 py-2.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-slate-800 transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            <span>Try again</span>
          </button>

          <Link
            href="/"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-5 py-2.5 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <Home className="h-4 w-4" />
            <span>Homepage</span>
          </Link>
        </div>

        <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-center gap-1 text-xs text-slate-500">
          <LifeBuoy className="h-3.5 w-3.5" />
          <span>Need help?</span>
          <Link href="/edition" className="font-semibold text-teal-700 hover:underline">
            Contact Clivora Support
          </Link>
        </div>
      </div>
    </div>
  );
}
