"use client";

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";

export type DonutSlice = { name: string; value: number; color: string };

export function DonutChart({
  title,
  slices,
  centerLabel,
  centerValue,
}: {
  title: string;
  slices: DonutSlice[];
  centerLabel?: string;
  centerValue?: string | number;
}) {
  const total = slices.reduce((s, x) => s + x.value, 0);
  const isEmpty = slices.length === 0 || total === 0;
  const data = isEmpty ? [{ name: "Empty", value: 1, color: "#E2E8F0" }] : slices;

  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <h2 className="font-display text-lg font-bold text-navy">{title}</h2>
      <div className="mt-2 flex flex-col items-center gap-4 sm:flex-row">
        <div className="relative h-40 w-40 shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                dataKey="value"
                nameKey="name"
                innerRadius={48}
                outerRadius={70}
                paddingAngle={isEmpty ? 0 : 2}
                strokeWidth={0}
              >
                {data.map((entry) => (
                  <Cell key={entry.name} fill={entry.color} />
                ))}
              </Pie>
              {!isEmpty && (
                <Tooltip
                  formatter={(v) => [Number(v ?? 0), "Count"]}
                  contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0" }}
                />
              )}
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            {isEmpty ? (
              <>
                <p className="font-display text-xl font-extrabold text-text-muted">-</p>
                <p className="text-[10px] font-semibold uppercase text-text-muted">No data</p>
              </>
            ) : (
              <>
                {centerValue != null && (
                  <p className="font-display text-xl font-extrabold text-navy">{centerValue}</p>
                )}
                {centerLabel && (
                  <p className="text-[10px] font-semibold uppercase text-text-muted">{centerLabel}</p>
                )}
              </>
            )}
          </div>
        </div>
        <ul className="min-w-0 w-full flex-1 space-y-2">
          {isEmpty ? (
            <li className="text-sm text-text-secondary">No data yet</li>
          ) : (
            slices.map((s) => (
              <li key={s.name} className="flex min-w-0 items-center justify-between gap-2 text-sm">
                <span className="inline-flex min-w-0 items-center gap-2 text-text-secondary">
                  <span
                    className="h-2.5 w-2.5 shrink-0 rounded-full"
                    style={{ background: s.color }}
                  />
                  <span className="min-w-0 truncate">{s.name}</span>
                </span>
                <span className="shrink-0 font-bold text-navy">
                  {s.value}
                  <span className="ml-1 text-xs font-medium text-text-muted">
                    ({Math.round((s.value / total) * 100)}%)
                  </span>
                </span>
              </li>
            ))
          )}
        </ul>
      </div>
    </div>
  );
}
