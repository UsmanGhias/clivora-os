"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { cn } from "@/lib/utils";

export type EarningsPoint = { day: string; amount: number; previous?: number };

export function EarningsLineChart({
  total,
  accent = "teal",
  title = "Earnings overview",
  trendLabel,
  summaryBoxes,
  showPreviousLegend,
  series,
}: {
  total: number;
  accent?: "teal" | "slate";
  title?: string;
  trendLabel?: string;
  summaryBoxes?: Array<{ label: string; value: string; tone: string }>;
  showPreviousLegend?: boolean;
  /** Real time-series from DB. When omitted/empty, chart shows honest empty state (no demo curve). */
  series?: EarningsPoint[];
}) {
  const stroke = accent === "slate" ? "#475569" : "#0D9488";
  const fill = stroke;
  const gradId = accent === "slate" ? "spendGrad" : "earnGrad";
  const points = (series ?? []).filter((p) => Number.isFinite(p.amount));
  const isEmpty = points.length === 0 || points.every((p) => p.amount === 0);

  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="font-display text-lg font-bold text-navy">{title}</h2>
          <p className="mt-1 font-display text-2xl font-extrabold text-navy">
            ${total.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </p>
          {trendLabel && (
            <p
              className={cn(
                "mt-1 text-xs font-semibold",
                accent === "slate" ? "text-client-accent" : "text-success",
              )}
            >
              {trendLabel}
            </p>
          )}
          {showPreviousLegend && !isEmpty && (
            <div className="mt-2 flex items-center gap-4 text-[11px] font-semibold text-text-muted">
              <span className="inline-flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-full" style={{ background: stroke }} />
                {title.includes("Spend") ? "Spending" : "Earnings"}
              </span>
              <span className="inline-flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-full bg-slate-300" />
                Previous month
              </span>
            </div>
          )}
        </div>
      </div>
      <div className="relative h-[220px] w-full min-h-[220px]">
        {isEmpty ? (
          <div className="flex h-full items-center justify-center rounded-xl border border-dashed border-border bg-slate-50/80 px-4 text-center text-sm font-semibold text-text-secondary">
            No invoice time-series yet - total above is from live database records.
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={220} debounce={50}>
            <AreaChart data={points}>
              <defs>
                <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={fill} stopOpacity={0.35} />
                  <stop offset="100%" stopColor={fill} stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
              <XAxis dataKey="day" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis
                tick={{ fontSize: 11 }}
                axisLine={false}
                tickLine={false}
                width={44}
                tickFormatter={(v) => `$${Number(v).toLocaleString()}`}
              />
              <Tooltip
                formatter={(v, name) => [
                  `$${Number(v ?? 0).toLocaleString(undefined, { maximumFractionDigits: 2 })}`,
                  name === "previous" ? "Previous" : title.includes("Spend") ? "Spend" : "Earnings",
                ]}
                contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0" }}
              />
              {showPreviousLegend && (
                <Area
                  type="monotone"
                  dataKey="previous"
                  stroke="#CBD5E1"
                  strokeWidth={2}
                  fill="transparent"
                  dot={false}
                />
              )}
              <Area
                type="monotone"
                dataKey="amount"
                stroke={stroke}
                strokeWidth={2.5}
                fill={`url(#${gradId})`}
                dot={{ r: 3, fill: stroke }}
                activeDot={{ r: 5 }}
                label={{
                  position: "top",
                  fontSize: 10,
                  fill: "#0F172A",
                  formatter: (v: unknown) => {
                    const n = Number(v);
                    return Number.isFinite(n) && n > 0 ? `$${Math.round(n)}` : "";
                  },
                }}
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
      {summaryBoxes && summaryBoxes.length > 0 && (
        <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {summaryBoxes.map((b) => (
            <div key={b.label} className={cn("rounded-xl px-3 py-2.5", b.tone)}>
              <p className="text-[10px] font-bold uppercase tracking-wide opacity-80">{b.label}</p>
              <p className="mt-0.5 text-sm font-extrabold">{b.value}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
