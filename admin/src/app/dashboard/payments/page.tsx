"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatCard } from "@/components/admin/stat-card";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, planLabel, t } from "@/lib/i18n";
import { useEffect, useState } from "react";

type Payment = {
  id: number;
  user_id: number;
  status: string;
  kind: string;
  amount: string;
  currency: string;
  plan: string | null;
  paid_at: string | null;
  created_at: string;
};

export default function PaymentsPage() {
  const [status, setStatus] = useState("");
  const [plan, setPlan] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [items, setItems] = useState<Payment[]>([]);
  const [stats, setStats] = useState<{ revenue: string; payments_by_status: Record<string, number> } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);

  async function load() {
    try {
      const q = new URLSearchParams({ page: String(page), limit: "50" });
      if (status) q.set("status", status);
      if (plan) q.set("plan", plan);
      if (dateFrom) q.set("from", dateFrom);
      if (dateTo) q.set("to", dateTo);

      const statsQ = new URLSearchParams();
      if (dateFrom) statsQ.set("from", dateFrom);
      if (dateTo) statsQ.set("to", dateTo);

      const [list, st] = await Promise.all([
        apiFetch<{ items: Payment[]; total: number; has_more: boolean }>(
          `/api/v1/admin/payments?${q}`,
          {},
        ),
        apiFetch<{ revenue: string; payments_by_status: Record<string, number> }>(
          `/api/v1/admin/payments/stats?${statsQ}`,
          {},
        ),
      ]);
      setItems(list.items);
      setTotal(list.total);
      setHasMore(list.has_more);
      setStats(st);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  useEffect(() => {
    void load();
  }, [page, status, plan, dateFrom, dateTo]);

  return (
    <div className="space-y-6">
      <PageHeader title={t("payments.title")} subtitle={t("payments.subtitle")}>
        <select
          value={status}
          onChange={(e) => {
            setPage(1);
            setStatus(e.target.value);
          }}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value="">{t("payments.statusAll")}</option>
          <option value="succeeded">succeeded</option>
          <option value="pending">pending</option>
          <option value="needs_refund">needs_refund</option>
          <option value="failed">failed</option>
        </select>
        <select
          value={plan}
          onChange={(e) => {
            setPage(1);
            setPlan(e.target.value);
          }}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value="">{t("subscriptions.planAll")}</option>
          <option value="basic">{planLabel("basic")}</option>
          <option value="premium">{planLabel("premium")}</option>
          <option value="business">{planLabel("business")}</option>
        </select>
        <input
          type="date"
          value={dateFrom}
          onChange={(e) => {
            setPage(1);
            setDateFrom(e.target.value);
          }}
          className="rounded-lg border px-3 py-2 text-sm"
        />
        <input
          type="date"
          value={dateTo}
          onChange={(e) => {
            setPage(1);
            setDateTo(e.target.value);
          }}
          className="rounded-lg border px-3 py-2 text-sm"
        />
      </PageHeader>

      {stats ? (
        <div className="grid gap-4 sm:grid-cols-3">
          <StatCard label={t("payments.revenue")} value={`$${stats.revenue}`} accent />
          {Object.entries(stats.payments_by_status).slice(0, 2).map(([k, v]) => (
            <StatCard key={k} label={k} value={v} />
          ))}
        </div>
      ) : null}

      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="overflow-hidden rounded-xl border bg-white">
        <table className="min-w-full text-sm">
          <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3 text-left">{t("payments.colId")}</th>
              <th className="px-4 py-3 text-left">{t("payments.colUser")}</th>
              <th className="px-4 py-3 text-left">{t("payments.colKind")}</th>
              <th className="px-4 py-3 text-left">{t("payments.colAmount")}</th>
              <th className="px-4 py-3 text-left">{t("payments.colStatus")}</th>
              <th className="px-4 py-3 text-left">{t("payments.colCreated")}</th>
            </tr>
          </thead>
          <tbody>
            {items.map((p) => (
              <tr key={p.id} className="border-t">
                <td className="px-4 py-2 tabular-nums">{p.id}</td>
                <td className="px-4 py-2">{p.user_id}</td>
                <td className="px-4 py-2">{p.kind}</td>
                <td className="px-4 py-2 font-medium">
                  {p.amount} {p.currency}
                </td>
                <td className="px-4 py-2">
                  <StatusBadge status={p.status} />
                </td>
                <td className="px-4 py-2 text-xs text-zinc-500">{formatDate(p.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!items.length ? <EmptyState /> : null}
        <Pagination page={page} total={total} hasMore={hasMore} onPageChange={setPage} />
      </div>
    </div>
  );
}
