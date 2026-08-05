"use client";

import { Alert } from "@/components/admin/alert";
import { LoadingGrid } from "@/components/admin/loading-grid";
import { PageHeader } from "@/components/admin/page-header";
import { StatCard } from "@/components/admin/stat-card";
import { ApiError, apiFetch } from "@/lib/api";
import { API_BASE } from "@/lib/env";
import { auditActionLabel, formatDate, formatNumber, t } from "@/lib/i18n";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

type InboxItem = {
  id: string;
  category: string;
  count: number;
  href: string;
  sla_breach: number;
  meta?: Record<string, number>;
};

type TrendBlock = {
  points: { date: string; value: number }[];
  total: number;
  previous_total: number;
  change_pct: number | null;
};

type CommandCenter = {
  generated_at: string;
  days: number;
  from: string;
  to: string;
  refresh_interval_seconds: number;
  kpis: {
    dau: number;
    mau: number;
    dau_mau_ratio: number;
    users_new: number;
    users_new_change_pct: number | null;
    gmv: string;
    gmv_change_pct: number | null;
    churn_rate: number;
    churned_users_30d: number;
    users_total: number;
    subscriptions_active: number;
  };
  geo: { country: string; users: number; revenue: string }[];
  inbox: InboxItem[];
  trends: Record<string, TrendBlock>;
  ops_activity: {
    id: number;
    at: string | null;
    action: string;
    decision: string;
    actor_name: string;
    target_type: string | null;
    target_id: string | null;
  }[];
  ops_summary: { actor_name: string; approve: number; reject: number; other: number }[];
  legacy: {
    chats_total: number;
    messages_total: number;
    messages_total_approx: boolean;
  };
};

type MetricKey = "users_new" | "revenue" | "payments";

const HOUR_MS = 60 * 60 * 1000;

function countryFlag(code: string): string {
  if (!code || code.length !== 2) return "🌐";
  const cc = code.toUpperCase();
  return String.fromCodePoint(...[...cc].map((c) => 127397 + c.charCodeAt(0)));
}

function inboxLabel(id: string): string {
  return t(`dashboard.inboxItems.${id}`);
}

function formatPct(v: number | null | undefined): string {
  if (v == null) return "—";
  return `${v > 0 ? "+" : ""}${v.toFixed(1)}%`;
}

