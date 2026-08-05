"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { Drawer } from "@/components/admin/drawer";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { auditActionLabel, formatDate, planLabel, t } from "@/lib/i18n";
import { useMemo, useState } from "react";

type UserFilters = {
  status: string;
  plan: string;
  country: string;
  risk: string;
  verified: string;
  last_active: string;
  device: string;
};

type UserRow = {
  id: number;
  full_name: string;
  email: string;
  number: string;
  country?: string | null;
  is_active: boolean;
  is_verified: boolean;
  verified_badge: boolean;
  factory_verified?: boolean;
  inspection_passed?: boolean;
  audit_report_url?: string | null;
  deleted_at: string | null;
  plan?: string;
  created_at: string;
  risk_score?: number;
  risk_level?: string;
  risk_flags?: string[];
  last_active_at?: string | null;
  complaints_count?: number;
};

type PaymentBrief = {
  id: number;
  status: string;
  kind: string;
  amount: string;
  currency: string;
  created_at: string;
};

type Detail = UserRow & {
  birth_date?: string | null;
  gender?: string | null;
  avatar_url?: string | null;
  app_language?: string;
  native_language?: string;
  deletion_reason?: string | null;
  subscription: Record<string, unknown> | null;
  business?: {
    company_name: string;
    country?: string | null;
    complaints_count: number;
    rating?: number | null;
    documents_verified: boolean;
    factory_verified: boolean;
    inspection_passed: boolean;
  } | null;
  risk?: {
    risk_score: number;
    risk_level: string;
    flags: string[];
    reasons: string[];
    complaints_count: number;
    rejected_products: number;
    failed_payments_30d: number;
    messages_24h: number;
    disposable_email: boolean;
  };
  recent_payments: PaymentBrief[];
  products?: {
    id: number;
    name: string;
    status: string;
    price: string;
    currency: string;
    created_at: string;
    moderation_note: string;
  }[];
  chats?: {
    id: number;
    type: string;
    title: string | null;
    message_count: number;
    last_message_at: string | null;
    peer_id: number | null;
  }[];
  sessions?: {
    session_id: string;
    device_name: string | null;
    device_type: string | null;
    platform: string | null;
    app_version: string | null;
    ip_address: string | null;
    last_active_at: string | null;
    session_started_at: string | null;
  }[];
  strikes?: { kind: string; at: string | null; label: string; ref: string }[];
  sessions_count?: number;
  change_timeline?: {
    id: number;
    at: string;
    action: string;
    actor_name: string;
    ip: string | null;
    summary: string;
    diff: { field: string; before: unknown; after: unknown }[];
    integrity_badge: string;
  }[];
};

type ConfirmState =
  | { type: "softDelete"; id: number }
  | { type: "restore"; id: number }
  | { type: "assign"; number: string }
  | { type: "random" }
  | { type: "bulkBan" }
  | { type: "bulkUnban" }
  | { type: "bulkPlan"; plan: string }
  | { type: "revokeSessions" }
  | null;

type DetailTab =
  | "profile"
  | "payments"
  | "chats"
  | "products"
  | "strikes"
  | "sessions"
  | "changes";

function riskBadgeClass(level?: string) {
  switch (level) {
    case "high":
      return "bg-rose-100 text-rose-800";
    case "medium":
      return "bg-amber-100 text-amber-800";
    case "low":
      return "bg-yellow-50 text-yellow-800";
    default:
      return "bg-zinc-100 text-zinc-600";
  }
}

function riskLabel(level?: string) {
  switch (level) {
    case "high":
      return t("users.riskHigh");
    case "medium":
      return t("users.riskMedium");
    case "low":
      return t("users.riskLow");
    default:
      return t("users.riskNone");
  }
}

