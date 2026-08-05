"use client";

import { CommandPalette } from "@/components/command-palette";
import { useI18nTick, useLocale } from "@/components/locale-provider";
import { useTheme } from "@/components/theme-provider";
import {
  clearAdminSession,
  getAdminProfile,
  refreshAdminProfile,
} from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import { roleLabel, t, type Locale } from "@/lib/i18n";
import { can, canAccessPath, firstAllowedPath, type Permission } from "@/lib/rbac";
import { cn } from "@/lib/utils";
import {
  ClipboardList,
  CreditCard,
  FileText,
  Hash,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageSquareLock,
  MessageSquareQuote,
  Moon,
  Package,
  RotateCcw,
  Search,
  Shield,
  Sun,
  Tag,
  Users,
  Wallet,
  Wrench,
  X,
} from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

type NavItem = {
  href: string;
  labelKey: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  permission: Permission;
  badgeIds?: string[];
};

const navItems: NavItem[] = [
  { href: "/dashboard", labelKey: "nav.overview", icon: LayoutDashboard, exact: true, permission: "overview" },
  { href: "/dashboard/users", labelKey: "nav.users", icon: Users, permission: "users" },
  {
    href: "/dashboard/verification",
    labelKey: "nav.verification",
    icon: FileText,
    permission: "verification",
    badgeIds: ["verification_pending"],
  },
  {
    href: "/dashboard/applications",
    labelKey: "nav.applications",
    icon: ClipboardList,
    permission: "applications",
    badgeIds: ["applications_pending"],
  },
  { href: "/dashboard/subscriptions", labelKey: "nav.subscriptions", icon: CreditCard, permission: "subscriptions" },
  { href: "/dashboard/promo-codes", labelKey: "nav.promos", icon: Tag, permission: "promos" },
  {
    href: "/dashboard/payments",
    labelKey: "nav.payments",
    icon: Wallet,
    permission: "payments",
    badgeIds: ["failed_payments"],
  },
  { href: "/dashboard/chats", labelKey: "nav.chats", icon: MessageSquareLock, permission: "chats" },
  {
    href: "/dashboard/restore",
    labelKey: "nav.restore",
    icon: RotateCcw,
    permission: "restore",
    badgeIds: ["restore_pending"],
  },
  { href: "/dashboard/audit", labelKey: "nav.audit", icon: Shield, permission: "audit" },
  { href: "/dashboard/number-groups", labelKey: "nav.numberGroups", icon: Hash, permission: "numberGroups" },
  {
    href: "/dashboard/products",
    labelKey: "nav.products",
    icon: Package,
    permission: "products",
    badgeIds: ["products_pending"],
  },
  {
    href: "/dashboard/reviews",
    labelKey: "nav.reviews",
    icon: MessageSquareQuote,
    permission: "reviews",
    badgeIds: ["reviews_pending"],
  },
  { href: "/dashboard/maintenance", labelKey: "nav.maintenance", icon: Wrench, permission: "maintenance" },
];

type InboxItem = { id: string; count: number; href: string };

