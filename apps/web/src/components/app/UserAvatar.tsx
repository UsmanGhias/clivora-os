import { cn } from "@/lib/utils";

/** Shared avatar - shows photo when available, otherwise initials. */
export function UserAvatar({
  name,
  email,
  avatarUrl,
  size = "md",
  className,
  ringClassName,
}: {
  name?: string | null;
  email?: string | null;
  avatarUrl?: string | null;
  size?: "sm" | "md" | "lg";
  className?: string;
  ringClassName?: string;
}) {
  const initial = (name || email || "?").charAt(0).toUpperCase();
  const sizeCls =
    size === "lg" ? "h-10 w-10 text-sm" : size === "sm" ? "h-8 w-8 text-[10px]" : "h-9 w-9 text-xs";

  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={avatarUrl}
        alt=""
        className={cn("shrink-0 rounded-full object-cover", sizeCls, className)}
      />
    );
  }

  return (
    <span
      className={cn(
        "relative flex shrink-0 items-center justify-center rounded-full bg-navy font-bold text-white",
        sizeCls,
        className,
        ringClassName,
      )}
    >
      {initial}
    </span>
  );
}
