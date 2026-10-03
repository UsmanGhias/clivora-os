import Link from "next/link";
import { cn } from "@/lib/utils";

export type PersonRow = {
  id: string;
  name: string;
  subtitle?: string | null;
  amountLabel?: string | null;
  rating?: number | null;
};

export function PeopleListCard({
  title,
  people,
  href,
  isClient,
  amountHeader = "Total paid",
}: {
  title: string;
  people: PersonRow[];
  href: string;
  isClient?: boolean;
  amountHeader?: string;
}) {
  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <div className="flex items-center justify-between gap-2">
        <h2 className="font-display text-lg font-bold text-navy">{title}</h2>
        <Link
          href={href}
          className={cn("text-xs font-semibold", isClient ? "text-client-accent" : "text-primary")}
        >
          View all →
        </Link>
      </div>
      {people.length === 0 ? (
        <p className="mt-4 text-sm text-text-secondary">Nothing to show yet.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {people.slice(0, 5).map((p) => (
            <li key={p.id} className="flex items-center gap-3">
              <span
                className={cn(
                  "flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white",
                  isClient ? "bg-client-accent" : "bg-primary",
                )}
              >
                {(p.name || "?").charAt(0).toUpperCase()}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-navy">{p.name}</p>
                <p className="truncate text-xs text-text-secondary">
                  {p.rating != null && p.rating > 0
                    ? `★ ${p.rating.toFixed(1)}${p.subtitle ? ` · ${p.subtitle}` : ""}`
                    : p.subtitle || amountHeader}
                </p>
              </div>
              {p.amountLabel && (
                <p className="shrink-0 text-sm font-bold text-navy">{p.amountLabel}</p>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
