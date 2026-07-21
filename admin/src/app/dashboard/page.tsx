"use client";

import { Alert } from "@/components/admin/alert";
import { LoadingGrid } from "@/components/admin/loading-grid";
import { PageHeader } from "@/components/admin/page-header";
import { StatCard } from "@/components/admin/stat-card";
import { ApiError, apiFetch } from "@/lib/api";
import { API_BASE } from "@/lib/env";
import { formatNumber, planLabel, statusLabel, t } from "@/lib/i18n";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

type Overview = {
  from: string;
  to: string;
  users_total: number;
  users_deleted: number;
  users_new: number;
  subscriptions_active: number;
  subscriptions_by_plan: Record<string, number>;
  revenue: string;
  payments_by_status: Record<string, number>;
  chats_total: number;
  messages_total: number;
};

type Timeseries = {
  metric: string;
  points: { date: string; value: number }[];
};

const quickLinks = [
  { href: "/dashboard/users", label: t("nav.users") },
  { href: "/dashboard/payments", label: t("nav.payments") },
  { href: "/dashboard/subscriptions", label: t("nav.subscriptions") },
  { href: "/dashboard/products", label: t("nav.products") },
  { href: "/dashboard/restore", label: t("nav.restore") },
  { href: "/dashboard/audit", label: t("nav.audit") },
];

