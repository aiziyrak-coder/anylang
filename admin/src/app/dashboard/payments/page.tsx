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
  const list = useAdminList<
    Payment,
    { status: string; plan: string; kind: string; from: string; to: string }
  >({
    queryKey: "admin-payments",
    path: "/api/v1/admin/payments",
    defaultSort: "id",
    initialFilters: { status: "", plan: "", kind: "", from: "", to: "" },
  });

  const [stats, setStats] = useState<{
    revenue: string;
    payments_by_status: Record<string, number>;
  } | null>(null);
  const [statsError, setStatsError] = useState<string | null>(null);

  useEffect(() => {
    const q = new URLSearchParams();
    if (list.filters.from) q.set("from", list.filters.from);
    if (list.filters.to) q.set("to", list.filters.to);
    apiFetch<{ revenue: string; payments_by_status: Record<string, number> }>(
      `/api/v1/admin/payments/stats?${q}`,
    )
      .then(setStats)
      .catch((err) =>
        setStatsError(err instanceof ApiError ? err.message : t("app.error")),
      );
  }, [list.filters.from, list.filters.to]);

  return (
    <div className="space-y-6">
      <PageHeader title={t("payments.title")} subtitle={t("payments.subtitle")}>
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
                <option value="needs_refund">needs_refund</option>
                <option value="failed">failed</option>
              </select>
              <select
                value={list.filters.kind}
                onChange={(e) => list.setFilter("kind", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("payments.colKind")}: {t("app.all")}</option>
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
                <option value="basic">{planLabel("basic")}</option>
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
      </PageHeader>

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

      {statsError ? <Alert variant="error">{statsError}</Alert> : null}

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
              </tr>
            </thead>
            <tbody>
              {list.items.map((p) => (
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
                  <td className="px-4 py-2 text-xs text-zinc-500">
                    {formatDate(p.created_at)}
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
    </div>
  );
}
