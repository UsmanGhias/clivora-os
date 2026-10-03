"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  LayoutDashboard,
  FileText,
  FolderKanban,
  MessageSquare,
  Users,
  Settings,
  LogOut,
  Bell,
  Search,
  Sparkles,
  Network,
  Receipt,
  Clock,
  Star,
  UserCircle,
  Bookmark,
  Briefcase,
  Plus,
  Diamond,
  BarChart3,
  Wallet,
  ChevronDown,
  CreditCard,
  ArrowLeftRight,
  Banknote,
  ScrollText,
  ListTodo,
  Menu,
  X,
  Handshake,
  Compass,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { isFeatureEnabledClient } from "@/lib/feature-flags-client";
import { cn } from "@/lib/utils";
import type { Profile } from "@/lib/profile-types";
import { isPro, isProPlus, planLabel } from "@/lib/plan";
import { Logo } from "@/components/ui/Logo";
import type { PortalNavCounts } from "@/lib/portal-nav";
import { CommandPalette, type CommandItem } from "@/components/app/CommandPalette";
import { UserAvatar } from "@/components/app/UserAvatar";

type NavItem = {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  badge?: number;
  cta?: boolean;
  /** Any of these feature-flag keys must be enabled for the item to show. */
  flags?: string[];
};

type NavSection = {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  items: NavItem[];
};

const SIDEBAR_KEY = "clivora-app-sidebar-collapsed";
const SECTIONS_KEY = "clivora-app-nav-sections";

function NavLink({
  item,
  active,
  isClient,
  nested,
  collapsed,
  onNavigate,
}: {
  item: NavItem;
  active: boolean;
  isClient: boolean;
  nested?: boolean;
  collapsed?: boolean;
  onNavigate?: () => void;
}) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      title={item.label}
      onClick={onNavigate}
      className={cn(
        "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition",
        nested && !collapsed && "py-2 pl-10",
        collapsed && "justify-center px-2",
        item.cta
          ? isClient
            ? "mt-2 bg-client-accent text-white hover:bg-client-header"
            : "mt-2 bg-primary text-white hover:bg-primary-dark"
          : active
            ? isClient
              ? "border-l-4 border-client-accent bg-white/10 text-white"
              : "border-l-4 border-primary bg-primary/20 text-white"
            : "text-white/70 hover:bg-white/5 hover:text-white",
        collapsed && active && "border-l-0 ring-1 ring-white/30",
      )}
    >
      <Icon className="h-4 w-4 shrink-0" />
      {!collapsed && (
        <>
          <span className="flex-1 truncate">{item.label}</span>
          {item.badge != null && item.badge > 0 && (
            <span
              className={cn(
                "rounded-full px-2 py-0.5 text-[10px] font-bold",
                isClient ? "bg-client-accent text-white" : "bg-primary text-white",
              )}
            >
              {item.badge}
            </span>
          )}
        </>
      )}
    </Link>
  );
}

function sectionContainsActive(section: NavSection, pathname: string): boolean {
  return section.items.some((item) => {
    if (item.href === "/app") return pathname === "/app";
    if (item.href === "/app/payments") {
      return pathname === "/app/payments" || pathname.startsWith("/app/payments/");
    }
    return pathname === item.href || pathname.startsWith(`${item.href}/`);
  });
}

