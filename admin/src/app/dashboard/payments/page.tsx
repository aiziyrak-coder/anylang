"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { StatCard } from "@/components/admin/stat-card";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, formatNumber, planLabel, t } from "@/lib/i18n";
import { useCallback, useEffect, useState } from "react";

type Payment = {
  id: number;
  user_id: number;
  status: string;
  provider: string;
  kind: string;
  amount: string;
  currency: string;
  plan: string | null;
  paid_at: string | null;
  created_at: string;
  amount_usd?: string | null;
  usd_uzs_rate?: string | null;
  refund_reason?: string | null;
  chargeback_reason?: string | null;
  email?: string | null;
  failed_notified_at?: string | null;
};

type Hub = {
  funnel: {
    days: number;
    providers: {
      provider: string;
      total: number;
      succeeded: number;
      failed: number;
      pending: number;
      refunded: number;
      chargeback: number;
      needs_refund: number;
      success_rate: number;
      fail_rate: number;
    }[];
  };
  fx: {
    days: number;
    live_rate: {
      usd_uzs_rate: string;
      fx_source: string;
      fx_date: string | null;
    };
    succeeded_count: number;
    usd_total: number;
    uzs_total: number;
    by_currency: Record<string, number>;
    daily: { date: string; usd: number; uzs: number; count: number }[];
  };
  suspicious: {
    hours: number;
    min_attempts: number;
    count: number;
    alerts: {
      user_id: number;
      email: string;
      attempts: number;
      failed: number;
      pending: number;
      succeeded: number;
      amount_sum: number;
      last_at: string | null;
      severity: string;
    }[];
  };
  failed: { items: Payment[]; total: number };
  refunds: {
    items: Payment[];
    reason_catalog: { refund: string[]; chargeback: string[] };
  };
};

type Tab = "list" | "funnel" | "refund" | "failed" | "fx" | "suspicious";

const TABS: { id: Tab; key: string }[] = [
  { id: "list", key: "payments.tabList" },
  { id: "funnel", key: "payments.tabFunnel" },
  { id: "refund", key: "payments.tabRefund" },
  { id: "failed", key: "payments.tabFailed" },
  { id: "fx", key: "payments.tabFx" },
  { id: "suspicious", key: "payments.tabSuspicious" },
];

