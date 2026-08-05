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
import { formatDate, formatNumber, planLabel, t } from "@/lib/i18n";
import { useCallback, useEffect, useState } from "react";

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

type PlanSetting = {
  plan_code: string;
  monthly_usd: string | null;
  trial_days: number;
  limits: Record<string, unknown>;
  region_currency: Record<string, string>;
  features_override: Record<string, unknown>;
  updated_at: string | null;
};

type Policy = {
  grace_days: number;
  soft_lock_enabled: boolean;
  reminder_days: number[];
  churn_reasons: string[];
  soft_lock_message: Record<string, string>;
  updated_at: string | null;
};

type Hub = {
  plans: PlanSetting[];
  policy: Policy;
  cohort: {
    days: number;
    transitions: { from_to: string; count: number }[];
    upgrades: number;
    downgrades: number;
    churn_total: number;
    churn_reasons: { reason: string; count: number }[];
    active_by_plan: Record<string, number>;
  };
  grants: {
    items: {
      id: number;
      created_at: string | null;
      admin_email: string | null;
      admin_name: string | null;
      user_id: number | null;
      from_plan: string | null;
      to_plan: string | null;
      expires_at: string | null;
      churn_reason: string | null;
      note: string | null;
    }[];
  };
  reminders: {
    reminder_days: number[];
    counts: Record<string, number>;
    items: {
      user_id: number;
      email: string;
      full_name: string;
      plan: string;
      expires_at: string;
      days_left: number;
      reminder_bucket: number | null;
      auto_renew: boolean;
    }[];
  };
  ltv: {
    days: number;
    plans: Record<
      string,
      {
        active_subscribers: number;
        paying_users: number;
        transactions: number;
        revenue: number;
        arpu_window: number;
        ltv_window: number;
        ltv_estimated: number;
        avg_tenure_months: number;
        catalog_monthly_usd: number;
      }
    >;
    delta: {
      ltv_window: number;
      arpu_window: number;
      revenue: number;
      active_subscribers: number;
      winner: string;
    };
  };
};

type Tab =
  | "users"
  | "editor"
  | "cohort"
  | "grants"
  | "reminders"
  | "policy"
  | "ltv";

const TABS: { id: Tab; labelKey: string }[] = [
  { id: "users", labelKey: "subscriptions.tabUsers" },
  { id: "editor", labelKey: "subscriptions.tabEditor" },
  { id: "cohort", labelKey: "subscriptions.tabCohort" },
  { id: "grants", labelKey: "subscriptions.tabGrants" },
  { id: "reminders", labelKey: "subscriptions.tabReminders" },
  { id: "policy", labelKey: "subscriptions.tabPolicy" },
  { id: "ltv", labelKey: "subscriptions.tabLtv" },
];

