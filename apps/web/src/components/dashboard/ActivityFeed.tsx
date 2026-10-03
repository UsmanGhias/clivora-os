import Link from "next/link";
import { CheckCircle2, DollarSign, MessageSquare, FolderKanban } from "lucide-react";

type Item = { id: string; title: string; detail: string; time: string; kind: string };

const ICONS: Record<string, typeof DollarSign> = {
  invoice: DollarSign,
  project: FolderKanban,
  message: MessageSquare,
  default: CheckCircle2,
};

export function ActivityFeed({
  items,
  viewAllHref,
  accent = "teal",
  defaultCollapsed = false,
}: {
  items: Item[];
  viewAllHref: string;
  accent?: "teal" | "slate";
  /** When true, wraps feed in a details/summary toggle (e.g. analytics). */
  defaultCollapsed?: boolean;
}) {
  const iconTone =
    accent === "slate" ? "bg-client-surface text-client-accent" : "bg-primary/10 text-primary";
  const linkTone = accent === "slate" ? "text-client-accent" : "text-primary";

  const body = (
    <>
      {items.length === 0 ? (
        <p className="mt-4 text-sm text-text-secondary">
          No recent activity yet. Start a project or send a message.
        </p>
      ) : (
        <ul className="mt-4 space-y-3">
          {items.map((item) => {
            const Icon = ICONS[item.kind] ?? ICONS.default;
            return (
              <li key={item.id} className="flex gap-3 rounded-xl border border-border/60 px-3 py-2.5">
                <span
                  className={`mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${iconTone}`}
                >
                  <Icon className="h-4 w-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-text-primary">{item.title}</p>
                  <p className="text-xs text-text-secondary">{item.detail}</p>
                </div>
                <span className="shrink-0 text-[10px] font-medium text-text-muted">{item.time}</span>
              </li>
            );
          })}
        </ul>
      )}
      <Link href={viewAllHref} className={`mt-4 inline-block text-sm font-semibold hover:underline ${linkTone}`}>
        View all activity →
      </Link>
    </>
  );

  if (defaultCollapsed) {
    return (
      <details className="rounded-2xl border border-border bg-surface p-5 shadow-sm" open={false}>
        <summary className="cursor-pointer list-none font-display text-lg font-bold text-navy marker:content-none [&::-webkit-details-marker]:hidden">
          <span className="flex items-center justify-between gap-2">
            Recent activity
            <span className="text-xs font-semibold text-text-muted">Show / hide</span>
          </span>
        </summary>
        {body}
      </details>
    );
  }

  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <h2 className="font-display text-lg font-bold text-navy">Recent activity</h2>
      {body}
    </div>
  );
}