export default function DashboardPage() {
  const [data, setData] = useState<CommandCenter | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [apiOk, setApiOk] = useState<boolean | null>(null);
  const [metric, setMetric] = useState<MetricKey>("users_new");
  const [days, setDays] = useState<7 | 30 | 90>(30);
  const [lastFetchAt, setLastFetchAt] = useState<Date | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const cc = await apiFetch<CommandCenter>(
        `/api/v1/admin/analytics/command-center?days=${days}`,
      );
      setData(cc);
      setLastFetchAt(new Date());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const id = window.setInterval(() => void load(), HOUR_MS);
    return () => window.clearInterval(id);
  }, [load]);

  useEffect(() => {
    fetch(`${API_BASE}/health`, { method: "GET" })
      .then((r) => setApiOk(r.ok))
      .catch(() => setApiOk(false));
  }, []);

  const trend = data?.trends[metric];
  const maxPoint = Math.max(1, ...(trend?.points.map((p) => Number(p.value)) ?? [1]));
  const maxGeoUsers = Math.max(1, ...(data?.geo.map((g) => g.users) ?? [1]));

  const inboxOpen = useMemo(
    () => (data?.inbox ?? []).filter((i) => i.count > 0 || i.sla_breach > 0),
    [data],
  );

  const minutesToRefresh = lastFetchAt
    ? Math.max(0, Math.round((HOUR_MS - (Date.now() - lastFetchAt.getTime())) / 60000))
    : 60;

  const metricLabels: Record<MetricKey, string> = {
    users_new: t("dashboard.usersNew"),
    revenue: t("dashboard.gmv"),
    payments: t("nav.payments"),
  };

  return (
    <div className="space-y-8">
      <PageHeader title={t("dashboard.title")} subtitle={t("dashboard.subtitle")}>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value) as 7 | 30 | 90)}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value={7}>{t("dashboard.last7")}</option>
          <option value={30}>{t("dashboard.last30")}</option>
          <option value={90}>{t("dashboard.last90")}</option>
        </select>
        <button
          type="button"
          onClick={() => void load()}
          className="rounded-lg border bg-white px-4 py-2 text-sm hover:bg-zinc-50"
        >
          {t("app.refresh")}
        </button>
      </PageHeader>

      <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-white px-4 py-3 text-sm">
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
        <span className="hidden h-4 w-px bg-zinc-200 sm:block" />
        <span className="text-xs text-zinc-500">{t("dashboard.autoRefresh")}</span>
        {lastFetchAt ? (
          <span className="ml-auto text-xs text-zinc-500">
            {t("dashboard.lastUpdated", {
              time: lastFetchAt.toLocaleTimeString("uz-UZ", {
                hour: "2-digit",
                minute: "2-digit",
              }),
            })}
            {" · "}
            {t("dashboard.nextRefresh", { min: minutesToRefresh })}
          </span>
        ) : null}
      </div>

      {loading && !data ? (
        <LoadingGrid count={10} />
      ) : error && !data ? (
        <Alert variant="error">{error}</Alert>
      ) : data ? (
        <>
          {error ? <Alert variant="error">{error}</Alert> : null}

          {/* KPIs */}
          <section>
            <h2 className="mb-3 text-sm font-semibold text-zinc-800">{t("dashboard.kpiTitle")}</h2>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <StatCard label={t("dashboard.dau")} value={formatNumber(data.kpis.dau)} accent />
              <StatCard
                label={t("dashboard.mau")}
                value={formatNumber(data.kpis.mau)}
                hint={`${t("dashboard.dauMau")}: ${data.kpis.dau_mau_ratio}%`}
              />
              <StatCard
                label={t("dashboard.usersNew")}
                value={formatNumber(data.kpis.users_new)}
                changePct={data.kpis.users_new_change_pct}
              />
              <StatCard
                label={t("dashboard.gmv")}
                value={`$${data.kpis.gmv}`}
                changePct={data.kpis.gmv_change_pct}
                accent
              />
              <StatCard
                label={t("dashboard.churn")}
                value={`${data.kpis.churn_rate}%`}
                hint={t("dashboard.churnHint", { n: data.kpis.churned_users_30d })}
              />
              <StatCard
                label={t("dashboard.usersTotal")}
                value={formatNumber(data.kpis.users_total)}
              />
              <StatCard
                label={t("dashboard.subsActive")}
                value={formatNumber(data.kpis.subscriptions_active)}
              />
              <StatCard
                label={t("dashboard.messagesTotal")}
                value={`${data.legacy.messages_total_approx ? "≈ " : ""}${formatNumber(data.legacy.messages_total)}`}
                hint={`${t("dashboard.chatsTotal")}: ${formatNumber(data.legacy.chats_total)}`}
              />
            </div>
          </section>

          <div className="grid gap-6 lg:grid-cols-2">
            {/* Attention inbox */}
            <section className="rounded-xl border bg-white p-5">
              <h2 className="text-sm font-semibold">{t("dashboard.inboxTitle")}</h2>
              <ul className="mt-4 divide-y">
                {(inboxOpen.length ? inboxOpen : data.inbox).map((item) => (
                  <li key={item.id}>
                    <Link
                      href={item.href}
                      className="flex items-center justify-between gap-3 py-2.5 text-sm hover:bg-zinc-50 -mx-2 px-2 rounded-lg"
                    >
                      <span className="min-w-0">
                        <span className="font-medium text-zinc-900">{inboxLabel(item.id)}</span>
                        {item.sla_breach > 0 ? (
                          <span className="ml-2 rounded bg-rose-50 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-rose-700">
                            {t("dashboard.inboxSla", { n: item.sla_breach })}
                          </span>
                        ) : null}
                      </span>
                      <span
                        className={`tabular-nums font-semibold ${item.count > 0 ? "text-amber-700" : "text-zinc-400"}`}
                      >
                        {formatNumber(item.count)}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
              {inboxOpen.length === 0 ? (
                <p className="mt-2 text-xs text-emerald-600">{t("dashboard.inboxEmpty")}</p>
              ) : null}
            </section>

            {/* Geography */}
            <section className="rounded-xl border bg-white p-5">
              <div className="flex items-baseline justify-between gap-2">
                <h2 className="text-sm font-semibold">{t("dashboard.geoTitle")}</h2>
                <span className="text-xs text-zinc-400">
                  {data.from} → {data.to}
                </span>
              </div>
              {data.geo.length === 0 ? (
                <p className="mt-6 text-sm text-zinc-500">{t("dashboard.geoEmpty")}</p>
              ) : (
                <ul className="mt-4 max-h-80 space-y-3 overflow-y-auto pr-1">
                  {data.geo.slice(0, 15).map((g) => (
                    <li key={g.country} className="text-sm">
                      <div className="mb-1 flex items-center justify-between gap-2">
                        <span className="font-medium">
                          {countryFlag(g.country)} {g.country}
                        </span>
                        <span className="tabular-nums text-zinc-600">
                          {formatNumber(g.users)} · ${g.revenue}
                        </span>
                      </div>
                      <div className="h-1.5 overflow-hidden rounded-full bg-zinc-100">
                        <div
                          className="h-full rounded-full bg-emerald-500/80"
                          style={{ width: `${Math.max(4, (g.users / maxGeoUsers) * 100)}%` }}
                        />
                      </div>
                    </li>
                  ))}
                </ul>
              )}
              <div className="mt-3 flex gap-4 text-[11px] uppercase tracking-wide text-zinc-400">
                <span>{t("dashboard.geoUsers")}</span>
                <span>{t("dashboard.geoRevenue")}</span>
              </div>
            </section>
          </div>

          {/* Trends */}
          <section className="rounded-xl border bg-white p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 className="text-sm font-semibold">{t("dashboard.trendsTitle")}</h2>
                {trend ? (
                  <p className="mt-1 text-xs text-zinc-500">
                    {metricLabels[metric]}:{" "}
                    <span className="font-semibold tabular-nums text-zinc-800">
                      {metric === "revenue" ? `$${trend.total}` : formatNumber(trend.total)}
                    </span>
                    <span
                      className={
                        trend.change_pct == null
                          ? "ml-2 text-zinc-400"
                          : trend.change_pct > 0
                            ? "ml-2 text-emerald-600"
                            : trend.change_pct < 0
                              ? "ml-2 text-rose-600"
                              : "ml-2 text-zinc-400"
                      }
                    >
                      {formatPct(trend.change_pct)} {t("dashboard.vsPrevious")}
                    </span>
                  </p>
                ) : null}
              </div>
              <select
                value={metric}
                onChange={(e) => setMetric(e.target.value as MetricKey)}
                className="rounded border px-2 py-1 text-xs"
              >
                <option value="users_new">{metricLabels.users_new}</option>
                <option value="revenue">{metricLabels.revenue}</option>
                <option value="payments">{metricLabels.payments}</option>
              </select>
            </div>
            <div className="mt-4 flex h-44 items-end gap-1 overflow-x-auto">
              {(trend?.points ?? []).map((p) => (
                <div key={p.date} className="flex min-w-[8px] flex-1 flex-col items-center gap-1">
                  <div
                    className="w-full rounded-t bg-emerald-500/80"
                    style={{ height: `${Math.max(4, (Number(p.value) / maxPoint) * 140)}px` }}
                    title={`${p.date}: ${p.value}`}
                  />
                </div>
              ))}
              {(trend?.points ?? []).length === 0 ? (
                <p className="text-sm text-zinc-500">{t("app.noData")}</p>
              ) : null}
            </div>
          </section>

          {/* Operator activity */}
          <section className="rounded-xl border bg-white p-5">
            <h2 className="text-sm font-semibold">{t("dashboard.opsTitle")}</h2>
            <div className="mt-4 grid gap-6 lg:grid-cols-3">
              <div className="lg:col-span-1">
                <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
                  {t("dashboard.opsSummary")}
                </h3>
                {data.ops_summary.length === 0 ? (
                  <p className="mt-3 text-sm text-zinc-500">{t("dashboard.opsEmpty")}</p>
                ) : (
                  <ul className="mt-3 space-y-3">
                    {data.ops_summary.map((row) => (
                      <li key={row.actor_name} className="rounded-lg border px-3 py-2 text-sm">
                        <p className="font-medium text-zinc-900">{row.actor_name}</p>
                        <p className="mt-1 flex flex-wrap gap-2 text-xs">
                          <span className="rounded bg-emerald-50 px-1.5 py-0.5 text-emerald-700">
                            {t("dashboard.opsApprove")}: {row.approve}
                          </span>
                          <span className="rounded bg-rose-50 px-1.5 py-0.5 text-rose-700">
                            {t("dashboard.opsReject")}: {row.reject}
                          </span>
                          {row.other > 0 ? (
                            <span className="rounded bg-zinc-100 px-1.5 py-0.5 text-zinc-600">
                              {t("dashboard.opsOther")}: {row.other}
                            </span>
                          ) : null}
                        </p>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
              <div className="lg:col-span-2">
                <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
                  {t("dashboard.opsFeed")}
                </h3>
                {data.ops_activity.length === 0 ? (
                  <p className="mt-3 text-sm text-zinc-500">{t("dashboard.opsEmpty")}</p>
                ) : (
                  <ul className="mt-3 max-h-72 divide-y overflow-y-auto">
                    {data.ops_activity.map((row) => (
                      <li key={row.id} className="flex flex-wrap items-start justify-between gap-2 py-2.5 text-sm">
                        <div className="min-w-0">
                          <p className="font-medium text-zinc-900">{row.actor_name}</p>
                          <p className="text-zinc-600">{auditActionLabel(row.action)}</p>
                          {row.target_type ? (
                            <p className="text-xs text-zinc-400">
                              {row.target_type}
                              {row.target_id ? ` #${row.target_id}` : ""}
                            </p>
                          ) : null}
                        </div>
                        <div className="text-right">
                          <span
                            className={
                              row.decision === "approve"
                                ? "rounded bg-emerald-50 px-1.5 py-0.5 text-xs font-medium text-emerald-700"
                                : row.decision === "reject"
                                  ? "rounded bg-rose-50 px-1.5 py-0.5 text-xs font-medium text-rose-700"
                                  : "rounded bg-zinc-100 px-1.5 py-0.5 text-xs font-medium text-zinc-600"
                            }
                          >
                            {row.decision === "approve"
                              ? t("dashboard.opsApprove")
                              : row.decision === "reject"
                                ? t("dashboard.opsReject")
                                : t("dashboard.opsOther")}
                          </span>
                          <p className="mt-1 text-xs text-zinc-400">{formatDate(row.at)}</p>
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
