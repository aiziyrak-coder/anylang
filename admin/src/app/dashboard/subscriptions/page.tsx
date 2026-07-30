"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, planLabel, t } from "@/lib/i18n";
import { useEffect, useState } from "react";

type Row = {
  user_id: number;
  email: string;
  full_name: string;
  number: string;
  plan: string;
  billing_cycle: string | null;
  expires_at: string | null;
  auto_renew: boolean;
  is_active: boolean;
  source?: string;
};

type PlanFeature = { text: string; included: boolean };
type PlanCatalog = {
  code: string;
  title: string;
  is_free: boolean;
  monthly_price: string | null;
  yearly_price: string | null;
  yearly_total: string | null;
  savings_percent: number | null;
  currency: string;
  badge: string | null;
  features: PlanFeature[];
};

export default function SubscriptionsPage() {
  const list = useAdminList<Row, { plan: string }>({
    queryKey: "admin-subscriptions",
    path: "/api/v1/admin/subscriptions",
    defaultSort: "id",
    initialFilters: { plan: "" },
  });

  const [catalog, setCatalog] = useState<PlanCatalog[]>([]);
  const [actionError, setActionError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  useEffect(() => {
    apiFetch<{ plans: PlanCatalog[] }>("/api/v1/admin/plan-catalog?language=uz_UZ")
      .then((res) => setCatalog(res.plans ?? []))
      .catch(() => {
        // Catalog is informational; list still works.
      });
  }, []);

  async function patchSub(userId: number, body: object) {
    setBusyId(userId);
    setActionError(null);
    setToast(null);
    try {
      await apiFetch(`/api/v1/admin/subscriptions/${userId}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      setToast(t("app.success"));
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function grantPlan(userId: number, nextPlan: string) {
    if (nextPlan === "basic") {
      await patchSub(userId, {
        plan: "basic",
        is_active: true,
        auto_renew: false,
      });
      return;
    }
    const expires = new Date();
    expires.setDate(expires.getDate() + 30);
    await patchSub(userId, {
      plan: nextPlan,
      billing_cycle: "1",
      expires_at: expires.toISOString(),
      is_active: true,
      auto_renew: false,
    });
  }

  async function extend30(userId: number, current: string | null) {
    const base = current ? new Date(current) : new Date();
    if (base < new Date()) base.setTime(Date.now());
    base.setDate(base.getDate() + 30);
    await patchSub(userId, { expires_at: base.toISOString(), is_active: true });
  }

  async function stopRenew(userId: number) {
    await patchSub(userId, { auto_renew: false });
  }

  async function revokeNow(userId: number) {
    await patchSub(userId, {
      plan: "basic",
      is_active: true,
      auto_renew: false,
    });
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("subscriptions.title")} subtitle={t("subscriptions.subtitle")}>
        <DataToolbar
          search={{
            value: list.q,
            onChange: list.setQ,
            placeholder: t("users.searchPlaceholder"),
          }}
          showClear={list.hasActiveFilters}
          onClear={list.clearFilters}
          filters={
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
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      {catalog.length > 0 ? (
        <div className="grid gap-3 md:grid-cols-3">
          {catalog.map((p) => (
            <div key={p.code} className="rounded-xl border bg-white p-4">
              <div className="flex items-center justify-between gap-2">
                <h3 className="font-semibold">{p.title}</h3>
                {p.badge ? (
                  <span className="rounded bg-zinc-100 px-2 py-0.5 text-[10px] uppercase text-zinc-600">
                    {p.badge}
                  </span>
                ) : null}
              </div>
              <p className="mt-2 text-sm text-zinc-600">
                {p.is_free
                  ? t("subscriptions.catalogFree")
                  : t("subscriptions.catalogPrice", {
                      monthly: p.monthly_price ?? "—",
                      yearly: p.yearly_price ?? "—",
                    })}
              </p>
              {p.yearly_total ? (
                <p className="mt-1 text-xs text-zinc-500">
                  {t("subscriptions.catalogYearlyTotal", { total: p.yearly_total })}
                </p>
              ) : null}
              <ul className="mt-3 space-y-1 text-xs text-zinc-600">
                {p.features.map((f) => (
                  <li key={f.text}>
                    {f.included ? "✓" : "✗"} {f.text}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      ) : null}

      <p className="text-xs text-zinc-500">{t("subscriptions.semanticsHint")}</p>

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
                <th className="px-4 py-3 text-left">{t("subscriptions.colUser")}</th>
                <SortableTh
                  label={t("subscriptions.colPlan")}
                  sortKey="plan"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                  className="text-left"
                />
                <th className="px-4 py-3 text-left">{t("subscriptions.colActive")}</th>
                <SortableTh
                  label={t("subscriptions.colExpires")}
                  sortKey="expires_at"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                  className="text-left"
                />
                <th className="px-4 py-3 text-left">{t("subscriptions.colAutoRenew")}</th>
                <th className="px-4 py-3 text-left">{t("app.actions")}</th>
              </tr>
            </thead>
            <tbody>
              {list.items.map((r) => (
                <tr key={r.user_id} className="border-t">
                  <td className="px-4 py-2">
                    <div className="font-medium">{r.full_name}</div>
                    <div className="text-xs text-zinc-500">
                      {r.email} · {r.number}
                      {r.source ? ` · ${r.source}` : ""}
                    </div>
                  </td>
                  <td className="px-4 py-2">
                    <select
                      value={r.plan}
                      disabled={busyId === r.user_id}
                      onChange={(e) => grantPlan(r.user_id, e.target.value)}
                      className="rounded border px-2 py-1 text-xs"
                    >
                      <option value="basic">{planLabel("basic")}</option>
                      <option value="premium">{planLabel("premium")}</option>
                      <option value="business">{planLabel("business")}</option>
                    </select>
                  </td>
                  <td className="px-4 py-2">
                    <StatusBadge status={r.is_active ? "active" : "inactive"} />
                  </td>
                  <td className="px-4 py-2 text-xs">{formatDate(r.expires_at)}</td>
                  <td className="px-4 py-2">
                    <button
                      type="button"
                      disabled={busyId === r.user_id}
                      onClick={() =>
                        patchSub(r.user_id, { auto_renew: !r.auto_renew })
                      }
                      className="rounded border px-2 py-0.5 text-xs"
                    >
                      {r.auto_renew ? t("app.yes") : t("app.no")}
                    </button>
                  </td>
                  <td className="px-4 py-2">
                    <div className="flex flex-wrap gap-1">
                      <button
                        type="button"
                        disabled={busyId === r.user_id}
                        onClick={() => extend30(r.user_id, r.expires_at)}
                        className="rounded border px-2 py-1 text-xs"
                      >
                        {t("subscriptions.extend30")}
                      </button>
                      {r.auto_renew ? (
                        <button
                          type="button"
                          disabled={busyId === r.user_id}
                          onClick={() => stopRenew(r.user_id)}
                          className="rounded border px-2 py-1 text-xs"
                        >
                          {t("subscriptions.stopRenew")}
                        </button>
                      ) : null}
                      {r.plan !== "basic" ? (
                        <button
                          type="button"
                          disabled={busyId === r.user_id}
                          onClick={() => revokeNow(r.user_id)}
                          className="rounded border border-red-200 px-2 py-1 text-xs text-red-700"
                        >
                          {t("subscriptions.revokeNow")}
                        </button>
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
    </div>
  );
}
