"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
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
};

type ListResp = {
  items: Row[];
  total: number;
  has_more: boolean;
  page: number;
};

export default function SubscriptionsPage() {
  const [plan, setPlan] = useState("");
  const [items, setItems] = useState<Row[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [busyId, setBusyId] = useState<number | null>(null);

  async function load() {
    try {
      const q = new URLSearchParams({ limit: "50", page: String(page) });
      if (plan) q.set("plan", plan);
      const res = await apiFetch<ListResp>(`/api/v1/admin/subscriptions?${q}`);
      setItems(res.items);
      setTotal(res.total ?? res.items.length);
      setHasMore(res.has_more ?? false);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  useEffect(() => {
    void load();
  }, [plan, page]);

  async function patchSub(userId: number, body: object) {
    setBusyId(userId);
    try {
      await apiFetch(`/api/v1/admin/subscriptions/${userId}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function extend30(userId: number, current: string | null) {
    const base = current ? new Date(current) : new Date();
    if (base < new Date()) base.setTime(Date.now());
    base.setDate(base.getDate() + 30);
    await patchSub(userId, { expires_at: base.toISOString(), is_active: true });
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("subscriptions.title")} subtitle={t("subscriptions.subtitle")}>
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
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="overflow-hidden rounded-xl border bg-white">
        <table className="min-w-full text-sm">
          <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3 text-left">{t("subscriptions.colUser")}</th>
              <th className="px-4 py-3 text-left">{t("subscriptions.colPlan")}</th>
              <th className="px-4 py-3 text-left">{t("subscriptions.colActive")}</th>
              <th className="px-4 py-3 text-left">{t("subscriptions.colExpires")}</th>
              <th className="px-4 py-3 text-left">{t("subscriptions.colAutoRenew")}</th>
              <th className="px-4 py-3 text-left">{t("app.actions")}</th>
            </tr>
          </thead>
          <tbody>
            {items.map((r) => (
              <tr key={r.user_id} className="border-t">
                <td className="px-4 py-2">
                  <div className="font-medium">{r.full_name}</div>
                  <div className="text-xs text-zinc-500">
                    {r.email} · {r.number}
                  </div>
                </td>
                <td className="px-4 py-2">
                  <select
                    defaultValue={r.plan}
                    disabled={busyId === r.user_id}
                    onChange={(e) => patchSub(r.user_id, { plan: e.target.value, is_active: true })}
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
                    onClick={() => patchSub(r.user_id, { auto_renew: !r.auto_renew })}
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
                    <button
                      type="button"
                      disabled={busyId === r.user_id}
                      onClick={() => patchSub(r.user_id, { is_active: !r.is_active })}
                      className="rounded border px-2 py-1 text-xs"
                    >
                      {r.is_active ? t("subscriptions.cancel") : t("subscriptions.activate")}
                    </button>
                  </div>
                </td>
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