export default function UsersPage() {
  const list = useAdminList<UserRow, UserFilters>({
    queryKey: "admin-users",
    path: "/api/v1/admin/users",
    searchParam: "search",
    defaultSort: "id",
    initialFilters: {
      status: "all",
      plan: "",
      country: "",
      risk: "",
      verified: "",
      last_active: "",
      device: "",
    },
  });

  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [detail, setDetail] = useState<Detail | null>(null);
  const [detailTab, setDetailTab] = useState<DetailTab>("profile");
  const [detailLoading, setDetailLoading] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmState>(null);
  const [tempPassword, setTempPassword] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [assignNumber, setAssignNumber] = useState("");
  const [applyBonus, setApplyBonus] = useState(false);
  const [forceAssign, setForceAssign] = useState(false);
  const [bulkPlan, setBulkPlan] = useState("premium");

  const selectedIds = useMemo(() => Array.from(selected), [selected]);
  const pageIds = list.items.map((u) => u.id);
  const allPageSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id));

  function toggleSelect(id: number) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectPage() {
    setSelected((prev) => {
      const next = new Set(prev);
      if (allPageSelected) {
        for (const id of pageIds) next.delete(id);
      } else {
        for (const id of pageIds) next.add(id);
      }
      return next;
    });
  }

  async function openDetail(id: number) {
    setDetailLoading(true);
    setTempPassword(null);
    setAssignNumber("");
    setApplyBonus(false);
    setForceAssign(false);
    setDetailTab("profile");
    try {
      const d = await apiFetch<Detail>(`/api/v1/admin/users/${id}/detail`);
      setDetail(d);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setDetailLoading(false);
    }
  }

  async function patchUser(id: number, body: object) {
    setBusy(true);
    try {
      await apiFetch(`/api/v1/admin/users/${id}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      setToast(t("app.success"));
      await list.refetch();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function grantPlan(userId: number, plan: string) {
    setBusy(true);
    try {
      const body: Record<string, unknown> = {
        plan,
        is_active: true,
        auto_renew: false,
      };
      if (plan !== "basic") {
        const expires = new Date();
        expires.setDate(expires.getDate() + 30);
        body.billing_cycle = "monthly";
        body.expires_at = expires.toISOString();
      }
      await apiFetch(`/api/v1/admin/subscriptions/${userId}`, {
        method: "PATCH",
        body: JSON.stringify(body),
      });
      setToast(t("app.success"));
      await list.refetch();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function act(path: string, body?: object) {
    setBusy(true);
    try {
      await apiFetch(path, {
        method: "POST",
        body: body ? JSON.stringify(body) : undefined,
      });
      setToast(t("app.success"));
      await list.refetch();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
      setConfirm(null);
    }
  }

  async function runBulk(action: "ban" | "unban" | "grant_plan", plan?: string) {
    if (selectedIds.length === 0) return;
    setBusy(true);
    try {
      await apiFetch("/api/v1/admin/users/bulk", {
        method: "POST",
        body: JSON.stringify({
          user_ids: selectedIds,
          action,
          plan: action === "grant_plan" ? plan : undefined,
        }),
      });
      setToast(t("app.success"));
      setSelected(new Set());
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
      setConfirm(null);
    }
  }

  async function exportCsv(ids?: number[]) {
    setBusy(true);
    try {
      const params = new URLSearchParams();
      if (ids?.length) {
        params.set("ids", ids.join(","));
      } else {
        const f = list.filters;
        if (list.q.trim()) params.set("search", list.q.trim());
        if (f.status && f.status !== "all") params.set("status", String(f.status));
        if (f.plan) params.set("plan", String(f.plan));
        if (f.country) params.set("country", String(f.country));
        if (f.risk) params.set("risk", String(f.risk));
        if (f.verified) params.set("verified", String(f.verified));
        if (f.last_active) params.set("last_active", String(f.last_active));
        if (f.device) params.set("device", String(f.device));
      }
      const { blob, filename } = await apiFetchBlob(
        `/api/v1/admin/users/export?${params.toString()}`,
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      setToast(t("app.success"));
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function doAssign(number?: string) {
    if (!detail) return;
    setBusy(true);
    try {
      const res = number
        ? await apiFetch<{ number: string }>(
            `/api/v1/admin/users/${detail.id}/assign-number`,
            {
              method: "POST",
              body: JSON.stringify({
                number,
                apply_bonus: applyBonus,
                force: forceAssign,
              }),
            },
          )
        : await apiFetch<{ number: string }>(
            `/api/v1/admin/users/${detail.id}/assign-random-number?apply_bonus=${applyBonus}`,
            { method: "POST" },
          );
      setToast(t("users.numberAssigned", { number: res.number }));
      setAssignNumber("");
      await list.refetch();
      await openDetail(detail.id);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
      setConfirm(null);
    }
  }

  async function resetPassword(id: number) {
    setBusy(true);
    try {
      const res = await apiFetch<{ temp_password: string }>(
        `/api/v1/admin/users/${id}/reset-password`,
        { method: "POST" },
      );
      setTempPassword(res.temp_password);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  function userStatus(u: UserRow) {
    if (u.deleted_at) return "deleted";
    if (!u.is_active) return "banned";
    return "active";
  }

  const tabs: { id: DetailTab; label: string }[] = [
    { id: "profile", label: t("users.tabProfile") },
    { id: "payments", label: t("users.tabPayments") },
    { id: "chats", label: t("users.tabChats") },
    { id: "products", label: t("users.tabProducts") },
    { id: "strikes", label: t("users.tabStrikes") },
    { id: "sessions", label: t("users.tabSessions") },
    { id: "changes", label: t("users.tabChanges") },
  ];

  return (
    <div className="space-y-6">
      <PageHeader title={t("users.title")} subtitle={t("users.subtitle")}>
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
                value={list.filters.status}
                onChange={(e) => list.setFilter("status", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="all">{t("users.statusAll")}</option>
                <option value="active">{t("users.statusActive")}</option>
                <option value="inactive">{t("users.statusInactive")}</option>
                <option value="deleted">{t("users.statusDeleted")}</option>
              </select>
              <select
                value={list.filters.plan}
                onChange={(e) => list.setFilter("plan", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("users.planAll")}</option>
                <option value="basic">{planLabel("basic")}</option>
                <option value="premium">{planLabel("premium")}</option>
                <option value="business">{planLabel("business")}</option>
              </select>
              <input
                value={list.filters.country}
                onChange={(e) =>
                  list.setFilter("country", e.target.value.toUpperCase().slice(0, 2))
                }
                placeholder={t("users.countryPlaceholder")}
                className="w-20 rounded-lg border px-3 py-2 text-sm uppercase"
                maxLength={2}
              />
              <select
                value={list.filters.risk}
                onChange={(e) => list.setFilter("risk", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("users.riskAll")}</option>
                <option value="none">{t("users.riskNone")}</option>
                <option value="low">{t("users.riskLow")}</option>
                <option value="medium">{t("users.riskMedium")}</option>
                <option value="high">{t("users.riskHigh")}</option>
                <option value="flagged">{t("users.riskFlagged")}</option>
              </select>
              <select
                value={list.filters.verified}
                onChange={(e) => list.setFilter("verified", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("users.verifiedAll")}</option>
                <option value="yes">{t("users.verifiedYes")}</option>
                <option value="no">{t("users.verifiedNo")}</option>
                <option value="badge">{t("users.verifiedBadge")}</option>
              </select>
              <select
                value={list.filters.last_active}
                onChange={(e) => list.setFilter("last_active", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("users.lastActiveAll")}</option>
                <option value="24h">{t("users.lastActive24h")}</option>
                <option value="7d">{t("users.lastActive7d")}</option>
                <option value="30d">{t("users.lastActive30d")}</option>
                <option value="inactive_30d">{t("users.lastActiveInactive")}</option>
              </select>
              <select
                value={list.filters.device}
                onChange={(e) => list.setFilter("device", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="">{t("users.deviceAll")}</option>
                <option value="android">{t("users.deviceAndroid")}</option>
                <option value="ios">{t("users.deviceIos")}</option>
                <option value="web">{t("users.deviceWeb")}</option>
                <option value="mobile">{t("users.deviceMobile")}</option>
              </select>
            </>
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      <div className="flex flex-wrap items-center gap-2 rounded-xl border bg-white px-4 py-3 text-sm">
        <span className="text-zinc-500">
          {t("users.bulkSelected", { n: selectedIds.length })}
        </span>
        <button
          type="button"
          disabled={busy || selectedIds.length === 0}
          onClick={() => setConfirm({ type: "bulkBan" })}
          className="rounded-lg border px-3 py-1.5 disabled:opacity-40"
        >
          {t("users.bulkBan")}
        </button>
        <button
          type="button"
          disabled={busy || selectedIds.length === 0}
          onClick={() => setConfirm({ type: "bulkUnban" })}
          className="rounded-lg border px-3 py-1.5 disabled:opacity-40"
        >
          {t("users.bulkUnban")}
        </button>
        <select
          value={bulkPlan}
          onChange={(e) => setBulkPlan(e.target.value)}
          className="rounded-lg border px-2 py-1.5 text-sm"
        >
          <option value="basic">{planLabel("basic")}</option>
          <option value="premium">{planLabel("premium")}</option>
          <option value="business">{planLabel("business")}</option>
        </select>
        <button
          type="button"
          disabled={busy || selectedIds.length === 0}
          onClick={() => setConfirm({ type: "bulkPlan", plan: bulkPlan })}
          className="rounded-lg border px-3 py-1.5 disabled:opacity-40"
        >
          {t("users.bulkGrantPlan")}
        </button>
        <button
          type="button"
          disabled={busy || selectedIds.length === 0}
          onClick={() => void exportCsv(selectedIds)}
          className="rounded-lg border px-3 py-1.5 disabled:opacity-40"
        >
          {t("users.bulkExport")}
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => void exportCsv()}
          className="ml-auto rounded-lg bg-zinc-900 px-3 py-1.5 text-white disabled:opacity-40"
        >
          {t("users.bulkExportAll")}
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border bg-white">
        <ListState
          isLoading={list.isLoading}
          error={list.error}
          isEmpty={list.items.length === 0}
          hasActiveFilters={list.hasActiveFilters}
          onClearFilters={list.clearFilters}
          onRetry={() => void list.refetch()}
        >
          <table className="min-w-full text-left text-sm">
            <thead className="sticky top-0 bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-3">
                  <input
                    type="checkbox"
                    checked={allPageSelected}
                    onChange={toggleSelectPage}
                    aria-label={t("users.selectAll")}
                  />
                </th>
                <SortableTh
                  label={t("users.colId")}
                  sortKey="id"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <SortableTh
                  label={t("users.colUser")}
                  sortKey="full_name"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <SortableTh
                  label={t("users.colNumber")}
                  sortKey="number"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <th className="px-4 py-3">{t("users.colCountry")}</th>
                <th className="px-4 py-3">{t("users.colPlan")}</th>
                <th className="px-4 py-3">{t("users.colRisk")}</th>
                <th className="px-4 py-3">{t("users.colLastActive")}</th>
                <th className="px-4 py-3">{t("users.colStatus")}</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {list.items.map((u) => (
                <tr key={u.id} className="border-t hover:bg-zinc-50">
                  <td className="px-3 py-3">
                    <input
                      type="checkbox"
                      checked={selected.has(u.id)}
                      onChange={() => toggleSelect(u.id)}
                    />
                  </td>
                  <td className="px-4 py-3 tabular-nums text-zinc-500">{u.id}</td>
                  <td className="px-4 py-3">
                    <div className="font-medium">{u.full_name}</div>
                    <div className="text-xs text-zinc-500">{u.email}</div>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">{u.number}</td>
                  <td className="px-4 py-3 uppercase text-zinc-600">{u.country || "—"}</td>
                  <td className="px-4 py-3">{u.plan ? planLabel(u.plan) : "—"}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${riskBadgeClass(u.risk_level)}`}
                      title={(u.risk_flags ?? []).join(", ")}
                    >
                      {u.risk_score ?? 0} · {riskLabel(u.risk_level)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {u.last_active_at ? formatDate(u.last_active_at) : "—"}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={userStatus(u)} />
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      type="button"
                      onClick={() => void openDetail(u.id)}
                      className="text-sm font-medium underline"
                    >
                      {t("app.open")}
                    </button>
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

      <Drawer
        open={!!detail || detailLoading}
        onClose={() => {
          setDetail(null);
          setTempPassword(null);
        }}
        title={detail?.full_name ?? t("app.loading")}
        width="xl"
      >
        {detailLoading && !detail ? (
          <p className="text-sm text-zinc-500">{t("app.loading")}</p>
        ) : detail ? (
          <>
            <p className="text-sm text-zinc-500">{detail.email}</p>
            <div className="mt-3 flex flex-wrap gap-2">
              <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${riskBadgeClass(detail.risk_level)}`}>
                {t("users.riskTitle")}: {detail.risk_score ?? 0} · {riskLabel(detail.risk_level)}
              </span>
              {(detail.risk_flags ?? detail.risk?.flags ?? []).map((f) => (
                <span key={f} className="rounded bg-rose-50 px-1.5 py-0.5 text-[10px] font-medium text-rose-700">
                  {f}
                </span>
              ))}
            </div>

            <div className="mt-4 flex flex-wrap gap-1 border-b pb-2">
              {tabs.map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setDetailTab(tab.id)}
                  className={`rounded-lg px-3 py-1.5 text-xs font-medium ${
                    detailTab === tab.id
                      ? "bg-zinc-900 text-white"
                      : "text-zinc-600 hover:bg-zinc-100"
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="mt-4 max-h-[70vh] overflow-y-auto pr-1">
              {detailTab === "profile" ? (
                <>
                  <dl className="space-y-3 text-sm">
                    <div className="flex justify-between">
                      <dt className="text-zinc-500">{t("users.drawerNumber")}</dt>
                      <dd className="font-mono">{detail.number}</dd>
                    </div>
                    <div className="flex justify-between">
                      <dt className="text-zinc-500">{t("users.colCountry")}</dt>
                      <dd className="uppercase">{detail.country || "—"}</dd>
                    </div>
                    <div className="flex justify-between">
                      <dt className="text-zinc-500">{t("users.drawerPlan")}</dt>
                      <dd>{detail.plan ? planLabel(detail.plan) : "—"}</dd>
                    </div>
                    <div className="flex justify-between gap-4 flex-wrap">
                      <span className="text-zinc-500">
                        {t("users.verified")}: {detail.is_verified ? t("app.yes") : t("app.no")}
                      </span>
                      <span className="text-zinc-500">
                        {t("users.badge")}: {detail.verified_badge ? t("app.yes") : t("app.no")}
                      </span>
                    </div>
                    {detail.business ? (
                      <div className="rounded-lg border p-3 text-xs text-zinc-600">
                        <p className="font-medium text-zinc-900">{detail.business.company_name}</p>
                        <p>
                          {t("users.riskFlags")}: complaints {detail.business.complaints_count}
                          {detail.business.rating != null
                            ? ` · rating ${detail.business.rating}`
                            : ""}
                        </p>
                      </div>
                    ) : null}
                    {detail.deleted_at ? (
                      <div className="flex justify-between">
                        <dt className="text-zinc-500">{t("users.drawerDeleted")}</dt>
                        <dd className="text-xs text-amber-700">{formatDate(detail.deleted_at)}</dd>
                      </div>
                    ) : null}
                  </dl>

                  {!detail.deleted_at ? (
                    <div className="mt-6 rounded-lg border p-3 space-y-3">
                      <h3 className="text-sm font-semibold">{t("users.assignNumber")}</h3>
                      <div className="flex flex-wrap gap-2">
                        <input
                          value={assignNumber}
                          onChange={(e) =>
                            setAssignNumber(e.target.value.replace(/\D/g, "").slice(0, 7))
                          }
                          placeholder={t("users.assignNumberPlaceholder")}
                          className="rounded-lg border px-3 py-2 font-mono text-sm"
                          inputMode="numeric"
                        />
                        <button
                          type="button"
                          disabled={busy || assignNumber.length !== 7}
                          onClick={() => setConfirm({ type: "assign", number: assignNumber })}
                          className="rounded-lg bg-zinc-900 px-3 py-2 text-sm text-white disabled:opacity-40"
                        >
                          {t("users.assignNumberBtn")}
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => setConfirm({ type: "random" })}
                          className="rounded-lg border px-3 py-2 text-sm"
                        >
                          {t("users.assignRandom")}
                        </button>
                      </div>
                      <label className="flex items-center gap-2 text-xs text-zinc-600">
                        <input
                          type="checkbox"
                          checked={applyBonus}
                          onChange={(e) => setApplyBonus(e.target.checked)}
                        />
                        {t("users.applyBonus")}
                      </label>
                      <label className="flex items-center gap-2 text-xs text-zinc-600">
                        <input
                          type="checkbox"
                          checked={forceAssign}
                          onChange={(e) => setForceAssign(e.target.checked)}
                        />
                        {t("users.forceAssign")}
                      </label>
                    </div>
                  ) : null}

                  {!detail.deleted_at ? (
                    <div className="mt-6 flex flex-wrap gap-2">
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => patchUser(detail.id, { is_active: !detail.is_active })}
                        className="rounded-lg border px-3 py-2 text-sm"
                      >
                        {detail.is_active ? t("users.ban") : t("users.unban")}
                      </button>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() =>
                          patchUser(detail.id, { verified_badge: !detail.verified_badge })
                        }
                        className="rounded-lg border px-3 py-2 text-sm"
                      >
                        {detail.verified_badge ? t("users.removeBadge") : t("users.grantBadge")}
                      </button>
                      <select
                        defaultValue={detail.plan ?? "basic"}
                        disabled={busy}
                        onChange={(e) => grantPlan(detail.id, e.target.value)}
                        className="rounded-lg border px-3 py-2 text-sm"
                      >
                        <option value="basic">{planLabel("basic")}</option>
                        <option value="premium">{planLabel("premium")}</option>
                        <option value="business">{planLabel("business")}</option>
                      </select>
                    </div>
                  ) : null}

                  <div className="mt-6 flex flex-col gap-2">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void resetPassword(detail.id)}
                      className="rounded-lg bg-zinc-900 px-3 py-2 text-sm text-white"
                    >
                      {t("users.resetPassword")}
                    </button>
                    {tempPassword ? (
                      <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm">
                        <p className="font-medium">{t("users.tempPassword")}</p>
                        <code className="mt-1 block break-all font-mono text-base">
                          {tempPassword}
                        </code>
                      </div>
                    ) : null}
                    {isSuperAdmin() && !detail.deleted_at ? (
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => setConfirm({ type: "softDelete", id: detail.id })}
                        className="rounded-lg border border-red-300 px-3 py-2 text-sm text-red-700"
                      >
                        {t("users.softDelete")}
                      </button>
                    ) : null}
                    {isSuperAdmin() && detail.deleted_at ? (
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => setConfirm({ type: "restore", id: detail.id })}
                        className="rounded-lg border border-emerald-300 px-3 py-2 text-sm text-emerald-800"
                      >
                        {t("users.restoreAccount")}
                      </button>
                    ) : null}
                  </div>
                </>
              ) : null}

              {detailTab === "payments" ? (
                detail.recent_payments?.length ? (
                  <ul className="space-y-2">
                    {detail.recent_payments.map((p) => (
                      <li key={p.id} className="rounded border px-3 py-2 text-xs">
                        <div className="flex justify-between">
                          <span>
                            #{p.id} · {p.kind}
                          </span>
                          <StatusBadge status={p.status} />
                        </div>
                        <div className="mt-1 font-medium">
                          {p.amount} {p.currency} · {formatDate(p.created_at)}
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-zinc-500">{t("users.paymentsEmpty")}</p>
                )
              ) : null}

              {detailTab === "chats" ? (
                detail.chats?.length ? (
                  <ul className="space-y-2">
                    {detail.chats.map((c) => (
                      <li key={c.id} className="rounded border px-3 py-2 text-xs">
                        <div className="flex justify-between font-medium">
                          <span>
                            #{c.id} · {c.type}
                            {c.title ? ` · ${c.title}` : ""}
                          </span>
                          <span className="text-zinc-500">{c.message_count} msg</span>
                        </div>
                        <div className="mt-1 text-zinc-500">
                          peer: {c.peer_id ?? "—"} · {formatDate(c.last_message_at)}
                        </div>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-zinc-500">{t("users.chatsEmpty")}</p>
                )
              ) : null}

              {detailTab === "products" ? (
                detail.products?.length ? (
                  <ul className="space-y-2">
                    {detail.products.map((p) => (
                      <li key={p.id} className="rounded border px-3 py-2 text-xs">
                        <div className="flex justify-between">
                          <span className="font-medium">{p.name}</span>
                          <StatusBadge status={p.status} />
                        </div>
                        <div className="mt-1 text-zinc-600">
                          {p.price} {p.currency} · {formatDate(p.created_at)}
                        </div>
                        {p.moderation_note ? (
                          <p className="mt-1 text-rose-600">{p.moderation_note}</p>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-zinc-500">{t("users.productsEmpty")}</p>
                )
              ) : null}

              {detailTab === "strikes" ? (
                detail.strikes?.length ? (
                  <ul className="space-y-2">
                    {detail.strikes.map((s, i) => (
                      <li key={`${s.ref}-${i}`} className="rounded border px-3 py-2 text-xs">
                        <p className="font-medium">{s.label}</p>
                        <p className="text-zinc-500">
                          {s.kind} · {s.at ? formatDate(s.at) : "—"}
                        </p>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-zinc-500">{t("users.strikesEmpty")}</p>
                )
              ) : null}

              {detailTab === "sessions" ? (
                <>
                  <button
                    type="button"
                    disabled={busy || !detail.sessions?.length}
                    onClick={() => setConfirm({ type: "revokeSessions" })}
                    className="mb-4 rounded-lg border border-rose-300 px-3 py-2 text-sm text-rose-700 disabled:opacity-40"
                  >
                    {t("users.revokeAllSessions")}
                  </button>
                  {detail.sessions?.length ? (
                    <ul className="space-y-2">
                      {detail.sessions.map((s) => (
                        <li key={s.session_id} className="rounded border px-3 py-2 text-xs">
                          <p className="font-medium">
                            {s.device_name || s.platform || s.device_type || "Device"}
                          </p>
                          <p className="text-zinc-500">
                            {s.platform ?? "—"} · {s.app_version ?? ""} · IP {s.ip_address ?? "—"}
                          </p>
                          <p className="mt-1 text-zinc-400">
                            {t("users.colLastActive")}: {formatDate(s.last_active_at)}
                          </p>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="text-sm text-zinc-500">{t("users.sessionsEmpty")}</p>
                  )}
                </>
              ) : null}

              {detailTab === "changes" ? (
                detail.change_timeline?.length ? (
                  <ol className="relative space-y-0 border-l border-zinc-200 pl-4">
                    {detail.change_timeline.map((ev) => (
                      <li key={ev.id} className="mb-4 ml-1">
                        <span className="absolute -left-1.5 mt-1.5 h-3 w-3 rounded-full border border-white bg-zinc-400" />
                        <p className="text-xs font-medium">
                          {auditActionLabel(ev.action)}
                        </p>
                        <p className="text-[11px] text-zinc-500">
                          {formatDate(ev.at)} · {ev.actor_name}
                          {ev.ip ? ` · ${ev.ip}` : ""}
                        </p>
                        <p className="mt-1 text-xs text-zinc-700">{ev.summary}</p>
                        {ev.diff?.length ? (
                          <ul className="mt-1 space-y-0.5 text-[11px]">
                            {ev.diff.slice(0, 6).map((d) => (
                              <li key={d.field}>
                                <span className="font-medium">{d.field}</span>:{" "}
                                <span className="text-rose-600">
                                  {d.before === null || d.before === undefined
                                    ? "—"
                                    : String(d.before)}
                                </span>{" "}
                                →{" "}
                                <span className="text-emerald-700">
                                  {d.after === null || d.after === undefined
                                    ? "—"
                                    : String(d.after)}
                                </span>
                              </li>
                            ))}
                          </ul>
                        ) : null}
                      </li>
                    ))}
                  </ol>
                ) : (
                  <p className="text-sm text-zinc-500">{t("users.timelineEmpty")}</p>
                )
              ) : null}
            </div>
          </>
        ) : null}
      </Drawer>

      <ConfirmDialog
        open={confirm?.type === "softDelete"}
        title={t("users.softDelete")}
        message={t("users.confirmSoftDelete", {
          id: confirm?.type === "softDelete" ? confirm.id : 0,
        })}
        danger
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "softDelete") {
            void act(`/api/v1/admin/users/${confirm.id}/soft-delete`, {
              reason: "admin_panel",
            });
          }
        }}
      />
      <ConfirmDialog
        open={confirm?.type === "restore"}
        title={t("users.restoreAccount")}
        message={t("users.confirmRestore", {
          id: confirm?.type === "restore" ? confirm.id : 0,
        })}
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "restore") {
            void act(`/api/v1/admin/users/${confirm.id}/restore`);
          }
        }}
      />
      <ConfirmDialog
        open={confirm?.type === "assign"}
        title={t("users.assignNumber")}
        message={t("users.confirmAssign", {
          number: confirm?.type === "assign" ? confirm.number : "",
        })}
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "assign") void doAssign(confirm.number);
        }}
      />
      <ConfirmDialog
        open={confirm?.type === "random"}
        title={t("users.assignRandom")}
        message={t("users.confirmRandom")}
        onCancel={() => setConfirm(null)}
        onConfirm={() => void doAssign()}
      />
      <ConfirmDialog
        open={confirm?.type === "bulkBan"}
        title={t("users.bulkBan")}
        message={t("users.confirmBulkBan", { n: selectedIds.length })}
        danger
        onCancel={() => setConfirm(null)}
        onConfirm={() => void runBulk("ban")}
      />
      <ConfirmDialog
        open={confirm?.type === "bulkUnban"}
        title={t("users.bulkUnban")}
        message={t("users.confirmBulkUnban", { n: selectedIds.length })}
        onCancel={() => setConfirm(null)}
        onConfirm={() => void runBulk("unban")}
      />
      <ConfirmDialog
        open={confirm?.type === "bulkPlan"}
        title={t("users.bulkGrantPlan")}
        message={t("users.confirmBulkPlan", {
          n: selectedIds.length,
          plan:
            confirm?.type === "bulkPlan" ? planLabel(confirm.plan) : "",
        })}
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "bulkPlan") void runBulk("grant_plan", confirm.plan);
        }}
      />
      <ConfirmDialog
        open={confirm?.type === "revokeSessions"}
        title={t("users.revokeAllSessions")}
        message={t("users.confirmRevokeSessions")}
        danger
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (detail) {
            void act(`/api/v1/admin/users/${detail.id}/revoke-sessions`);
          }
        }}
      />
    </div>
  );
}
