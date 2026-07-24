"use client";

import {
  clearAdminSession,
  getAdminProfile,
  isSuperAdmin,
  refreshAdminProfile,
} from "@/lib/auth";
import { roleLabel, t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import {
  CreditCard,
  FileText,
  Hash,
  LayoutDashboard,
  LogOut,
  MessageSquareLock,
  Package,
  RotateCcw,
  Shield,
  Tag,
  Users,
  Wallet,
  Wrench,
} from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type NavItem = {
  href: string;
  labelKey: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  superOnly?: boolean;
};

const navItems: NavItem[] = [
  { href: "/dashboard", labelKey: "nav.overview", icon: LayoutDashboard, exact: true },
  { href: "/dashboard/users", labelKey: "nav.users", icon: Users },
  { href: "/dashboard/subscriptions", labelKey: "nav.subscriptions", icon: CreditCard },
  { href: "/dashboard/promo-codes", labelKey: "nav.promos", icon: Tag },
  { href: "/dashboard/payments", labelKey: "nav.payments", icon: Wallet },
  { href: "/dashboard/chats", labelKey: "nav.chats", icon: MessageSquareLock, superOnly: true },
  { href: "/dashboard/restore", labelKey: "nav.restore", icon: RotateCcw, superOnly: true },
  { href: "/dashboard/audit", labelKey: "nav.audit", icon: Shield, superOnly: true },
  { href: "/dashboard/number-groups", labelKey: "nav.numberGroups", icon: Hash },
  { href: "/dashboard/products", labelKey: "nav.products", icon: Package },
  { href: "/dashboard/maintenance", labelKey: "nav.maintenance", icon: Wrench, superOnly: true },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const [profile, setProfile] = useState(getAdminProfile());

  useEffect(() => {
    refreshAdminProfile()
      .then((p) => {
        if (!p) {
          router.replace("/login");
          return;
        }
        setProfile(p);
        setReady(true);
      })
      .catch(() => router.replace("/login"));
  }, [router]);

  async function handleSignOut() {
    await clearAdminSession();
    router.replace("/login");
  }

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-900" />
      </div>
    );
  }

  const visibleNav = navItems.filter((item) => !item.superOnly || isSuperAdmin());

  return (
    <div className="flex min-h-screen bg-zinc-50">
      <aside className="flex w-64 shrink-0 flex-col bg-zinc-950 text-zinc-100">
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

        <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4" aria-label="Asosiy navigatsiya">
          {visibleNav.map(({ href, labelKey, icon: Icon, exact }) => {
            const active = exact ? pathname === href : pathname.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition",
                  active
                    ? "bg-zinc-800 text-white"
                    : "text-zinc-400 hover:bg-zinc-800/60 hover:text-white",
                )}
              >
                <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
                <span className="truncate">{t(labelKey)}</span>
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-zinc-800 p-3">
          <button
            type="button"
            onClick={() => void handleSignOut()}
            className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-zinc-400 transition hover:bg-zinc-800 hover:text-white"
          >
            <LogOut className="h-4 w-4 shrink-0" aria-hidden="true" />
            {t("nav.signOut")}
          </button>
          <p className="mt-2 flex items-center gap-1 px-3 text-[10px] text-zinc-600">
            <FileText className="h-3 w-3" /> {t("app.audited")}
          </p>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <main className="flex-1 overflow-auto p-6 lg:p-8">{children}</main>
      </div>
    </div>
  );
}