export default function PaymentsPage() {
  const list = useAdminList<
    Payment,
    { status: string; plan: string; kind: string; provider: string; from: string; to: string }
  >({
    queryKey: "admin-payments",
    path: "/api/v1/admin/payments",
    defaultSort: "id",
    initialFilters: {
      status: "",
      plan: "",
      kind: "",
      provider: "",
      from: "",
      to: "",
    },
  });

  const [tab, setTab] = useState<Tab>("list");
  const [hubDays, setHubDays] = useState(30);
  const [hub, setHub] = useState<Hub | null>(null);
  const [hubLoading, setHubLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [reason, setReason] = useState("other");
  const [note, setNote] = useState("");

  const [stats, setStats] = useState<{
    revenue: string;
    payments_by_status: Record<string, number>;
  } | null>(null);

  const loadHub = useCallback(async () => {
    setHubLoading(true);
    setError(null);
    try {
      const data = await apiFetch<Hub>(`/api/v1/admin/payments/hub?days=${hubDays}`);
      setHub(data);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setHubLoading(false);
    }
  }, [hubDays]);

  useEffect(() => {
    if (tab !== "list") void loadHub();
  }, [tab, loadHub]);

  useEffect(() => {
    const q = new URLSearchParams();
    if (list.filters.from) q.set("from", list.filters.from);
    if (list.filters.to) q.set("to", list.filters.to);
    apiFetch<{ revenue: string; payments_by_status: Record<string, number> }>(
      `/api/v1/admin/payments/stats?${q}`
    )
      .then(setStats)
      .catch(() => setStats(null));
  }, [list.filters.from, list.filters.to]);

  async function doRefund(id: number, kind: "refund" | "chargeback") {
    setBusyId(id);
    setError(null);
    setToast(null);
    try {
      await apiFetch(`/api/v1/admin/payments/${id}/${kind}`, {
        method: "POST",
        body: JSON.stringify({ reason, note: note || null }),
      });
      setToast(
        kind === "refund"
          ? t("payments.refundOk", { id })
          : t("payments.chargebackOk", { id })
      );
      await loadHub();
      await list.refetch();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function doTriage(id: number, action: "retry" | "notify" | "dismiss") {
    setBusyId(id);
    setError(null);
    setToast(null);
    try {
      await apiFetch(`/api/v1/admin/payments/${id}/triage`, {
        method: "POST",
        body: JSON.stringify({ action, note: note || null }),
      });
      setToast(t("payments.triageOk", { action }));
      await loadHub();
      await list.refetch();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("payments.title")} subtitle={t("payments.subtitle")}>
        <div className="flex flex-wrap items-center gap-2">
          <label className="text-xs text-zinc-500">{t("payments.days")}</label>
          <select
            value={hubDays}
            onChange={(e) => setHubDays(Number(e.target.value))}
            className="rounded-lg border px-2 py-1.5 text-sm"
          >
            <option value={7}>7</option>
            <option value={30}>30</option>
            <option value={90}>90</option>
          </select>
          {tab !== "list" ? (
            <button
              type="button"
              onClick={() => void loadHub()}
              className="rounded-lg border px-3 py-1.5 text-sm hover:bg-zinc-50"
            >
              {t("payments.reload")}
            </button>
          ) : null}
        </div>
      </PageHeader>

      <div className="flex flex-wrap gap-1 border-b pb-2">
        {TABS.map((tb) => (
          <button
            key={tb.id}
            type="button"
            onClick={() => setTab(tb.id)}
            className={`rounded-lg px-3 py-1.5 text-sm ${
              tab === tb.id ? "bg-zinc-900 text-white" : "text-zinc-600 hover:bg-zinc-100"
            }`}
          >
            {t(tb.key)}
          </button>
        ))}
      </div>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {toast ? <Alert variant="success">{toast}</Alert> : null}

      {tab === "list" ? (
        <>
          <DataToolbar
            search={{
              value: list.q,
              onChange: list.setQ,
              placeholder: t("app.search"),
            }}
            showClear={list.hasActiveFilters}
            onClear={list.clearFilters}
            filters={
              <>
                <select
                  value={list.filters.status}
                  onChange={(e) => list.setFilter("status", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                >
                  <option value="">{t("payments.statusAll")}</option>
                  <option value="succeeded">succeeded</option>
                  <option value="pending">pending</option>
                  <option value="failed">failed</option>
                  <option value="needs_refund">needs_refund</option>
                  <option value="refunded">refunded</option>
                  <option value="chargeback">chargeback</option>
                  <option value="cancelled">cancelled</option>
                </select>
                <select
                  value={list.filters.provider}
                  onChange={(e) => list.setFilter("provider", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                >
                  <option value="">{t("payments.providerAll")}</option>
                  <option value="click">click</option>
                  <option value="paddle">paddle</option>
                  <option value="mock">mock</option>
                  <option value="stripe">stripe</option>
                </select>
                <select
                  value={list.filters.kind}
                  onChange={(e) => list.setFilter("kind", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                >
                  <option value="">
                    {t("payments.colKind")}: {t("app.all")}
                  </option>
                  <option value="subscription">subscription</option>
                  <option value="number">number</option>
                  <option value="product_top">product_top</option>
                </select>
                <select
                  value={list.filters.plan}
                  onChange={(e) => list.setFilter("plan", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                >
                  <option value="">{t("subscriptions.planAll")}</option>
                  <option value="premium">{planLabel("premium")}</option>
                  <option value="business">{planLabel("business")}</option>
                </select>
                <input
                  type="date"
                  value={list.filters.from}
                  onChange={(e) => list.setFilter("from", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                />
                <input
                  type="date"
                  value={list.filters.to}
                  onChange={(e) => list.setFilter("to", e.target.value)}
                  className="rounded-lg border px-3 py-2 text-sm"
                />
              </>
            }
          />

          {stats ? (
            <div className="grid gap-4 sm:grid-cols-3">
              <StatCard label={t("payments.revenue")} value={`$${stats.revenue}`} accent />
              {Object.entries(stats.payments_by_status)
                .slice(0, 2)
                .map(([k, v]) => (
                  <StatCard key={k} label={k} value={v} />
                ))}
            </div>
          ) : null}

          <div className="overflow-hidden rounded-xl border bg-white">
            <ListState
              isLoading={list.isLoading}
              error={list.error}
              isEmpty={list.items.length === 0}
              hasActiveFilters={list.hasActiveFilters}
              onClearFilters={list.clearFilters}
              onRetry={() => void list.refetch()}
            >
              <table className="min-w-full text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <SortableTh
                      label={t("payments.colId")}
                      sortKey="id"
                      sortBy={list.sort}
                      sortDir={list.order}
                      onSort={list.toggleSort}
                    />
                    <th className="px-4 py-3 text-left">{t("payments.colUser")}</th>
                    <th className="px-4 py-3 text-left">{t("payments.colProvider")}</th>
                    <th className="px-4 py-3 text-left">{t("payments.colKind")}</th>
                    <SortableTh
                      label={t("payments.colAmount")}
                      sortKey="amount"
                      sortBy={list.sort}
                      sortDir={list.order}
                      onSort={list.toggleSort}
                    />
                    <SortableTh
                      label={t("payments.colStatus")}
                      sortKey="status"
                      sortBy={list.sort}
                      sortDir={list.order}
                      onSort={list.toggleSort}
                    />
                    <SortableTh
                      label={t("payments.colCreated")}
                      sortKey="created_at"
                      sortBy={list.sort}
                      sortDir={list.order}
                      onSort={list.toggleSort}
                    />
                    <th className="px-4 py-3 text-left">{t("app.actions")}</th>
                  </tr>
                </thead>
                <tbody>
                  {list.items.map((p) => (
                    <tr key={p.id} className="border-t">
                      <td className="px-4 py-2 tabular-nums">{p.id}</td>
                      <td className="px-4 py-2">{p.user_id}</td>
                      <td className="px-4 py-2">{p.provider}</td>
                      <td className="px-4 py-2">{p.kind}</td>
                      <td className="px-4 py-2 font-medium">
                        {p.amount} {p.currency}
                        {p.amount_usd ? (
                          <span className="ml-1 text-xs text-zinc-500">(${p.amount_usd})</span>
                        ) : null}
                      </td>
                      <td className="px-4 py-2">
                        <StatusBadge status={p.status} />
                      </td>
                      <td className="px-4 py-2 text-xs text-zinc-500">
                        {formatDate(p.created_at)}
                      </td>
                      <td className="px-4 py-2">
                        <div className="flex flex-wrap gap-1">
                          {p.status === "succeeded" || p.status === "needs_refund" ? (
                            <>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-violet-700"
                                onClick={() => void doRefund(p.id, "refund")}
                              >
                                {t("payments.markRefund")}
                              </button>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-red-700"
                                onClick={() => void doRefund(p.id, "chargeback")}
                              >
                                {t("payments.markChargeback")}
                              </button>
                            </>
                          ) : null}
                          {p.status === "failed" || p.status === "cancelled" ? (
                            <>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-emerald-700"
                                onClick={() => void doTriage(p.id, "retry")}
                              >
                                {t("payments.retry")}
                              </button>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-sky-700"
                                onClick={() => void doTriage(p.id, "notify")}
                              >
                                {t("payments.notify")}
                              </button>
                            </>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <Pagination
                page={list.page}
                total={list.total}
                hasMore={list.hasMore}
                onPageChange={list.setPage}
                limit={list.limit}
                onLimitChange={list.setLimit}
              />
            </ListState>
          </div>
        </>
      ) : null}

      {tab !== "list" && hubLoading && !hub ? (
        <p className="text-sm text-zinc-500">{t("app.loading")}</p>
      ) : null}

      {tab === "funnel" && hub ? (
        <div className="grid gap-3 md:grid-cols-3">
          {hub.funnel.providers.length === 0 ? (
            <p className="text-sm text-zinc-500">{t("payments.noData")}</p>
          ) : (
            hub.funnel.providers.map((p) => (
              <div key={p.provider} className="rounded-xl border bg-white p-4">
                <h3 className="text-lg font-semibold uppercase">{p.provider}</h3>
                <p className="mt-1 text-2xl font-bold text-emerald-700">
                  {p.success_rate}%{" "}
                  <span className="text-sm font-normal text-zinc-500">
                    {t("payments.successRate")}
                  </span>
                </p>
                <dl className="mt-3 grid grid-cols-2 gap-2 text-sm">
                  <div>
                    <dt className="text-zinc-500">{t("payments.total")}</dt>
                    <dd>{p.total}</dd>
                  </div>
                  <div>
                    <dt className="text-zinc-500">{t("payments.succeeded")}</dt>
                    <dd>{p.succeeded}</dd>
                  </div>
                  <div>
                    <dt className="text-zinc-500">{t("payments.failed")}</dt>
                    <dd>{p.failed}</dd>
                  </div>
                  <div>
                    <dt className="text-zinc-500">{t("payments.pending")}</dt>
                    <dd>{p.pending}</dd>
                  </div>
                  <div>
                    <dt className="text-zinc-500">{t("payments.refunded")}</dt>
                    <dd>{p.refunded}</dd>
                  </div>
                  <div>
                    <dt className="text-zinc-500">{t("payments.chargeback")}</dt>
                    <dd>{p.chargeback}</dd>
                  </div>
                </dl>
              </div>
            ))
          )}
        </div>
      ) : null}

      {(tab === "refund" || tab === "failed") && hub ? (
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2 rounded-xl border bg-white p-3">
            <label className="text-xs text-zinc-500">
              {t("payments.reason")}
              <select
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="ml-2 rounded border px-2 py-1 text-sm"
              >
                {(tab === "refund"
                  ? hub.refunds.reason_catalog.refund
                  : ["retry", "user_abandon", "other"]
                ).map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </select>
            </label>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={t("payments.note")}
              className="min-w-[200px] flex-1 rounded border px-3 py-1.5 text-sm"
            />
          </div>
          <div className="overflow-hidden rounded-xl border bg-white">
            {(tab === "refund" ? hub.refunds.items : hub.failed.items).length === 0 ? (
              <p className="p-6 text-sm text-zinc-500">{t("payments.noData")}</p>
            ) : (
              <table className="min-w-full text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <th className="px-4 py-2 text-left">ID</th>
                    <th className="px-4 py-2 text-left">{t("payments.colUser")}</th>
                    <th className="px-4 py-2 text-left">{t("payments.colProvider")}</th>
                    <th className="px-4 py-2 text-left">{t("payments.colAmount")}</th>
                    <th className="px-4 py-2 text-left">{t("payments.colStatus")}</th>
                    <th className="px-4 py-2 text-left">{t("app.actions")}</th>
                  </tr>
                </thead>
                <tbody>
                  {(tab === "refund" ? hub.refunds.items : hub.failed.items).map((p) => (
                    <tr key={p.id} className="border-t">
                      <td className="px-4 py-2">{p.id}</td>
                      <td className="px-4 py-2">
                        #{p.user_id}
                        <div className="text-xs text-zinc-500">{p.email}</div>
                      </td>
                      <td className="px-4 py-2">{p.provider}</td>
                      <td className="px-4 py-2">
                        {p.amount} {p.currency}
                      </td>
                      <td className="px-4 py-2">
                        <StatusBadge status={p.status} />
                        {p.refund_reason || p.chargeback_reason ? (
                          <div className="text-xs text-zinc-500">
                            {p.refund_reason || p.chargeback_reason}
                          </div>
                        ) : null}
                      </td>
                      <td className="px-4 py-2">
                        <div className="flex flex-wrap gap-2">
                          {tab === "refund" &&
                          (p.status === "succeeded" || p.status === "needs_refund") ? (
                            <>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-violet-700"
                                onClick={() => void doRefund(p.id, "refund")}
                              >
                                {t("payments.markRefund")}
                              </button>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-red-700"
                                onClick={() => void doRefund(p.id, "chargeback")}
                              >
                                {t("payments.markChargeback")}
                              </button>
                            </>
                          ) : null}
                          {tab === "failed" ? (
                            <>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-emerald-700"
                                onClick={() => void doTriage(p.id, "retry")}
                              >
                                {t("payments.retry")}
                              </button>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-sky-700"
                                onClick={() => void doTriage(p.id, "notify")}
                              >
                                {t("payments.notify")}
                              </button>
                              <button
                                type="button"
                                disabled={busyId === p.id}
                                className="text-xs text-zinc-600"
                                onClick={() => void doTriage(p.id, "dismiss")}
                              >
                                {t("payments.dismiss")}
                              </button>
                            </>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      ) : null}

      {tab === "fx" && hub ? (
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-4">
            <StatCard
              label={t("payments.liveRate")}
              value={hub.fx.live_rate.usd_uzs_rate}
              accent
            />
            <StatCard label={t("payments.usdTotal")} value={`$${formatNumber(hub.fx.usd_total)}`} />
            <StatCard label={t("payments.uzsTotal")} value={formatNumber(hub.fx.uzs_total)} />
            <StatCard label="Tx" value={hub.fx.succeeded_count} />
          </div>
          <p className="text-xs text-zinc-500">
            source: {hub.fx.live_rate.fx_source}
            {hub.fx.live_rate.fx_date ? ` · ${hub.fx.live_rate.fx_date}` : ""}
          </p>
          <div className="overflow-hidden rounded-xl border bg-white">
            {hub.fx.daily.length === 0 ? (
              <p className="p-6 text-sm text-zinc-500">{t("payments.noData")}</p>
            ) : (
              <table className="min-w-full text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <th className="px-4 py-2 text-left">Date</th>
                    <th className="px-4 py-2 text-left">USD</th>
                    <th className="px-4 py-2 text-left">UZS</th>
                    <th className="px-4 py-2 text-left">Count</th>
                  </tr>
                </thead>
                <tbody>
                  {hub.fx.daily.map((d) => (
                    <tr key={d.date} className="border-t">
                      <td className="px-4 py-2">{d.date}</td>
                      <td className="px-4 py-2">${formatNumber(Math.round(d.usd * 100) / 100)}</td>
                      <td className="px-4 py-2">{formatNumber(Math.round(d.uzs))}</td>
                      <td className="px-4 py-2">{d.count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      ) : null}

      {tab === "suspicious" && hub ? (
        <div className="overflow-hidden rounded-xl border bg-white">
          <div className="border-b px-4 py-3 text-sm text-zinc-600">
            {hub.suspicious.hours}h · min {hub.suspicious.min_attempts} attempts ·{" "}
            {hub.suspicious.count} alerts
          </div>
          {hub.suspicious.alerts.length === 0 ? (
            <p className="p-6 text-sm text-zinc-500">{t("payments.noData")}</p>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                <tr>
                  <th className="px-4 py-2 text-left">{t("payments.colUser")}</th>
                  <th className="px-4 py-2 text-left">{t("payments.attempts")}</th>
                  <th className="px-4 py-2 text-left">{t("payments.failed")}</th>
                  <th className="px-4 py-2 text-left">{t("payments.succeeded")}</th>
                  <th className="px-4 py-2 text-left">{t("payments.colAmount")}</th>
                  <th className="px-4 py-2 text-left">{t("payments.severity")}</th>
                </tr>
              </thead>
              <tbody>
                {hub.suspicious.alerts.map((a) => (
                  <tr key={a.user_id} className="border-t">
                    <td className="px-4 py-2">
                      #{a.user_id}
                      <div className="text-xs text-zinc-500">{a.email}</div>
                    </td>
                    <td className="px-4 py-2 font-semibold">{a.attempts}</td>
                    <td className="px-4 py-2">{a.failed}</td>
                    <td className="px-4 py-2">{a.succeeded}</td>
                    <td className="px-4 py-2">{formatNumber(a.amount_sum)}</td>
                    <td className="px-4 py-2">
                      <span
                        className={
                          a.severity === "high"
                            ? "rounded bg-red-100 px-2 py-0.5 text-xs text-red-800"
                            : "rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-900"
                        }
                      >
                        {a.severity}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ) : null}
    </div>
  );
}
