"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ChevronDown, Globe, LayoutDashboard, LogOut, Menu, X } from "lucide-react";
import { Logo } from "@/components/ui/Logo";
import { marketing } from "@/lib/marketing";
import { cn } from "@/lib/utils";
import { useLivePlatformStats } from "@/lib/useLivePlatformStats";

type SessionUser = {
  email: string | null;
  name: string | null;
};

export function MarketingNav({ variant = "light" }: { variant?: "light" | "overlay" }) {
  const stats = useLivePlatformStats();
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [openMenu, setOpenMenu] = useState<string | null>(null);
  const [user, setUser] = useState<SessionUser | null>(null);
  const light = variant === "light";

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Instant auth hydration with local cache fallback to eliminate layout shift
  useEffect(() => {
    let mounted = true;
    let unsub: (() => void) | undefined;

    // 1. Instant hydration from cached session user
    try {
      const cached = localStorage.getItem("clivora_session_user");
      if (cached) {
        const parsed = JSON.parse(cached);
        if (parsed && typeof parsed === "object") {
          setUser(parsed);
        }
      }
    } catch {
      /* ignore storage errors */
    }

    // 2. Validate session immediately via Supabase client
    void (async () => {
      try {
        const { createClient } = await import("@/lib/supabase/client");
        const supabase = createClient();

        async function syncUser() {
          try {
            const {
              data: { session },
            } = await supabase.auth.getSession();
            if (!mounted) return;
            if (!session?.user) {
              setUser(null);
              try {
                localStorage.removeItem("clivora_session_user");
              } catch {
                /* ignore */
              }
              return;
            }

            const u = session.user;
            const metaName = (u.user_metadata?.full_name || u.user_metadata?.name || null) as string | null;
            const updatedUser: SessionUser = {
              email: u.email ?? null,
              name: metaName,
            };
            setUser(updatedUser);
            try {
              localStorage.setItem("clivora_session_user", JSON.stringify(updatedUser));
            } catch {
              /* ignore */
            }

            // Fetch profile in background for custom display name
            const { data: profile } = await supabase
              .from("profiles")
              .select("name")
              .eq("id", u.id)
              .maybeSingle();

            if (mounted && profile?.name) {
              const fullUser: SessionUser = {
                email: u.email ?? null,
                name: String(profile.name),
              };
              setUser(fullUser);
              try {
                localStorage.setItem("clivora_session_user", JSON.stringify(fullUser));
              } catch {
                /* ignore */
              }
            }
          } catch {
            if (mounted) setUser(null);
          }
        }

        await syncUser();

        try {
          const { data: sub } = supabase.auth.onAuthStateChange(() => {
            void syncUser();
          });
          unsub = () => {
            try {
              sub?.subscription?.unsubscribe?.();
            } catch {
              /* ignore */
            }
          };
        } catch {
          /* ignore */
        }
      } catch {
        if (mounted) setUser(null);
      }
    })();

    return () => {
      mounted = false;
      unsub?.();
    };
  }, []);

  async function signOut() {
    try {
      localStorage.removeItem("clivora_session_user");
    } catch {
      /* ignore */
    }
    const { createClient } = await import("@/lib/supabase/client");
    const supabase = createClient();
    await supabase.auth.signOut();
    setUser(null);
    window.location.href = "/";
  }

  const loggedIn = !!user;
  const displayName = (user?.name || user?.email || "Account").split(" ")[0];

  return (
    <>
      <div className="relative z-50 bg-[#0F172A] px-4 py-2 text-center text-xs font-medium text-slate-300 border-b border-slate-800">
        <span>You are exploring the open-source community demo. Looking for the production platform? </span>
        <a
          href="https://clivora.io"
          target="_blank"
          rel="noopener noreferrer"
          className="font-bold text-teal-400 underline underline-offset-2 hover:text-teal-300 inline-flex items-center gap-1 ml-1"
        >
          <span>Switch to clivora.io</span>
          <span aria-hidden="true">&rarr;</span>
        </a>
      </div>
      <header
        className={cn(
          "sticky top-0 z-50 transition-all duration-300",
          light
            ? scrolled
              ? "border-b border-slate-200/80 bg-white/90 shadow-sm backdrop-blur-xl"
              : "border-b border-transparent bg-[#F8FAFC]/90 backdrop-blur-md"
            : scrolled
              ? "border-b border-white/10 bg-navy/90 backdrop-blur-xl"
              : "bg-transparent",
        )}
      >
        <div className="mx-auto flex h-[68px] max-w-7xl items-center justify-between gap-4 px-5 lg:px-8">
          <Link href="/" className="flex shrink-0 items-center gap-2.5" aria-label="Clivora Home">
            <Logo size="sm" showText={false} variant={light ? "onLight" : "onDark"} />
            <span className="hidden flex-col leading-none sm:flex">
              <span
                className={cn(
                  "font-display text-sm font-extrabold tracking-wide",
                  light ? "text-navy" : "text-white",
                )}
              >
                {marketing.brand.name}
              </span>
              <span className="text-[9px] font-semibold uppercase tracking-[0.18em] text-primary">
                {marketing.brand.productLine}
              </span>
            </span>
          </Link>

          <nav className="hidden items-center gap-1 xl:gap-2 lg:flex">
            {marketing.nav.links.map((link) => {
              const hasChildren = "children" in link && !!link.children?.length;
              const isExternal = "external" in link && link.external;
              const badge = "badge" in link ? (link.badge as string) : null;
              const isJobsLink = link.label === "Jobs";
              const itemClass = cn(
                "inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs xl:text-sm font-semibold transition-colors",
                light
                  ? "text-slate-600 hover:bg-slate-100 hover:text-navy"
                  : "text-white/75 hover:bg-white/10 hover:text-white",
                isExternal && light ? "text-primary hover:text-primary" : null,
              );
              return (
                <div
                  key={link.label}
                  className="relative"
                  onMouseEnter={() => hasChildren && setOpenMenu(link.label)}
                  onMouseLeave={() => setOpenMenu(null)}
                >
                  {isExternal ? (
                    <a
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className={itemClass}
                      onClick={() => setOpenMenu(null)}
                    >
                      <span>{link.label}</span>
                      {badge && (
                        <span className="rounded-full bg-teal-100 px-1.5 py-0.5 text-[9px] font-bold text-teal-800">
                          {badge}
                        </span>
                      )}
                    </a>
                  ) : (
                    <Link
                      href={link.href}
                      className={itemClass}
                      onClick={() => setOpenMenu(null)}
                    >
                      <span>{link.label}</span>
                      {isJobsLink ? (
                        <span className="rounded-full bg-teal-100 px-1.5 py-0.5 text-[9px] font-extrabold text-teal-800 border border-teal-200">
                          {stats.formattedJobs}
                        </span>
                      ) : badge ? (
                        <span className="rounded-full bg-teal-100 px-1.5 py-0.5 text-[9px] font-bold text-teal-800">
                          {badge}
                        </span>
                      ) : null}
                      {hasChildren ? <ChevronDown className="h-3.5 w-3.5 opacity-60" /> : null}
                    </Link>
                  )}
                  {hasChildren && openMenu === link.label ? (
                    <div className="absolute left-0 top-full pt-2">
                      <div className="min-w-[220px] rounded-xl border border-slate-200 bg-white p-2 shadow-xl shadow-slate-900/10">
                        {link.children!.map((child) => {
                          const childExternal = "external" in child && child.external;
                          return childExternal ? (
                            <a
                              key={child.href + child.label}
                              href={child.href}
                              target="_blank"
                              rel="noopener noreferrer"
                              onClick={() => setOpenMenu(null)}
                              className="block rounded-lg px-3 py-2 text-xs xl:text-sm text-slate-600 transition hover:bg-teal-50 hover:text-navy"
                            >
                              {child.label}
                            </a>
                          ) : (
                            <Link
                              key={child.href + child.label}
                              href={child.href}
                              onClick={() => setOpenMenu(null)}
                              className="flex items-center justify-between rounded-lg px-3 py-2 text-xs xl:text-sm text-slate-600 transition hover:bg-teal-50 hover:text-navy"
                            >
                              <span>{child.label}</span>
                              {child.href === "/jobs" && (
                                <span className="rounded-full bg-teal-100 px-1.5 py-0.5 text-[9px] font-bold text-teal-800">
                                  {stats.formattedJobs}
                                </span>
                              )}
                            </Link>
                          );
                        })}
                      </div>
                    </div>
                  ) : null}
                </div>
              );
            })}
          </nav>

          <div className="hidden items-center gap-2 xl:gap-2.5 lg:flex shrink-0">
            <button
              type="button"
              className={cn(
                "inline-flex items-center gap-1 rounded-lg px-2 py-1.5 text-xs xl:text-sm font-medium",
                light ? "text-slate-500 hover:bg-slate-100" : "text-white/70 hover:bg-white/10",
              )}
              aria-label="Language"
            >
              <Globe className="h-3.5 w-3.5" />
              {marketing.nav.locale}
            </button>

            {loggedIn ? (
              <div className="flex items-center gap-1.5 xl:gap-2 shrink-0">
                <span
                  className={cn(
                    "hidden text-xs xl:text-sm font-semibold xl:inline truncate max-w-[110px]",
                    light ? "text-slate-600" : "text-white/80",
                  )}
                  title={displayName}
                >
                  Hi, {displayName}
                </span>
                <Link
                  href="/app"
                  className={cn(
                    "inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs xl:text-sm font-bold shadow-xs transition shrink-0",
                    light
                      ? "bg-navy text-white hover:bg-navy/90 shadow-navy/10"
                      : "bg-white text-navy hover:bg-white/90 shadow-white/10",
                  )}
                >
                  <LayoutDashboard className="h-3.5 w-3.5" />
                  <span>Dashboard</span>
                </Link>
                <button
                  type="button"
                  onClick={() => void signOut()}
                  className={cn(
                    "inline-flex items-center justify-center rounded-lg p-2 text-sm font-medium transition shrink-0",
                    light ? "text-slate-500 hover:bg-slate-100 hover:text-navy" : "text-white/70 hover:bg-white/10 hover:text-white",
                  )}
                  aria-label="Sign out"
                  title="Sign out"
                >
                  <LogOut className="h-4 w-4" />
                </button>
              </div>
            ) : (
              <>
                <Link
                  href={marketing.nav.login.href}
                  className={cn(
                    "text-xs xl:text-sm font-semibold px-2 py-1.5",
                    light ? "text-navy hover:text-primary" : "text-white/80 hover:text-white",
                  )}
                >
                  {marketing.nav.login.label}
                </Link>
                <Link
                  href={marketing.nav.cta.href}
                  className={cn(
                    "rounded-xl px-4 py-2 text-xs xl:text-sm font-bold transition shadow-xs shrink-0",
                    light
                      ? "bg-navy text-white hover:bg-navy/90 shadow-navy/10"
                      : "bg-white text-navy hover:bg-white/90 shadow-white/10",
                  )}
                >
                  {marketing.nav.cta.label}
                </Link>
              </>
            )}
          </div>

          <div className="flex items-center gap-1.5 lg:hidden">
            <button
              type="button"
              className={cn(
                "flex h-9 w-9 items-center justify-center rounded-xl border transition",
                light
                  ? "border-slate-200/90 bg-slate-100/70 text-navy hover:bg-slate-200/70"
                  : "border-white/10 bg-white/5 text-white hover:bg-white/10",
              )}
              onClick={() => setMobileOpen((v) => !v)}
              aria-label="Toggle menu"
            >
              {mobileOpen ? <X size={20} /> : <Menu size={20} />}
            </button>
          </div>
        </div>
      </header>

      {mobileOpen ? (
        <div className="fixed inset-x-0 top-[68px] z-40 max-h-[calc(100svh-68px)] overflow-y-auto border-b border-slate-200 bg-white p-5 shadow-xl lg:hidden">
          <div className="mb-4">
          </div>
          <nav className="flex flex-col gap-1">
            {marketing.nav.links.map((link) => {
              const isExternal = "external" in link && link.external;
              return (
                <div key={link.label} className="border-b border-slate-100 py-2">
                  {isExternal ? (
                    <a
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={() => setMobileOpen(false)}
                      className="block py-2 text-base font-semibold text-primary"
                    >
                      {link.label}
                    </a>
                  ) : (
                    <Link
                      href={link.href}
                      onClick={() => setMobileOpen(false)}
                      className="block py-2 text-base font-semibold text-navy"
                    >
                      {link.label}
                    </Link>
                  )}
                  {"children" in link && link.children
                    ? link.children.map((child) => {
                        const isChildExt = "external" in child && child.external;
                        return isChildExt ? (
                          <a
                            key={child.href + child.label}
                            href={child.href}
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={() => setMobileOpen(false)}
                            className="flex items-center justify-between py-1.5 pl-3 pr-2 text-sm text-slate-500 hover:text-navy"
                          >
                            <span>{child.label}</span>
                          </a>
                        ) : (
                          <Link
                            key={child.href + child.label}
                            href={child.href}
                            onClick={() => setMobileOpen(false)}
                            className="flex items-center justify-between py-1.5 pl-3 pr-2 text-sm text-slate-500 hover:text-navy"
                          >
                            <span>{child.label}</span>
                            {child.href === "/jobs" && (
                              <span className="rounded-full bg-teal-100 px-1.5 py-0.5 text-[9px] font-bold text-teal-800">
                                {stats.formattedJobs}
                              </span>
                            )}
                          </Link>
                        );
                      })
                    : null}
                </div>
              );
            })}
            {loggedIn ? (
              <>
                <Link
                  href="/app"
                  onClick={() => setMobileOpen(false)}
                  className="mt-3 rounded-xl bg-navy px-4 py-3 text-center text-sm font-bold text-white"
                >
                  Open portal
                </Link>
                <button
                  type="button"
                  onClick={() => {
                    setMobileOpen(false);
                    void signOut();
                  }}
                  className="mt-2 py-2 text-base font-semibold text-slate-600"
                >
                  Sign out
                </button>
              </>
            ) : (
              <>
                <Link
                  href={marketing.nav.login.href}
                  onClick={() => setMobileOpen(false)}
                  className="mt-3 py-2 text-base font-semibold text-navy"
                >
                  {marketing.nav.login.label}
                </Link>
                <Link
                  href={marketing.nav.cta.href}
                  onClick={() => setMobileOpen(false)}
                  className="mt-2 rounded-xl bg-navy px-4 py-3 text-center text-sm font-bold text-white"
                >
                  {marketing.nav.cta.label}
                </Link>
              </>
            )}
          </nav>
        </div>
      ) : null}
    </>
  );
}
