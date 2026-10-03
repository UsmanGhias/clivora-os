"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

type BarPoint = { month: string; amount: number };

export function MonthlyBarChart({
  total,
  data: series,
  unit = "money",
}: {
  total?: number;
  /** Real monthly buckets. When provided, used instead of scaled demo. */
  data?: BarPoint[];
  unit?: "money" | "hours";
}) {
  const points =
    series && series.length > 0
      ? series
      : Array.from({ length: 6 }, (_, i) => {
          const d = new Date();
          d.setMonth(d.getMonth() - (5 - i));
          return { month: d.toLocaleString("en-US", { month: "short" }), amount: 0 };
        });

  const isEmpty = points.every((p) => !p.amount) && !(total && total > 0 && !series);
  const formatValue = (v: number) =>
    unit === "hours"
      ? `${Math.round(v * 10) / 10}h`
      : `$${Math.round(v).toLocaleString()}`;

  return (
    <div className="relative h-56 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={points} margin={{ top: 18, right: 4, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
          <XAxis dataKey="month" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
          <YAxis tick={{ fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
          <Tooltip
            formatter={(v) => [formatValue(Number(v ?? 0)), unit === "hours" ? "Hours" : "Amount"]}
            contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0" }}
          />
          <Bar dataKey="amount" fill={isEmpty ? "#E2E8F0" : "#0D9488"} radius={[8, 8, 0, 0]}>
            {!isEmpty && (
              <LabelList
                dataKey="amount"
                position="top"
                formatter={(v) => (Number(v) > 0 ? formatValue(Number(v)) : "")}
                style={{ fontSize: 10, fontWeight: 700, fill: "#0F172A" }}
              />
            )}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
      {isEmpty && (
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <p className="rounded-lg border border-dashed border-border bg-surface/90 px-4 py-2 text-sm font-semibold text-text-secondary">
            No data yet
          </p>
        </div>
      )}
    </div>
  );
}
