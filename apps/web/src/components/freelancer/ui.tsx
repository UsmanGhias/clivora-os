import Link from "next/link";
import { cn } from "@/lib/utils";

export function FreelancerPageHeader({
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
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
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

export function FreelancerStatCard({
  label,
  value,
  sub,
  trend,
  icon: Icon,
  iconTone = "bg-primary/10 text-primary",
  href,
}: {
  label: string;
  value: string | number;
  sub?: string;
  trend?: string;
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
          <span className="rounded-lg bg-success/10 px-2 py-0.5 text-[10px] font-bold text-success">
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
        className="rounded-2xl border border-border bg-surface p-4 shadow-sm transition hover:border-primary/40"
      >
        {body}
      </Link>
    );
  }

  return (
    <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm">{body}</div>
  );
}

export function FreelancerCard({
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

export function StatusPill({
  children,
  tone = "teal",
}: {
  children: React.ReactNode;
  tone?: "teal" | "green" | "amber" | "red" | "blue" | "gray" | "violet";
}) {
  const tones = {
    teal: "bg-primary/10 text-primary-dark",
    green: "bg-success/10 text-success",
    amber: "bg-amber-100 text-amber-800",
    red: "bg-red-100 text-red-700",
    blue: "bg-sky-100 text-sky-800",
    gray: "bg-slate-100 text-slate-600",
    violet: "bg-violet-100 text-violet-800",
  };
  return (
    <span className={cn("inline-flex items-center rounded-full px-2.5 py-1 text-[10px] font-bold", tones[tone])}>
      {children}
    </span>
  );
}

export function PrimaryButton({
  href,
  children,
  onClick,
  type = "button",
  disabled,
  className: extra,
}: {
  href?: string;
  children: React.ReactNode;
  onClick?: () => void;
  type?: "button" | "submit";
  disabled?: boolean;
  className?: string;
}) {
  const className = cn(
    "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white hover:bg-primary-dark disabled:opacity-60",
    extra,
  );
  if (href) {
    return (
      <Link href={href} className={className}>
        {children}
      </Link>
    );
  }
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={className}>
      {children}
    </button>
  );
}

export function OutlineButton({
  href,
  children,
  onClick,
  type = "button",
  disabled,
  className: extra,
}: {
  href?: string;
  children: React.ReactNode;
  onClick?: () => void;
  type?: "button" | "submit";
  disabled?: boolean;
  className?: string;
}) {
  const className = cn(
    "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-semibold text-navy hover:border-primary/40 disabled:opacity-60",
    extra,
  );
  if (href) {
    return (
      <Link href={href} className={className}>
        {children}
      </Link>
    );
  }
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={className}>
      {children}
    </button>
  );
}

export function money(n: number, digits = 2) {
  return `$${Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  })}`;
}
