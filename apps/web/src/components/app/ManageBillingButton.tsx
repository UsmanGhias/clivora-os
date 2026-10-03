import Link from "next/link";

/**
 * Community edition: there is no billing to manage. Kept as a component so
 * settings pages stay unchanged; it links to the edition overview instead.
 */
export function ManageBillingButton() {
  return (
    <Link
      href="/edition"
      className="inline-flex items-center rounded-xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-navy hover:bg-slate-50"
    >
      Community edition: all features included
    </Link>
  );
}