export function AppShell({
  profile,
  isClient,
  counts,
  children,
}: {
  profile: Profile;
  isClient: boolean;
  counts?: PortalNavCounts;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const plus = isProPlus(profile);
  const pro = isPro(profile);
  const plan = planLabel(profile);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);
  const [openSections, setOpenSections] = useState<Record<string, boolean>>({});
  const [aiModalOpen, setAiModalOpen] = useState(false);
  const profileMenuRef = useRef<HTMLDivElement>(null);
  const [enabledFlags, setEnabledFlags] = useState<Record<string, boolean>>({});

  // Shared icon language (web ↔ mobile): Compass≈travel_explore Connect,
  // MessageSquare≈chat, Receipt≈receipt_long, FolderKanban≈projects, Users≈clients.
  const freelancerSections: NavSection[] = useMemo(
    () => [
      {
        id: "overview",
        label: "Overview",
        icon: LayoutDashboard,
        items: [{ href: "/app", label: "Dashboard", icon: LayoutDashboard }],
      },
      {
        id: "connect",
        label: "Connect",
        icon: Compass,
        items: [
          { href: "/app/connect", label: "Find jobs (Connect)", icon: Compass },
          { href: "/app/connect/manage", label: "Post a need", icon: Plus },
          { href: "/app/proposals", label: "Proposals", icon: FileText, badge: counts?.proposals },
        ],
      },
      {
        id: "work",
        label: "Work",
        icon: FolderKanban,
        items: [
          { href: "/app/projects", label: "Projects", icon: FolderKanban, badge: counts?.projects },
          { href: "/app/contracts", label: "Contracts", icon: ScrollText },
          { href: "/app/tasks", label: "Tasks", icon: ListTodo },
          {
            href: "/app/workspace-tasks",
            label: "Workspace tasks",
            icon: ListTodo,
            flags: ["workspace_tasks", "phase2_workspace_tasks"],
          },
          {
            href: "/app/calendar",
            label: "Calendar",
            icon: Clock,
            flags: ["calendar_events", "phase3_calendar_events"],
          },
          { href: "/app/timesheets", label: "Time tracking", icon: Clock },
        ],
      },
      {
        id: "money",
        label: "Money",
        icon: Wallet,
        items: [
          { href: "/app/invoices", label: "Invoices", icon: Receipt },
          { href: "/app/earnings", label: "Earnings", icon: Wallet },
        ],
      },
      {
        id: "crm",
        label: "Clients & CRM",
        icon: Users,
        items: [
          { href: "/app/clients", label: "Clients", icon: Users },
          {
            href: "/app/conflicts",
            label: "CRM conflicts",
            icon: Handshake,
            flags: ["crm_conflict_ui", "phase4_crm_conflicts"],
          },
        ],
      },
      {
        id: "growth",
        label: "Growth & tools",
        icon: Sparkles,
        items: [
          { href: "/app/reviews", label: "Reviews", icon: Star },
          { href: "/app/bookmarks", label: "Bookmarks", icon: Bookmark },
          { href: "/app/team", label: "Team", icon: Briefcase },
          { href: "/app/analytics", label: "Analytics", icon: BarChart3 },
        ],
      },
      {
        id: "account",
        label: "Account",
        icon: UserCircle,
        items: [
          { href: "/app/messages", label: "Messages", icon: MessageSquare, badge: counts?.messages },
          { href: "/app/notifications", label: "Notifications", icon: Bell, badge: counts?.notifications },
          { href: "/app/account", label: "My profile", icon: UserCircle },
          { href: "/app/settings", label: "Settings", icon: Settings },
        ],
      },
    ],
    [counts?.proposals, counts?.projects, counts?.messages, counts?.notifications],
  );

  const clientSections: NavSection[] = useMemo(
    () => [
      {
        id: "overview",
        label: "Overview",
        icon: LayoutDashboard,
        items: [{ href: "/app", label: "Dashboard", icon: LayoutDashboard }],
      },
      {
        id: "connect",
        label: "Connect",
        icon: Compass,
        items: [
          { href: "/app/connect", label: "Marketplace / Connect", icon: Compass },
          { href: "/app/connect/manage", label: "Post a job", icon: Plus },
          { href: "/app/proposals", label: "Proposals", icon: FileText, badge: counts?.proposals },
        ],
      },
      {
        id: "work",
        label: "Work",
        icon: FolderKanban,
        items: [
          { href: "/app/projects", label: "Projects", icon: FolderKanban, badge: counts?.projects },
          { href: "/app/contracts", label: "Contracts", icon: ScrollText },
          { href: "/app/tasks", label: "Tasks", icon: ListTodo },
          {
            href: "/app/workspace-tasks",
            label: "Workspace tasks",
            icon: ListTodo,
            flags: ["workspace_tasks", "phase2_workspace_tasks"],
          },
          {
            href: "/app/calendar",
            label: "Calendar",
            icon: Clock,
            flags: ["calendar_events", "phase3_calendar_events"],
          },
          { href: "/app/messages", label: "Messages", icon: MessageSquare, badge: counts?.messages },
        ],
      },
      {
        id: "payments",
        label: "Payments",
        icon: Receipt,
        items: [
          { href: "/app/payments", label: "Overview", icon: Wallet },
          { href: "/app/invoices", label: "Invoices", icon: Receipt },
          { href: "/app/payments/transactions", label: "Transactions", icon: ArrowLeftRight },
          { href: "/app/payments/payment-methods", label: "Payment methods", icon: CreditCard },
          { href: "/app/payments/payouts", label: "Payouts", icon: Banknote },
        ],
      },
      {
        id: "growth",
        label: "Growth & tools",
        icon: Sparkles,
        items: [
          {
            href: "/app/conflicts",
            label: "CRM conflicts",
            icon: Handshake,
            flags: ["crm_conflict_ui", "phase4_crm_conflicts"],
          },
        ],
      },
      {
        id: "workspace",
        label: "Workspace",
        icon: Briefcase,
        items: [
          { href: "/app/team", label: "My team", icon: Users },
          { href: "/app/bookmarks", label: "Bookmarks", icon: Bookmark },
          { href: "/app/reviews", label: "Reviews", icon: Star },
          { href: "/app/timesheets", label: "Time tracking", icon: Clock },
          { href: "/app/analytics", label: "Reports", icon: BarChart3 },
        ],
      },
      {
        id: "account",
        label: "Account",
        icon: UserCircle,
        items: [
          { href: "/app/notifications", label: "Notifications", icon: Bell, badge: counts?.notifications },
          { href: "/app/account", label: "My profile", icon: UserCircle },
          { href: "/app/settings", label: "Settings", icon: Settings },
        ],
      },
    ],
    [counts?.proposals, counts?.projects, counts?.messages, counts?.notifications],
  );

  const sections = isClient ? clientSections : freelancerSections;

  useEffect(() => {
    try {
      if (localStorage.getItem(SIDEBAR_KEY) === "1") setCollapsed(true);
      const raw = localStorage.getItem(SECTIONS_KEY);
      if (raw) setOpenSections(JSON.parse(raw) as Record<string, boolean>);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(SIDEBAR_KEY, collapsed ? "1" : "0");
    } catch {
      /* ignore */
    }
  }, [collapsed]);

  useEffect(() => {
    const keys = Array.from(
      new Set(sections.flatMap((s) => s.items.flatMap((item) => item.flags ?? [])).filter(Boolean)),
    );
    if (keys.length === 0) return;
    let cancelled = false;
    void (async () => {
      const entries = await Promise.all(
        keys.map(async (key) => [key, await isFeatureEnabledClient(key)] as const),
      );
      if (cancelled) return;
      setEnabledFlags(Object.fromEntries(entries));
    })();
    return () => {
      cancelled = true;
    };
  }, [sections]);

  useEffect(() => {
    setOpenSections((prev) => {
      const next = { ...prev };
      let changed = false;
      for (const section of sections) {
        if (sectionContainsActive(section, pathname) && next[section.id] !== true) {
          next[section.id] = true;
          changed = true;
        }
      }
      if (changed) {
        try {
          localStorage.setItem(SECTIONS_KEY, JSON.stringify(next));
        } catch {
          /* ignore */
        }
      }
      return changed ? next : prev;
    });
  }, [pathname, sections]);

  useEffect(() => {
    const supabase = createClient();
    if (!profile?.id) return;
    
    const channel = supabase
      .channel('app-shell-realtime')
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'profiles', filter: `id=eq.${profile.id}` },
        () => {
          router.refresh();
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_uid=eq.${profile.id}` },
        () => {
          router.refresh();
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'client_messages', filter: `to_uid=eq.${profile.id}` },
        () => {
          router.refresh();
        }
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [profile?.id, router]);

  function isFlagAllowed(item: NavItem): boolean {
    if (!item.flags?.length) return true;
    return item.flags.some((key) => enabledFlags[key] === true);
  }

  function toggleSection(id: string) {
    setOpenSections((prev) => {
      const next = { ...prev, [id]: !prev[id] };
      try {
        localStorage.setItem(SECTIONS_KEY, JSON.stringify(next));
      } catch {
        /* ignore */
      }
      return next;
    });
  }

  function isSectionOpen(section: NavSection): boolean {
    if (collapsed) return false;
    if (openSections[section.id] === true) return true;
    if (openSections[section.id] === false) return false;
    return section.id === "overview" || sectionContainsActive(section, pathname);
  }

  const allItems = useMemo(
    () => sections.flatMap((s) => s.items.filter(isFlagAllowed)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [sections, enabledFlags],
  );

  const mobileNav = isClient
    ? [
        { href: "/app", label: "Home", icon: LayoutDashboard },
        { href: "/app/connect", label: "Connect", icon: Compass },
        { href: "/app/messages", label: "Messages", icon: MessageSquare },
        { href: "/app/notifications", label: "Alerts", icon: Bell },
        { href: "/app/settings", label: "Settings", icon: Settings },
      ]
    : [
        { href: "/app", label: "Home", icon: LayoutDashboard },
        { href: "/app/proposals", label: "Proposals", icon: FileText },
        { href: "/app/projects", label: "Work", icon: FolderKanban },
        { href: "/app/connect", label: "Connect", icon: Compass },
        { href: "/app/account", label: "Account", icon: UserCircle },
      ];

  const commandItems: CommandItem[] = useMemo(() => {
    const items: CommandItem[] = allItems.map((item) => ({
      href: item.href,
      label: item.label,
      group: "Navigate",
    }));
    items.push(
      { href: "/app/settings", label: "Settings", group: "Account" },
      { href: "/app/hub", label: "Hub", group: "Navigate" },
    );
    const seen = new Set<string>();
    return items.filter((item) => {
      const key = `${item.href}|${item.label}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [allItems]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setCommandOpen(true);
      }
      if (e.key === "Escape") {
        setMobileDrawerOpen(false);
        setCommandOpen(false);
        setProfileMenuOpen(false);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (!profileMenuOpen) return;
    function onDoc(e: MouseEvent) {
      if (!profileMenuRef.current?.contains(e.target as Node)) {
        setProfileMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [profileMenuOpen]);

  useEffect(() => {
    setMobileDrawerOpen(false);
  }, [pathname]);

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  function isActive(href: string) {
    if (href === "/app") return pathname === "/app";
    if (href === "/app/payments") return pathname === "/app/payments";
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  const pageTitle =
    pathname === "/app"
      ? "Dashboard"
      : pathname.startsWith("/app/payments")
        ? "Payments"
        : pathname.startsWith("/app/invoices")
          ? "Invoices"
          : pathname.startsWith("/app/team")
            ? isClient
              ? "My team"
              : "Team"
            : allItems.find((n) => isActive(n.href))?.label ?? "App";

  const profileHref = "/app/account";

  function renderNavSections(opts: { collapsedView: boolean; onNavigate?: () => void }) {
    const { collapsedView, onNavigate } = opts;
    return (
      <nav className="flex-1 space-y-1 overflow-y-auto px-2 py-3">
        {sections.map((section) => {
          const visibleItems = section.items.filter(isFlagAllowed);
          if (visibleItems.length === 0) return null;
          const SectionIcon = section.icon;
          const open = isSectionOpen(section);
          const sectionActive = sectionContainsActive(section, pathname);

          if (collapsedView) {
            return (
              <div key={section.id} className="space-y-0.5">
                {visibleItems.map((item, i) => (
                  <NavLink
                    key={`${item.href}-${item.label}-${i}`}
                    item={item}
                    active={isActive(item.href) && !item.cta}
                    isClient={isClient}
                    collapsed
                    onNavigate={onNavigate}
                  />
                ))}
              </div>
            );
          }

          return (
            <div key={section.id} className="pt-1">
              <button
                type="button"
                onClick={() => toggleSection(section.id)}
                className={cn(
                  "flex w-full items-center gap-2 rounded-xl px-3 py-2 text-[11px] font-bold uppercase tracking-wider transition",
                  sectionActive ? "text-white" : "text-white/45 hover:bg-white/5 hover:text-white/80",
                )}
                aria-expanded={open}
              >
                <SectionIcon className="h-3.5 w-3.5 shrink-0" />
                <span className="flex-1 text-left">{section.label}</span>
                <ChevronDown className={cn("h-3.5 w-3.5 transition", open && "rotate-180")} />
              </button>
              {open && (
                <div className="mt-0.5 space-y-0.5">
                  {visibleItems.map((item, i) => (
                    <NavLink
                      key={`${item.href}-${item.label}-${i}`}
                      item={item}
                      active={isActive(item.href) && !item.cta}
                      isClient={isClient}
                      nested={visibleItems.length > 1}
                      onNavigate={onNavigate}
                    />
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </nav>
    );
  }

  function renderSidebarChrome(opts: { collapsedView: boolean; onNavigate?: () => void }) {
    const { collapsedView, onNavigate } = opts;
    return (
      <>
        <div className={cn("border-b border-white/10", collapsedView ? "px-2 py-4" : "px-4 py-5")}>
          <Link href="/app" className="block" onClick={onNavigate}>
            <Logo size="sm" variant="onDark" showText={!collapsedView} />
          </Link>
          {!collapsedView && (
            <p
              className={cn(
                "mt-2 text-[10px] font-bold uppercase tracking-[0.14em]",
                isClient ? "text-white/50" : "text-primary-light",
              )}
            >
              {isClient ? "Client portal" : "Freelancer portal"}
            </p>
          )}
        </div>

        {!collapsedView && (
          <div className="relative border-b border-white/10 px-4 py-4" ref={profileMenuRef}>
            <button
              type="button"
              onClick={() => setProfileMenuOpen((o) => !o)}
              className="flex w-full items-center gap-3 rounded-xl px-1 py-1 text-left transition hover:bg-white/5"
              aria-expanded={profileMenuOpen}
              aria-haspopup="menu"
            >
              <span className="relative shrink-0">
                <UserAvatar
                  name={profile.name}
                  email={profile.email}
                  avatarUrl={profile.avatar_url}
                  size="lg"
                  className="bg-white/10"
                />
                <span className="absolute bottom-0 right-0 h-2.5 w-2.5 rounded-full border-2 border-navy bg-success" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{profile.name || profile.email}</p>
                {pro ? (
                  <span
                    className={cn(
                      "mt-1 inline-flex items-center gap-1 rounded-lg px-2 py-0.5 text-[10px] font-bold uppercase",
                      isClient ? "bg-white/15 text-white" : "bg-primary/20 text-primary-light",
                    )}
                  >
                    <Diamond className="h-3 w-3" />
                    {plan}
                  </span>
                ) : (
                  <span className="mt-1 inline-block text-[10px] font-semibold uppercase tracking-wide text-white/50">
                    Free plan
                  </span>
                )}
              </div>
              <ChevronDown
                className={cn("h-4 w-4 shrink-0 text-white/40 transition", profileMenuOpen && "rotate-180")}
              />
            </button>
            {profileMenuOpen && (
              <div
                role="menu"
                className="absolute left-3 right-3 top-[calc(100%-0.5rem)] z-50 overflow-hidden rounded-xl border border-white/10 bg-navy shadow-xl"
              >
                <Link
                  href={profileHref}
                  role="menuitem"
                  onClick={() => {
                    setProfileMenuOpen(false);
                    onNavigate?.();
                  }}
                  className="flex items-center gap-2 px-3 py-2.5 text-sm text-white/80 hover:bg-white/10 hover:text-white"
                >
                  <UserCircle className="h-4 w-4" />
                  My profile
                </Link>
                <Link
                  href="/app/settings"
                  role="menuitem"
                  onClick={() => {
                    setProfileMenuOpen(false);
                    onNavigate?.();
                  }}
                  className="flex items-center gap-2 px-3 py-2.5 text-sm text-white/80 hover:bg-white/10 hover:text-white"
                >
                  <Settings className="h-4 w-4" />
                  Settings
                </Link>
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    setProfileMenuOpen(false);
                    void signOut();
                  }}
                  className="flex w-full items-center gap-2 border-t border-white/10 px-3 py-2.5 text-sm text-white/80 hover:bg-white/10 hover:text-white"
                >
                  <LogOut className="h-4 w-4" />
                  Sign out
                </button>
              </div>
            )}
          </div>
        )}

        {renderNavSections(opts)}

        <div className={cn("border-t border-white/10", collapsedView ? "p-2" : "p-4")}>
          {!collapsedView && (
            <>
              <Link
                href="/app/connect/manage"
                onClick={onNavigate}
                className={cn(
                  "mb-3 flex w-full items-center justify-center gap-2 rounded-xl px-3 py-2.5 text-sm font-bold text-white",
                  isClient
                    ? "border border-white/20 bg-transparent hover:bg-white/5"
                    : "bg-primary hover:bg-primary-dark",
                )}
              >
                <Plus className="h-4 w-4" />
                {isClient ? "Post a job" : "Post a need"}
              </Link>
              <div className="rounded-xl border border-white/10 bg-white/5 p-3">
                <p className="text-xs font-bold text-white/80">Founder Access</p>
                <p className="mt-1 text-[10px] text-white/50">
                  All workspace & Connect features unlocked ($0 platform fees)
                </p>
                <Link
                  href="/app/settings"
                  onClick={onNavigate}
                  className={cn(
                    "mt-2 block rounded-lg px-3 py-1.5 text-center text-xs font-semibold text-white",
                    isClient ? "bg-white/15 hover:bg-white/25" : "bg-primary",
                  )}
                >
                  Account Settings
                </Link>
              </div>
            </>
          )}
          {collapsedView && (
            <Link
              href="/app/connect/manage"
              title={isClient ? "Post a job" : "Post a need"}
              onClick={onNavigate}
              className={cn(
                "flex items-center justify-center rounded-xl p-2.5 text-white",
                isClient ? "border border-white/20" : "bg-primary",
              )}
            >
              <Plus className="h-4 w-4" />
            </Link>
          )}
        </div>
      </>
    );
  }

  return (
    <div
      className={cn(
        "flex min-h-screen bg-background text-text-primary",
        isClient && "theme-client",
      )}
    >
      <aside
        className={cn(
          "sticky top-0 hidden h-screen shrink-0 flex-col bg-navy text-white transition-all duration-200 lg:flex",
          collapsed ? "w-[72px]" : "w-64",
        )}
      >
        {renderSidebarChrome({ collapsedView: collapsed })}
      </aside>

      {mobileDrawerOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-black/50"
            aria-label="Close menu"
            onClick={() => setMobileDrawerOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 flex w-[min(100%,20rem)] flex-col bg-navy text-white shadow-2xl">
            <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
              <p className="text-sm font-bold text-white">
                {isClient ? "Client menu" : "Freelancer menu"}
              </p>
              <button
                type="button"
                onClick={() => setMobileDrawerOpen(false)}
                className="rounded-lg border border-white/15 p-2 text-white/80"
                aria-label="Close menu"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            {renderSidebarChrome({
              collapsedView: false,
              onNavigate: () => setMobileDrawerOpen(false),
            })}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-border bg-surface/95 backdrop-blur">
          <div className="flex items-center gap-3 px-4 py-3 sm:px-6">
            <button
              type="button"
              onClick={() => {
                if (typeof window !== "undefined" && window.matchMedia("(min-width: 1024px)").matches) {
                  setCollapsed((v) => !v);
                } else {
                  setMobileDrawerOpen(true);
                }
              }}
              className="rounded-lg border border-border p-2 text-text-secondary hover:bg-background"
              aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
              title="Toggle sidebar"
            >
              <Menu className="h-4 w-4" />
            </button>
            <div className="lg:hidden">
              <Logo size="sm" variant="onLight" showText={false} />
            </div>
            <p className="hidden font-display text-sm font-bold text-navy sm:block">{pageTitle}</p>
            <button
              type="button"
              onClick={() => setCommandOpen(true)}
              className="relative mx-auto hidden max-w-md flex-1 text-left sm:block"
            >
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
              <span className="block w-full rounded-full border border-border bg-background py-2 pl-10 pr-16 text-sm text-text-muted">
                {isClient
                  ? "Search freelancers, projects, invoices..."
                  : "Search anything..."}
              </span>
              <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 rounded-md bg-surface px-1.5 py-0.5 text-[10px] font-bold text-text-muted">
                ⌘K
              </span>
            </button>
            <div className="ml-auto flex items-center gap-1">
              <button
                type="button"
                onClick={() => setCommandOpen(true)}
                className="rounded-full p-2 text-text-secondary hover:bg-background sm:hidden"
                aria-label="Search"
              >
                <Search className="h-5 w-5" />
              </button>
              <Link
                href="/app/messages"
                className="rounded-full p-2 text-text-secondary hover:bg-background"
                aria-label="Messages"
              >
                <MessageSquare className="h-5 w-5" />
              </Link>
              <Link
                href="/app/notifications"
                className="relative rounded-full p-2 text-text-secondary hover:bg-background"
                aria-label="Notifications"
              >
                <Bell className="h-5 w-5" />
                {(counts?.notifications ?? 0) > 0 && (
                  <span className="absolute right-1 top-1 flex h-4 w-4 items-center justify-center rounded-full bg-error text-[9px] font-bold text-white">
                    {counts!.notifications}
                  </span>
                )}
              </Link>
              <button
                type="button"
                onClick={() => setAiModalOpen(true)}
                className="group relative flex items-center gap-1.5 rounded-full border border-primary/30 bg-primary/10 px-3 py-1.5 text-xs font-bold text-primary hover:bg-primary/20 transition shadow-sm"
                title="CLIVORA AI Assistant (Proposals, Invoices & Health)"
              >
                <Sparkles className="h-3.5 w-3.5 text-primary" />
                <span className="hidden sm:inline">AI Assistant</span>
              </button>
              <Link
                href="/app/settings"
                className={cn(
                  "hidden items-center gap-1 rounded-full px-3 py-1.5 text-xs font-semibold text-white sm:inline-flex",
                  isClient ? "bg-navy" : "bg-primary",
                )}
                title="Founder Access: $0 platform fees"
              >
                <Sparkles className="h-3.5 w-3.5" />
                Founder Access
              </Link>
              <Link href={profileHref} className="block shrink-0">
                <UserAvatar
                  name={profile.name}
                  email={profile.email}
                  avatarUrl={profile.avatar_url}
                  size="md"
                />
              </Link>
              <button
                type="button"
                onClick={signOut}
                className="hidden rounded-full p-2 text-text-muted hover:bg-background lg:inline-flex"
                aria-label="Sign out"
              >
                <LogOut className="h-4 w-4" />
              </button>
            </div>
          </div>
        </header>

        <main className="flex-1 px-4 py-6 pb-24 sm:px-6 lg:px-8 lg:pb-6">{children}</main>
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-white/10 bg-navy lg:hidden">
        <div className="mx-auto flex max-w-lg justify-around px-1 py-2">
          {mobileNav.map((item) => {
            const active = isActive(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex flex-col items-center gap-0.5 rounded-lg px-1.5 py-1 text-[10px] font-semibold",
                  active
                    ? isClient
                      ? "text-white"
                      : "text-primary-light"
                    : "text-white/50",
                )}
              >
                <Icon className="h-5 w-5" />
                {item.label}
              </Link>
            );
          })}
        </div>
      </nav>

      <CommandPalette
        open={commandOpen}
        onClose={() => setCommandOpen(false)}
        items={commandItems}
        isClient={isClient}
      />
    </div>
  );
}
