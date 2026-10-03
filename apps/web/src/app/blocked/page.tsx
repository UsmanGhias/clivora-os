import Link from "next/link";
import { Logo } from "@/components/ui/Logo";
import { site } from "@/lib/site";

export const metadata = {
  title: "Account blocked | CLIVORA",
};

export default function BlockedPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-navy px-6 text-white">
      <div className="w-full max-w-md rounded-3xl border border-white/10 bg-white/5 p-8 text-center backdrop-blur">
        <div className="mb-4 flex justify-center">
          <Logo size="sm" variant="onDark" />
        </div>
        <h1 className="text-2xl font-extrabold">Account blocked</h1>
        <p className="mt-3 text-sm text-white/70">
          This CLIVORA account has been blocked by an administrator. Web app, Connect, and billing
          actions are paused.
        </p>
        <a
          href={`mailto:${site.company.email}?subject=CLIVORA%20account%20blocked`}
          className="mt-6 inline-flex rounded-full bg-primary px-5 py-2.5 text-sm font-bold text-white"
        >
          Contact support
        </a>
        <p className="mt-4">
          <Link href="/" className="text-sm text-white/60 hover:text-white">
            Back to home
          </Link>
        </p>
      </div>
    </main>
  );
}
