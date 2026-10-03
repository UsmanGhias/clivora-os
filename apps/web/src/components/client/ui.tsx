import Link from "next/link";
import { cn } from "@/lib/utils";

export function ClientPageHeader({
  title,
  subtitle,
  icon: Icon,
  actions,
}: {
  title: string;
  subtitle?: string;
  icon?: React.ComponentType<{ className?: string }>;
  actions?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <h1 className="flex items-center gap-2 font-display text-2xl font-extrabold text-navy sm:text-3xl">
          {Icon && (
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-client-surface text-client-accent">
              <Icon className="h-5 w-5" />
            </span>
          )}
          {title}
        </h1>
        {subtitle && <p className="mt-1 max-w-2xl text-sm text-text-secondary">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function ClientStatCard({
  label,
  value,
  sub,
  trend,
  trendDown,
  icon: Icon,
  iconTone = "bg-client-surface text-client-accent",
  href,
}: {
  label: string;
  value: string | number;
  sub?: string;
  trend?: string;
  trendDown?: boolean;
  icon?: React.ComponentType<{ className?: string }>;
  iconTone?: string;
  href?: string;
}) {
  const body = (
    <>
      <div className="flex items-start justify-between gap-2">
        {Icon && (
          <span className={cn("flex h-10 w-10 items-center justify-center rounded-xl", iconTone)}>
            <Icon className="h-5 w-5" />
          </span>
        )}
        {trend && (
          <span
            className={cn(
              "rounded-lg px-2 py-0.5 text-[10px] font-bold",
              trendDown ? "bg-error/10 text-error" : "bg-success/10 text-success",
            )}
          >
            {trend}
          </span>
        )}
      </div>
      <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-text-muted">{label}</p>
      <p className="mt-1 font-display text-xl font-extrabold text-navy sm:text-2xl">{value}</p>
      {sub && <p className="mt-1 text-xs text-text-secondary">{sub}</p>}
    </>
  );

  if (href) {
    return (
      <Link
        href={href}
        className="rounded-2xl border border-border bg-surface p-4 shadow-sm transition hover:border-client-accent/40"
      >
        {body}
      </Link>
    );
  }

  return <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm">{body}</div>;
}

export function ClientCard({
  title,
  action,
  children,
  className,
}: {
  title?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("rounded-2xl border border-border bg-surface p-5 shadow-sm", className)}>
      {(title || action) && (
        <div className="mb-4 flex items-center justify-between gap-2">
          {title && <h2 className="font-display text-lg font-bold text-navy">{title}</h2>}
          {action}
        </div>
      )}
      {children}
    </div>
  );
}

export function ClientStatusPill({
  children,
  tone = "slate",
}: {
  children: React.ReactNode;
  tone?: "slate" | "green" | "amber" | "red" | "blue" | "violet" | "gray";
}) {
  const tones = {
    slate: "bg-client-surface text-client-accent",
    green: "bg-emerald-50 text-emerald-700",
    amber: "bg-amber-50 text-amber-800",
    red: "bg-red-50 text-red-700",
    blue: "bg-sky-50 text-sky-800",
    violet: "bg-violet-50 text-violet-800",
    gray: "bg-slate-100 text-slate-600",
  };
  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-1 text-[10px] font-bold uppercase", tones[tone])}>
      {children}
    </span>
  );
}

export function ClientPrimaryButton({
  children,
  href,
  className,
  type = "button",
  onClick,
}: {
  children: React.ReactNode;
  href?: string;
  className?: string;
  type?: "button" | "submit";
  onClick?: () => void;
}) {
  const cls = cn(
    "inline-flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-client-accent px-4 py-2.5 text-sm font-bold text-white hover:bg-client-header",
    className,
  );
  if (href) return <Link href={href} className={cls}>{children}</Link>;
  return (
    <button type={type} onClick={onClick} className={cls}>
      {children}
    </button>
  );
}

export function ClientOutlineButton({
  children,
  href,
  className,
}: {
  children: React.ReactNode;
  href?: string;
  className?: string;
}) {
  const cls = cn(
    "inline-flex min-h-10 items-center justify-center gap-1.5 rounded-xl border-2 border-client-accent bg-white px-4 py-2.5 text-sm font-bold text-client-accent hover:bg-client-surface",
    className,
  );
  if (href) return <Link href={href} className={cls}>{children}</Link>;
  return <button type="button" className={cls}>{children}</button>;
}

export function money(n: number, digits = 2) {
  return `$${n.toLocaleString(undefined, { minimumFractionDigits: digits, maximumFractionDigits: digits })}`;
}
