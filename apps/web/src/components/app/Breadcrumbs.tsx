import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

export type Crumb = { label: string; href?: string };

export function Breadcrumbs({
  items,
  className,
  light = false,
}: {
  items: Crumb[];
  className?: string;
  light?: boolean;
}) {
  if (items.length === 0) return null;
  return (
    <nav aria-label="Breadcrumb" className={cn("flex flex-wrap items-center gap-1 text-xs", className)}>
      {items.map((item, i) => {
        const last = i === items.length - 1;
        return (
          <span key={`${item.label}-${i}`} className="flex items-center gap-1">
            {i > 0 && (
              <ChevronRight
                className={cn("h-3 w-3", light ? "text-white/40" : "text-text-muted")}
              />
            )}
            {item.href && !last ? (
              <Link
                href={item.href}
                className={cn(
                  "font-medium hover:underline",
                  light ? "text-white/70 hover:text-white" : "text-text-secondary hover:text-navy",
                )}
              >
                {item.label}
              </Link>
            ) : (
              <span
                className={cn(
                  "font-semibold",
                  light ? "text-white" : "text-navy",
                  last && "truncate max-w-[160px] sm:max-w-none",
                )}
              >
                {item.label}
              </span>
            )}
          </span>
        );
      })}
    </nav>
  );
}
