"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export function DashboardCharts({
  invoiceTotal,
  projectCount,
  clientCount,
  paidCount,
  outstandingCount,
}: {
  invoiceTotal: number;
  projectCount: number;
  clientCount: number;
  paidCount: number;
  outstandingCount: number;
}) {
  const data = [
    { name: "Clients", value: clientCount },
    { name: "Projects", value: projectCount },
    { name: "Paid inv.", value: paidCount },
    { name: "Open inv.", value: outstandingCount },
  ];

  return (
    <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm">
      <div className="mb-3 flex items-end justify-between gap-2">
        <div>
          <h2 className="font-display text-lg font-bold text-navy">Workspace snapshot</h2>
          <p className="text-sm text-text-secondary">
            Invoice book (cloud):{" "}
            <strong className="text-navy">${invoiceTotal.toLocaleString()}</strong>
          </p>
        </div>
      </div>
      <div className="h-56 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
            <XAxis dataKey="name" tick={{ fontSize: 12 }} />
            <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
            <Tooltip />
            <Bar dataKey="value" fill="#0D9488" radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