function NavLinks({
  pathname,
  badges,
  onNavigate,
  compact,
}: {
  pathname: string;
  badges: Record<string, number>;
  onNavigate?: () => void;
  compact?: boolean;
}) {
  const profile = getAdminProfile();
  const visible = navItems.filter((item) => can(profile?.role, item.permission));

  return (
    <nav
      className={cn("space-y-1", compact ? "px-2 py-2" : "flex-1 overflow-y-auto px-3 py-4")}
      aria-label="nav"
    >
      {visible.map(({ href, labelKey, icon: Icon, exact, badgeIds }) => {
        const active = exact ? pathname === href : pathname.startsWith(href);
        const badge = (badgeIds ?? []).reduce((sum, id) => sum + (badges[id] || 0), 0);
        return (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            className={cn(
              "flex min-h-11 items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition active:scale-[0.99]",
              active
                ? "bg-zinc-800 text-white dark:bg-zinc-700"
                : "text-zinc-400 hover:bg-zinc-800/60 hover:text-white",
            )}
          >
            <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
            <span className="min-w-0 flex-1 truncate">{t(labelKey)}</span>
            {badge > 0 ? (
              <span className="rounded-full bg-rose-500 px-1.5 py-0.5 text-[10px] font-semibold text-white tabular-nums">
                {badge > 99 ? "99+" : badge}
              </span>
            ) : null}
          </Link>
        );
      })}
    </nav>
  );
}

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  useI18nTick();
  const { locale, setLocale } = useLocale();
  const { mode, setMode, resolved } = useTheme();
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [profile, setProfile] = useState(getAdminProfile());
  const [mobileOpen, setMobileOpen] = useState(false);
  const [badges, setBadges] = useState<Record<string, number>>({});

  const loadBadges = useCallback(async () => {
    try {
      const data = await apiFetch<{ items: InboxItem[] }>("/api/v1/admin/inbox");
      const map: Record<string, number> = {};
      for (const it of data.items || []) {
        map[it.id] = Number(it.count) || 0;
      }
      setBadges(map);
    } catch {
      // non-blocking
    }
  }, []);

  useEffect(() => {
    refreshAdminProfile()
      .then((p) => {
        if (!p) {
          router.replace("/login");
          return;
        }
        setProfile(p);
        if (!canAccessPath(p.role, pathname)) {
          router.replace(firstAllowedPath(p.role));
          return;
        }
        setReady(true);
      })
      .catch(() => router.replace("/login"));
  }, [router, pathname]);

  useEffect(() => {
    if (!ready) return;
    void loadBadges();
    const id = window.setInterval(() => void loadBadges(), 60_000);
    return () => window.clearInterval(id);
  }, [ready, loadBadges]);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  async function handleSignOut() {
    await clearAdminSession();
    router.replace("/login");
  }

  const forbidden = useMemo(() => {
    if (!profile) return false;
    return !canAccessPath(profile.role, pathname);
  }, [profile, pathname]);

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 dark:bg-zinc-950">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-900 dark:border-zinc-600 dark:border-t-zinc-100" />
      </div>
    );
  }

  const sidebar = (
    <>
      <div className="border-b border-zinc-800 px-5 py-5">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-zinc-500">
          {t("nav.operations")}
        </p>
        <h1 className="mt-1 text-lg font-semibold text-white">{t("app.name")}</h1>
        {profile ? (
          <p className="mt-2 truncate text-xs text-zinc-400">
            {profile.full_name} ·{" "}
            <span className="text-emerald-400">{roleLabel(profile.role)}</span>
          </p>
        ) : null}
      </div>

      <NavLinks
        pathname={pathname}
        badges={badges}
        onNavigate={() => setMobileOpen(false)}
      />

      <div className="mt-auto space-y-2 border-t border-zinc-800 p-3">
        <div className="flex gap-1">
          {(["uz", "ru", "en"] as Locale[]).map((l) => (
            <button
              key={l}
              type="button"
              onClick={() => setLocale(l)}
              className={cn(
                "flex-1 rounded-md px-2 py-1.5 text-[11px] font-semibold uppercase",
                locale === l
                  ? "bg-zinc-700 text-white"
                  : "text-zinc-500 hover:bg-zinc-800 hover:text-zinc-200",
              )}
            >
              {l}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => {
            const next =
              mode === "light" ? "dark" : mode === "dark" ? "system" : "light";
            setMode(next);
          }}
          className="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-white"
        >
          {resolved === "dark" ? <Sun className="h-3.5 w-3.5" /> : <Moon className="h-3.5 w-3.5" />}
          {t("app.theme")}:{" "}
          {mode === "system"
            ? t("app.themeSystem")
            : t(`app.theme${resolved === "dark" ? "Dark" : "Light"}`)}
        </button>
        <button
          type="button"
          onClick={() => void handleSignOut()}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-zinc-400 transition hover:bg-zinc-800 hover:text-white"
        >
          <LogOut className="h-4 w-4 shrink-0" aria-hidden="true" />
          {t("nav.signOut")}
        </button>
        <p className="flex items-center gap-1 px-3 text-[10px] text-zinc-600">
          <FileText className="h-3 w-3" /> {t("app.audited")}
        </p>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-zinc-50 dark:bg-zinc-950">
      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 flex-col bg-zinc-950 text-zinc-100 md:flex">
        {sidebar}
      </aside>

      {/* Mobile drawer */}
      {mobileOpen ? (
        <div className="fixed inset-0 z-40 md:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-black/50"
            aria-label={t("app.close")}
            onClick={() => setMobileOpen(false)}
          />
          <aside className="relative flex h-full w-[min(100%,18rem)] flex-col bg-zinc-950 text-zinc-100 shadow-xl">
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              className="absolute right-3 top-3 rounded-lg p-2 text-zinc-400 hover:bg-zinc-800"
              aria-label={t("app.close")}
            >
              <X className="h-5 w-5" />
            </button>
            {sidebar}
          </aside>
        </div>
      ) : null}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex items-center gap-2 border-b border-zinc-200 bg-white/90 px-3 py-2 backdrop-blur dark:border-zinc-800 dark:bg-zinc-900/90 md:px-6">
          <button
            type="button"
            className="rounded-lg p-2 text-zinc-700 hover:bg-zinc-100 dark:text-zinc-200 dark:hover:bg-zinc-800 md:hidden"
            onClick={() => setMobileOpen(true)}
            aria-label={t("app.menu")}
          >
            <Menu className="h-5 w-5" />
          </button>
          <button
            type="button"
            onClick={() => window.dispatchEvent(new Event("anylang:open-command"))}
            className="flex min-h-10 flex-1 items-center gap-2 rounded-lg border border-zinc-200 bg-zinc-50 px-3 text-left text-sm text-zinc-500 dark:border-zinc-700 dark:bg-zinc-800/50 dark:text-zinc-400 md:max-w-md"
          >
            <Search className="h-4 w-4 shrink-0" />
            <span className="truncate">{t("command.placeholder")}</span>
            <kbd className="ml-auto hidden rounded border border-zinc-300 px-1.5 py-0.5 text-[10px] dark:border-zinc-600 sm:inline">
              ⌘K
            </kbd>
          </button>
          <div className="hidden items-center gap-1 sm:flex">
            {(
              [
                ["verification_pending", "/dashboard/verification"],
                ["products_pending", "/dashboard/products"],
                ["reviews_pending", "/dashboard/reviews"],
              ] as const
            ).map(([id, href]) => {
              const n = badges[id] || 0;
              if (n <= 0 || !canAccessPath(profile?.role, href)) return null;
              return (
                <Link
                  key={id}
                  href={href}
                  className="rounded-full bg-rose-100 px-2 py-1 text-[11px] font-semibold text-rose-800 dark:bg-rose-950 dark:text-rose-200"
                >
                  {n}
                </Link>
              );
            })}
          </div>
        </header>

        <main className="flex-1 overflow-auto p-4 pb-24 md:p-6 lg:p-8 lg:pb-8">
          {forbidden ? (
            <div className="rounded-xl border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-100">
              {t("app.forbidden")}
            </div>
          ) : (
            <div key={locale}>{children}</div>
          )}
        </main>

        {/* Mobile bottom quick actions for queues */}
        <nav className="fixed inset-x-0 bottom-0 z-30 flex border-t border-zinc-200 bg-white/95 px-1 py-1 backdrop-blur dark:border-zinc-800 dark:bg-zinc-900/95 md:hidden">
          {(
            [
              ["/dashboard/verification", "nav.verification", "verification_pending"],
              ["/dashboard/products", "nav.products", "products_pending"],
              ["/dashboard/reviews", "nav.reviews", "reviews_pending"],
              ["/dashboard/payments", "nav.payments", "failed_payments"],
            ] as const
          )
            .filter(([href]) => canAccessPath(profile?.role, href))
            .map(([href, labelKey, badgeId]) => {
              const active = pathname.startsWith(href);
              const n = badges[badgeId] || 0;
              return (
                <Link
                  key={href}
                  href={href}
                  className={cn(
                    "relative flex min-h-12 flex-1 flex-col items-center justify-center gap-0.5 rounded-lg text-[10px] font-medium",
                    active
                      ? "text-zinc-900 dark:text-white"
                      : "text-zinc-500 dark:text-zinc-400",
                  )}
                >
                  <span className="truncate px-1">{t(labelKey)}</span>
                  {n > 0 ? (
                    <span className="absolute right-2 top-1 rounded-full bg-rose-500 px-1 text-[9px] text-white">
                      {n > 99 ? "99+" : n}
                    </span>
                  ) : null}
                </Link>
              );
            })}
        </nav>
      </div>

      <CommandPalette />
    </div>
  );
}
