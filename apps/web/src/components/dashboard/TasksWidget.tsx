import Link from "next/link";

type Task = { id: string; title: string; project: string; due: string; priority: "high" | "medium" | "low" };

const PRIORITY: Record<Task["priority"], string> = {
  high: "bg-red-100 text-red-700",
  medium: "bg-amber-100 text-amber-800",
  low: "bg-emerald-100 text-emerald-800",
};

export function TasksWidget({ tasks, viewAllHref }: { tasks: Task[]; viewAllHref: string }) {
  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <h2 className="font-display text-lg font-bold text-navy">Upcoming tasks</h2>
      {tasks.length === 0 ? (
        <p className="mt-4 text-sm text-text-secondary">No tasks due soon. Add tasks from Projects or Hub.</p>
      ) : (
        <ul className="mt-4 space-y-2">
          {tasks.map((t) => (
            <li
              key={t.id}
              className="flex items-start justify-between gap-2 rounded-xl border border-border/60 px-3 py-2.5"
            >
              <div>
                <p className="text-sm font-semibold text-text-primary">{t.title}</p>
                <p className="text-xs text-text-secondary">{t.project}</p>
              </div>
              <div className="text-right">
                <span className={`rounded-md px-2 py-0.5 text-[10px] font-bold uppercase ${PRIORITY[t.priority]}`}>
                  {t.priority}
                </span>
                <p className="mt-1 text-[10px] text-text-muted">{t.due}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
      <Link href={viewAllHref} className="mt-4 inline-block text-sm font-semibold text-primary hover:underline">
        View all tasks →
      </Link>
    </div>
  );
}