export default function DashboardPage() {
  const [overview, setOverview] = useState<Overview | null>(null);
  const [series, setSeries] = useState<Timeseries | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [apiOk, setApiOk] = useState<boolean | null>(null);
  const [metric, setMetric] = useState<"users_new" | "revenue" | "payments">("users_new");
  const [days, setDays] = useState(30);

  const load = useCallback(async () => {

    setLoading(true);
    setError(null);

    const to = new Date();
    const from = new Date();
    from.setDate(from.getDate() - days);
    const fromStr = from.toISOString().slice(0, 10);
    const toStr = to.toISOString().slice(0, 10);
    const range = `from=${fromStr}&to=${toStr}`;

    try {
      const [o, s] = await Promise.all([
        apiFetch<Overview>(`/api/v1/admin/analytics/overview?${range}`),
        apiFetch<Timeseries>(
          `/api/v1/admin/analytics/timeseries?metric=${metric}&${range}`,
        ),
      ]);
      setOverview(o);
      setSeries(s);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }, [days, metric]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    fetch(`${API_BASE}/health`, { method: "GET" })
      .then((r) => setApiOk(r.ok))
      .catch(() => setApiOk(false));
  }, []);

  const maxPoint = Math.max(1, ...(series?.points.map((p) => Number(p.value)) ?? [1]));

  const metricLabels: Record<string, string> = {
    users_new: t("dashboard.usersNew"),
    revenue: t("dashboard.revenue"),
    payments: t("nav.payments"),
  };

  return (
    <div className="space-y-8">
      <PageHeader title={t("dashboard.title")} subtitle={t("dashboard.subtitle")}>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value={7}>7 kun</option>
          <option value={30}>{t("dashboard.last30")}</option>
          <option value={90}>90 kun</option>
        </select>
        <button
          type="button"
          onClick={() => void load()}
          className="rounded-lg border bg-white px-4 py-2 text-sm hover:bg-zinc-50"
        >
          {t("app.refresh")}
        </button>
      </PageHeader>

      <div className="flex items-center gap-3 rounded-xl border bg-white px-4 py-3 text-sm">
        <span
          className={`h-2.5 w-2.5 rounded-full ${apiOk ? "bg-emerald-500" : apiOk === false ? "bg-red-500" : "bg-zinc-300"}`}
        />
        <span className="font-medium">{t("dashboard.systemHealth")}:</span>
        <span className="text-zinc-600">
          {apiOk === null
            ? t("app.loading")
            : apiOk
              ? t("dashboard.apiOnline")
              : t("dashboard.apiOffline")}
        </span>
        {overview ? (
          <span className="ml-auto text-xs text-zinc-500">
            {overview.from} → {overview.to}
          </span>
        ) : null}
      </div>

      {loading ? (
        <LoadingGrid count={8} />
      ) : error ? (
        <Alert variant="error">{error}</Alert>
      ) : overview ? (
        <>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard label={t("dashboard.usersTotal")} value={formatNumber(overview.users_total)} accent />
            <StatCard label={t("dashboard.usersNew")} value={formatNumber(overview.users_new)} />
            <StatCard label={t("dashboard.usersDeleted")} value={formatNumber(overview.users_deleted)} />
            <StatCard label={t("dashboard.subsActive")} value={formatNumber(overview.subscriptions_active)} />
            <StatCard label={t("dashboard.revenue")} value={`$${overview.revenue}`} accent />
            <StatCard label={t("dashboard.chatsTotal")} value={formatNumber(overview.chats_total)} />
            <StatCard label={t("dashboard.messagesTotal")} value={formatNumber(overview.messages_total)} />
            <StatCard
              label={t("dashboard.plansCount")}
              value={Object.keys(overview.subscriptions_by_plan).length}
            />
          </div>

          <div className="grid gap-6 lg:grid-cols-3">
            <section className="rounded-xl border bg-white p-5 lg:col-span-1">
              <h2 className="text-sm font-semibold">{t("dashboard.subsByPlan")}</h2>
              <ul className="mt-4 space-y-2">
                {Object.entries(overview.subscriptions_by_plan).map(([plan, count]) => (
                  <li key={plan} className="flex justify-between text-sm">
                    <span className="text-zinc-600">{planLabel(plan)}</span>
                    <span className="font-medium tabular-nums">{count}</span>
                  </li>
                ))}
                {Object.keys(overview.subscriptions_by_plan).length === 0 ? (
                  <li className="text-sm text-zinc-500">{t("app.noData")}</li>
                ) : null}
              </ul>
            </section>

            <section className="rounded-xl border bg-white p-5 lg:col-span-1">
              <h2 className="text-sm font-semibold">{t("dashboard.paymentsByStatus")}</h2>
              <ul className="mt-4 space-y-2">
                {Object.entries(overview.payments_by_status).map(([st, count]) => (
                  <li key={st} className="flex justify-between text-sm">
                    <span className="text-zinc-600">{statusLabel(st)}</span>
                    <span className="font-medium tabular-nums">{count}</span>
                  </li>
                ))}
                {Object.keys(overview.payments_by_status).length === 0 ? (
                  <li className="text-sm text-zinc-500">{t("app.noData")}</li>
                ) : null}
              </ul>
            </section>

            <section className="rounded-xl border bg-white p-5 lg:col-span-1">
              <h2 className="text-sm font-semibold">{t("dashboard.quickLinks")}</h2>
              <ul className="mt-4 space-y-2">
                {quickLinks.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="text-sm font-medium text-zinc-900 underline hover:text-zinc-600"
                    >
                      {link.label} →
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          </div>

          <section className="rounded-xl border bg-white p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <h2 className="text-sm font-semibold">{t("dashboard.newUsersDaily")}</h2>
              <select
                value={metric}
                onChange={(e) => setMetric(e.target.value as typeof metric)}
                className="rounded border px-2 py-1 text-xs"
              >
                <option value="users_new">{metricLabels.users_new}</option>
                <option value="revenue">{metricLabels.revenue}</option>
                <option value="payments">{metricLabels.payments}</option>
              </select>
            </div>
            <div className="mt-4 flex h-40 items-end gap-1 overflow-x-auto">
              {(series?.points ?? []).map((p) => (
                <div key={p.date} className="flex min-w-[10px] flex-1 flex-col items-center gap-1">
                  <div
                    className="w-full rounded-t bg-emerald-500/80"
                    style={{ height: `${Math.max(4, (Number(p.value) / maxPoint) * 120)}px` }}
                    title={`${p.date}: ${p.value}`}
                  />
                </div>
              ))}
              {(series?.points ?? []).length === 0 ? (
                <p className="text-sm text-zinc-500">{t("app.noData")}</p>
              ) : null}
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
