import Link from "next/link";
import { MarketingNav } from "@/components/marketing/MarketingNav";
import { MarketingFooter } from "@/components/marketing/MarketingFooter";
import { site } from "@/lib/site";

const FEATURES = [
  { title: "Clients and CRM", body: "Contacts, notes, files and every project for a client in one record." },
  { title: "Projects and milestones", body: "Deliverables, acceptance dates and a client-visible milestone history." },
  { title: "Quotes and invoices", body: "Quotes that convert to invoices, recurring invoices, credits and public invoice links." },
  { title: "Timesheets", body: "Time tracked against projects and turned into billable invoice lines." },
  { title: "Private hiring", body: "A job board and Connect, where contact details are shared only after both sides accept." },
  { title: "Offline-first Android app", body: "Works without a connection and syncs through a durable outbox when it reconnects." },
];

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#F8FAFC] text-text-primary">
      <MarketingNav variant="light" />
      <main className="mx-auto max-w-6xl px-4 py-16 sm:py-24">
        <section className="max-w-3xl">
          <p className="text-sm font-semibold uppercase tracking-wide text-primary-dark">Open source · AGPL-3.0</p>
          <h1 className="mt-3 font-display text-4xl font-extrabold leading-tight text-navy sm:text-5xl">
            The open-source Freelancer OS
          </h1>
          <p className="mt-5 text-lg text-text-secondary">{site.description}</p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/signup" className="rounded-xl bg-primary px-5 py-3 font-semibold text-white shadow-sm hover:bg-primary-dark">
              Create an account
            </Link>
            <Link href="/login" className="rounded-xl border border-slate-300 bg-white px-5 py-3 font-semibold text-navy hover:bg-slate-50">
              Log in
            </Link>
            <a href={site.repoUrl} className="rounded-xl border border-slate-300 bg-white px-5 py-3 font-semibold text-navy hover:bg-slate-50">
              View on GitHub
            </a>
          </div>
        </section>
        <section className="mt-16 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div key={f.title} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 className="font-display text-lg font-bold text-navy">{f.title}</h2>
              <p className="mt-2 text-sm text-text-secondary">{f.body}</p>
            </div>
          ))}
        </section>
      </main>
      <MarketingFooter />
    </div>
  );
}
