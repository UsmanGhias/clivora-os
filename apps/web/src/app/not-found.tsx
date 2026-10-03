import Link from "next/link";
import { ArrowLeft, FileQuestion } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] px-4 py-16 text-slate-900 antialiased">
      <div className="w-full max-w-md rounded-3xl border border-slate-200/90 bg-white p-6 sm:p-8 shadow-xl text-center">
        <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-teal-50 text-teal-700 border border-teal-100">
          <FileQuestion className="h-7 w-7" />
        </div>

        <p className="text-xs font-bold uppercase tracking-widest text-teal-700">404 Error</p>

        <h1 className="mt-2 text-2xl font-extrabold tracking-tight text-slate-900">
          Page Not Found
        </h1>

        <p className="mt-2 text-sm text-slate-600 leading-relaxed">
          The requested page does not exist or may have been moved. Let us get you back on track.
        </p>

        <div className="mt-6 flex flex-col sm:flex-row items-center justify-center gap-2.5">
          <Link
            href="/"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-slate-800 transition-colors"
          >
            <ArrowLeft className="h-4 w-4" />
            <span>Return to Homepage</span>
          </Link>

          <Link
            href="/jobs"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <span>Browse Jobs</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
