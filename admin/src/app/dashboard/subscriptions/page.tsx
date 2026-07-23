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
  source?: string;
};

type ListResp = {
  items: Row[];
  total: number;
  has_more: boolean;
  page: number;
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
  const [plan, setPlan] = useState("");
  const [items, setItems] = useState<Row[]>([]);
  const [catalog, setCatalog] = useState<PlanCatalog[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [busyId, setBusyId] = useState<number | null>(null);

  async function loadCatalog() {
    try {
      const res = await apiFetch<{ plans: PlanCatalog[] }>(
        "/api/v1/admin/plan-catalog?language=uz_UZ",
      );
      setCatalog(res.plans ?? []);
    } catch {
      // Catalog is informational; list still works.
    }
  }

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
    void loadCatalog();
  }, []);

  useEffect(() => {
    void load();
  }, [plan, page]);

  async function patchSub(userId: number, body: object) {
    setBusyId(userId);
    setError(null);
    setToast(null);
    try {
      await apiFetch(`/api/v1/admin/subscriptions/${userId}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      setToast(t("app.success"));
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
      billing_cycle: "monthly",
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

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

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
        {!items.length ? <EmptyState /> : null}
        <Pagination page={page} total={total} hasMore={hasMore} onPageChange={setPage} />
      </div>
    </div>
  );
}
