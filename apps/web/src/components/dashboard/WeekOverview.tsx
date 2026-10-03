export function WeekOverview({
  timeTracked,
  earned,
  tasksDone,
  productivity,
}: {
  timeTracked: string;
  earned: string;
  tasksDone: number;
  productivity: number;
}) {
  const cells = [
    { label: "Time tracked", value: timeTracked, tone: "bg-sky-50 text-sky-800" },
    { label: "Earned", value: earned, tone: "bg-primary/10 text-primary-dark" },
    { label: "Tasks done", value: String(tasksDone), tone: "bg-violet-50 text-violet-800" },
    { label: "Productivity", value: `${productivity}%`, tone: "bg-amber-50 text-amber-900" },
  ];

  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <h2 className="font-display text-lg font-bold text-navy">This week overview</h2>
      <div className="mt-4 grid grid-cols-2 gap-3">
        {cells.map((c) => (
          <div key={c.label} className={`rounded-xl px-3 py-3 ${c.tone}`}>
            <p className="text-[10px] font-bold uppercase tracking-wide opacity-80">{c.label}</p>
            <p className="mt-1 font-display text-lg font-extrabold">{c.value}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