export default function SubscriptionsPage() {
  const list = useAdminList<Row, { plan: string }>({
    queryKey: "admin-subscriptions",
    path: "/api/v1/admin/subscriptions",
    defaultSort: "id",
    initialFilters: { plan: "" },
  });

  const [tab, setTab] = useState<Tab>("users");
  const [hubDays, setHubDays] = useState(90);
  const [hub, setHub] = useState<Hub | null>(null);
  const [hubError, setHubError] = useState<string | null>(null);
  const [hubLoading, setHubLoading] = useState(false);

  const [actionError, setActionError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [churnReason, setChurnReason] = useState("");

  const [editDrafts, setEditDrafts] = useState<
    Record<string, { monthly_usd: string; trial_days: string; limits: string; region_currency: string }>
  >({});
  const [policyDraft, setPolicyDraft] = useState<{
    grace_days: string;
    soft_lock_enabled: boolean;
    reminder_days: string;
    churn_reasons: string;
    soft_lock_message: string;
  } | null>(null);

  const loadHub = useCallback(async () => {
    setHubLoading(true);
    setHubError(null);
    try {
      const data = await apiFetch<Hub>(`/api/v1/admin/subscriptions/hub?days=${hubDays}`);
      setHub(data);
      const drafts: typeof editDrafts = {};
      for (const p of data.plans) {
        drafts[p.plan_code] = {
          monthly_usd: p.monthly_usd ?? "",
          trial_days: String(p.trial_days ?? 0),
          limits: JSON.stringify(p.limits ?? {}, null, 2),
          region_currency: JSON.stringify(p.region_currency ?? {}, null, 2),
        };
      }
      setEditDrafts(drafts);
      setPolicyDraft({
        grace_days: String(data.policy.grace_days),
        soft_lock_enabled: data.policy.soft_lock_enabled,
        reminder_days: (data.policy.reminder_days || []).join(", "),
        churn_reasons: (data.policy.churn_reasons || []).join(", "),
        soft_lock_message: JSON.stringify(data.policy.soft_lock_message ?? {}, null, 2),
      });
    } catch (err) {
      setHubError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setHubLoading(false);
    }
  }, [hubDays]);

  useEffect(() => {
    if (tab !== "users") void loadHub();
  }, [tab, loadHub]);

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
        churn_reason: churnReason || undefined,
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
      churn_reason: churnReason || "admin_revoke",
    });
  }

  async function savePlan(code: string) {
    const d = editDrafts[code];
    if (!d) return;
    setActionError(null);
    setToast(null);
    try {
      let limits: Record<string, unknown>;
      let region_currency: Record<string, string>;
      try {
        limits = JSON.parse(d.limits) as Record<string, unknown>;
        region_currency = JSON.parse(d.region_currency) as Record<string, string>;
      } catch {
        setActionError("JSON noto‘g‘ri");
        return;
      }
      await apiFetch(`/api/v1/admin/plan-settings/${code}`, {
        method: "PUT",
        body: JSON.stringify({
          monthly_usd: code === "basic" ? null : d.monthly_usd === "" ? null : Number(d.monthly_usd),
          trial_days: Number(d.trial_days) || 0,
          limits,
          region_currency,
        }),
      });
      setToast(t("app.success"));
      await loadHub();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function savePolicy() {
    if (!policyDraft) return;
    setActionError(null);
    setToast(null);
    try {
      const reminder_days = policyDraft.reminder_days
        .split(/[,;\s]+/)
        .map((x) => Number(x.trim()))
        .filter((n) => n > 0);
      const churn_reasons = policyDraft.churn_reasons
        .split(/[,;]+/)
        .map((x) => x.trim())
        .filter(Boolean);
      let soft_lock_message: Record<string, string>;
      try {
        soft_lock_message = JSON.parse(policyDraft.soft_lock_message) as Record<string, string>;
      } catch {
        setActionError("Soft-lock JSON noto‘g‘ri");
        return;
      }
      await apiFetch("/api/v1/admin/subscription-policy", {
        method: "PUT",
        body: JSON.stringify({
          grace_days: Number(policyDraft.grace_days) || 0,
          soft_lock_enabled: policyDraft.soft_lock_enabled,
          reminder_days,
          churn_reasons,
          soft_lock_message,
        }),
      });
      setToast(t("app.success"));
      await loadHub();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("subscriptions.title")} subtitle={t("subscriptions.subtitle")}>
        <div className="flex flex-wrap items-center gap-2">
          <label className="text-xs text-zinc-500">{t("subscriptions.days")}</label>
          <select
            value={hubDays}
            onChange={(e) => setHubDays(Number(e.target.value))}
            className="rounded-lg border px-2 py-1.5 text-sm"
          >
            <option value={30}>30</option>
            <option value={90}>90</option>
            <option value={180}>180</option>
            <option value={365}>365</option>
          </select>
          {tab !== "users" ? (
            <button
              type="button"
              onClick={() => void loadHub()}
              className="rounded-lg border px-3 py-1.5 text-sm hover:bg-zinc-50"
            >
              {t("subscriptions.reload")}
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
            {t(tb.labelKey)}
          </button>
        ))}
      </div>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}
      {hubError && tab !== "users" ? <Alert variant="error">{hubError}</Alert> : null}

      {tab === "users" ? (
        <>
          <DataToolbar
            search={{
              value: list.q,
              onChange: list.setQ,
              placeholder: t("users.searchPlaceholder"),
            }}
            showClear={list.hasActiveFilters}
            onClear={list.clearFilters}
            filters={
              <>
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
                  value={churnReason}
                  onChange={(e) => setChurnReason(e.target.value)}
                  placeholder={t("subscriptions.churnReason")}
                  className="rounded-lg border px-3 py-2 text-sm"
                />
              </>
            }
          />
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
                <tbody className="divide-y">
                  {list.items.map((row) => (
                    <tr key={row.user_id} className="hover:bg-zinc-50/80">
                      <td className="px-4 py-3">
                        <div className="font-medium">{row.full_name || "—"}</div>
                        <div className="text-xs text-zinc-500">
                          #{row.user_id} · {row.email}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <select
                          disabled={busyId === row.user_id}
                          value={row.plan}
                          onChange={(e) => void grantPlan(row.user_id, e.target.value)}
                          className="rounded border px-2 py-1 text-sm"
                        >
                          <option value="basic">{planLabel("basic")}</option>
                          <option value="premium">{planLabel("premium")}</option>
                          <option value="business">{planLabel("business")}</option>
                        </select>
                      </td>
                      <td className="px-4 py-3">
                        <StatusBadge status={row.is_active ? "active" : "inactive"} />
                      </td>
                      <td className="px-4 py-3 text-zinc-600">{formatDate(row.expires_at)}</td>
                      <td className="px-4 py-3">{row.auto_renew ? "✓" : "—"}</td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap gap-1">
                          <button
                            type="button"
                            disabled={busyId === row.user_id || row.plan === "basic"}
                            onClick={() => void extend30(row.user_id, row.expires_at)}
                            className="rounded border px-2 py-1 text-xs hover:bg-zinc-50 disabled:opacity-40"
                          >
                            {t("subscriptions.extend30")}
                          </button>
                          <button
                            type="button"
                            disabled={busyId === row.user_id || !row.auto_renew}
                            onClick={() => void stopRenew(row.user_id)}
                            className="rounded border px-2 py-1 text-xs hover:bg-zinc-50 disabled:opacity-40"
                          >
                            {t("subscriptions.stopRenew")}
                          </button>
                          <button
                            type="button"
                            disabled={busyId === row.user_id || row.plan === "basic"}
                            onClick={() => void revokeNow(row.user_id)}
                            className="rounded border px-2 py-1 text-xs text-red-700 hover:bg-red-50 disabled:opacity-40"
                          >
                            {t("subscriptions.revokeNow")}
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <Pagination
                page={list.page}
                totalPages={list.totalPages}
                total={list.total}
                onPageChange={list.setPage}
              />
            </ListState>
          </div>
        </>
      ) : null}

      {tab !== "users" && hubLoading && !hub ? (
        <p className="text-sm text-zinc-500">{t("app.loading")}</p>
      ) : null}

      {tab === "editor" && hub ? (
        <div className="grid gap-4 md:grid-cols-3">
          {hub.plans.map((p) => {
            const d = editDrafts[p.plan_code];
            if (!d) return null;
            return (
              <div key={p.plan_code} className="space-y-3 rounded-xl border bg-white p-4">
                <h3 className="font-semibold">{planLabel(p.plan_code)}</h3>
                <label className="block text-xs text-zinc-500">
                  {t("subscriptions.priceUsd")}
                  <input
                    disabled={p.plan_code === "basic"}
                    value={d.monthly_usd}
                    onChange={(e) =>
                      setEditDrafts((prev) => ({
                        ...prev,
                        [p.plan_code]: { ...d, monthly_usd: e.target.value },
                      }))
                    }
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm disabled:bg-zinc-50"
                  />
                </label>
                <label className="block text-xs text-zinc-500">
                  {t("subscriptions.trialDays")}
                  <input
                    value={d.trial_days}
                    onChange={(e) =>
                      setEditDrafts((prev) => ({
                        ...prev,
                        [p.plan_code]: { ...d, trial_days: e.target.value },
                      }))
                    }
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                  />
                </label>
                <label className="block text-xs text-zinc-500">
                  {t("subscriptions.limitsJson")}
                  <textarea
                    rows={5}
                    value={d.limits}
                    onChange={(e) =>
                      setEditDrafts((prev) => ({
                        ...prev,
                        [p.plan_code]: { ...d, limits: e.target.value },
                      }))
                    }
                    className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-xs"
                  />
                </label>
                <label className="block text-xs text-zinc-500">
                  {t("subscriptions.regionCurrency")}
                  <textarea
                    rows={3}
                    value={d.region_currency}
                    onChange={(e) =>
                      setEditDrafts((prev) => ({
                        ...prev,
                        [p.plan_code]: { ...d, region_currency: e.target.value },
                      }))
                    }
                    className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-xs"
                  />
                </label>
                <button
                  type="button"
                  onClick={() => void savePlan(p.plan_code)}
                  className="rounded-lg bg-zinc-900 px-3 py-2 text-sm text-white hover:bg-zinc-800"
                >
                  {t("subscriptions.save")}
                </button>
              </div>
            );
          })}
        </div>
      ) : null}

      {tab === "cohort" && hub ? (
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-4">
            {[
              { label: t("subscriptions.upgrades"), value: hub.cohort.upgrades },
              { label: t("subscriptions.downgrades"), value: hub.cohort.downgrades },
              { label: t("subscriptions.churnTotal"), value: hub.cohort.churn_total },
              {
                label: t("subscriptions.activeByPlan"),
                value: Object.entries(hub.cohort.active_by_plan)
                  .map(([k, v]) => `${planLabel(k)}: ${v}`)
                  .join(" · ") || "—",
              },
            ].map((c) => (
              <div key={c.label} className="rounded-xl border bg-white p-4">
                <div className="text-xs text-zinc-500">{c.label}</div>
                <div className="mt-1 text-lg font-semibold">{c.value}</div>
              </div>
            ))}
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="rounded-xl border bg-white p-4">
              <h3 className="mb-3 font-semibold">{t("subscriptions.transitions")}</h3>
              {hub.cohort.transitions.length === 0 ? (
                <p className="text-sm text-zinc-500">{t("subscriptions.noData")}</p>
              ) : (
                <ul className="space-y-2 text-sm">
                  {hub.cohort.transitions.map((tr) => (
                    <li key={tr.from_to} className="flex justify-between border-b py-1">
                      <span>{tr.from_to}</span>
                      <span className="font-medium">{tr.count}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div className="rounded-xl border bg-white p-4">
              <h3 className="mb-3 font-semibold">{t("subscriptions.churnReasons")}</h3>
              {hub.cohort.churn_reasons.length === 0 ? (
                <p className="text-sm text-zinc-500">{t("subscriptions.noData")}</p>
              ) : (
                <ul className="space-y-2 text-sm">
                  {hub.cohort.churn_reasons.map((cr) => (
                    <li key={cr.reason} className="flex justify-between border-b py-1">
                      <span>{cr.reason}</span>
                      <span className="font-medium">{cr.count}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {tab === "grants" && hub ? (
        <div className="overflow-hidden rounded-xl border bg-white">
          {hub.grants.items.length === 0 ? (
            <p className="p-6 text-sm text-zinc-500">{t("subscriptions.noData")}</p>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                <tr>
                  <th className="px-4 py-3 text-left">{t("payments.colCreated")}</th>
                  <th className="px-4 py-3 text-left">{t("subscriptions.grantAdmin")}</th>
                  <th className="px-4 py-3 text-left">User</th>
                  <th className="px-4 py-3 text-left">{t("subscriptions.grantFromTo")}</th>
                  <th className="px-4 py-3 text-left">{t("subscriptions.churnReason")}</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {hub.grants.items.map((g) => (
                  <tr key={g.id}>
                    <td className="px-4 py-3">{formatDate(g.created_at)}</td>
                    <td className="px-4 py-3">
                      <div>{g.admin_name || "—"}</div>
                      <div className="text-xs text-zinc-500">{g.admin_email}</div>
                    </td>
                    <td className="px-4 py-3">#{g.user_id ?? "—"}</td>
                    <td className="px-4 py-3">
                      {planLabel(g.from_plan || "?")} → {planLabel(g.to_plan || "?")}
                    </td>
                    <td className="px-4 py-3 text-zinc-600">{g.churn_reason || g.note || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ) : null}

      {tab === "reminders" && hub ? (
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            {Object.entries(hub.reminders.counts).map(([k, v]) => (
              <span key={k} className="rounded-full bg-zinc-100 px-3 py-1 text-xs">
                {k === "other" ? "other" : `≤${k}d`}: {v}
              </span>
            ))}
          </div>
          <div className="overflow-hidden rounded-xl border bg-white">
            {hub.reminders.items.length === 0 ? (
              <p className="p-6 text-sm text-zinc-500">{t("subscriptions.noData")}</p>
            ) : (
              <table className="min-w-full text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <th className="px-4 py-3 text-left">{t("subscriptions.colUser")}</th>
                    <th className="px-4 py-3 text-left">{t("subscriptions.colPlan")}</th>
                    <th className="px-4 py-3 text-left">{t("subscriptions.colExpires")}</th>
                    <th className="px-4 py-3 text-left">{t("subscriptions.daysLeft")}</th>
                    <th className="px-4 py-3 text-left">{t("subscriptions.reminderBucket")}</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {hub.reminders.items.map((r) => (
                    <tr key={r.user_id}>
                      <td className="px-4 py-3">
                        <div className="font-medium">{r.full_name}</div>
                        <div className="text-xs text-zinc-500">
                          #{r.user_id} · {r.email}
                        </div>
                      </td>
                      <td className="px-4 py-3">{planLabel(r.plan)}</td>
                      <td className="px-4 py-3">{formatDate(r.expires_at)}</td>
                      <td className="px-4 py-3">{r.days_left}</td>
                      <td className="px-4 py-3">{r.reminder_bucket ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      ) : null}

      {tab === "policy" && policyDraft ? (
        <div className="max-w-xl space-y-4 rounded-xl border bg-white p-6">
          <label className="block text-xs text-zinc-500">
            {t("subscriptions.graceDays")}
            <input
              value={policyDraft.grace_days}
              onChange={(e) => setPolicyDraft({ ...policyDraft, grace_days: e.target.value })}
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
            />
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={policyDraft.soft_lock_enabled}
              onChange={(e) =>
                setPolicyDraft({ ...policyDraft, soft_lock_enabled: e.target.checked })
              }
            />
            {t("subscriptions.softLock")}
          </label>
          <label className="block text-xs text-zinc-500">
            {t("subscriptions.reminderDays")}
            <input
              value={policyDraft.reminder_days}
              onChange={(e) => setPolicyDraft({ ...policyDraft, reminder_days: e.target.value })}
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs text-zinc-500">
            {t("subscriptions.churnReasonList")}
            <input
              value={policyDraft.churn_reasons}
              onChange={(e) => setPolicyDraft({ ...policyDraft, churn_reasons: e.target.value })}
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs text-zinc-500">
            {t("subscriptions.softLockMsg")}
            <textarea
              rows={5}
              value={policyDraft.soft_lock_message}
              onChange={(e) =>
                setPolicyDraft({ ...policyDraft, soft_lock_message: e.target.value })
              }
              className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-xs"
            />
          </label>
          <button
            type="button"
            onClick={() => void savePolicy()}
            className="rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white hover:bg-zinc-800"
          >
            {t("subscriptions.save")}
          </button>
        </div>
      ) : null}

      {tab === "ltv" && hub ? (
        <div className="space-y-4">
          <p className="text-sm text-zinc-600">
            {t("subscriptions.winner")}:{" "}
            <strong>{planLabel(hub.ltv.delta.winner === "tie" ? "premium" : hub.ltv.delta.winner)}</strong>
            {hub.ltv.delta.winner === "tie" ? " (tie)" : ""} · {t("subscriptions.delta")}: LTV{" "}
            {hub.ltv.delta.ltv_window >= 0 ? "+" : ""}
            {hub.ltv.delta.ltv_window}$ · ARPU {hub.ltv.delta.arpu_window >= 0 ? "+" : ""}
            {hub.ltv.delta.arpu_window}$
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            {(["premium", "business"] as const).map((code) => {
              const p = hub.ltv.plans[code];
              if (!p) return null;
              return (
                <div key={code} className="rounded-xl border bg-white p-5">
                  <h3 className="text-lg font-semibold">{planLabel(code)}</h3>
                  <p className="text-xs text-zinc-500">
                    Catalog ${p.catalog_monthly_usd}/mo · window {hub.ltv.days}d
                  </p>
                  <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.ltvWindow")}</dt>
                      <dd className="text-xl font-semibold">${formatNumber(p.ltv_window)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.ltvEst")}</dt>
                      <dd className="text-xl font-semibold">${formatNumber(p.ltv_estimated)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.arpu")}</dt>
                      <dd>${formatNumber(p.arpu_window)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.revenue")}</dt>
                      <dd>${formatNumber(p.revenue)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.payingUsers")}</dt>
                      <dd>{formatNumber(p.paying_users)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.activeSubs")}</dt>
                      <dd>{formatNumber(p.active_subscribers)}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">{t("subscriptions.avgTenure")}</dt>
                      <dd>{p.avg_tenure_months}</dd>
                    </div>
                    <div>
                      <dt className="text-zinc-500">Tx</dt>
                      <dd>{formatNumber(p.transactions)}</dd>
                    </div>
                  </dl>
                </div>
              );
            })}
          </div>
        </div>
      ) : null}
    </div>
  );
}
