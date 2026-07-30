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
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatDate, planLabel, t } from "@/lib/i18n";
import { useState } from "react";

type UserRow = {
  id: number;
  full_name: string;
  email: string;
  number: string;
  is_active: boolean;
  is_verified: boolean;
  verified_badge: boolean;
  factory_verified?: boolean;
  inspection_passed?: boolean;
  audit_report_url?: string | null;
  deleted_at: string | null;
  plan?: string;
  created_at: string;
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
  subscription: Record<string, unknown> | null;
  recent_payments: PaymentBrief[];
  deletion_reason?: string | null;
};

type ConfirmState =
  | { type: "softDelete"; id: number }
  | { type: "restore"; id: number }
  | { type: "assign"; number: string }
  | { type: "random" }
  | null;

export default function UsersPage() {
  const list = useAdminList<UserRow, { status: string; plan: string }>({
    queryKey: "admin-users",
    path: "/api/v1/admin/users",
    searchParam: "search",
    defaultSort: "id",
    initialFilters: { status: "all", plan: "" },
  });

  const [detail, setDetail] = useState<Detail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmState>(null);
  const [tempPassword, setTempPassword] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [assignNumber, setAssignNumber] = useState("");
  const [applyBonus, setApplyBonus] = useState(false);
  const [forceAssign, setForceAssign] = useState(false);

  async function openDetail(id: number) {
    setDetailLoading(true);
    setTempPassword(null);
    setAssignNumber("");
    setApplyBonus(false);
    setForceAssign(false);
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
            </>
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

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
                <th className="px-4 py-3">{t("users.colPlan")}</th>
                <th className="px-4 py-3">{t("users.colStatus")}</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {list.items.map((u) => (
                <tr key={u.id} className="border-t hover:bg-zinc-50">
                  <td className="px-4 py-3 tabular-nums text-zinc-500">{u.id}</td>
                  <td className="px-4 py-3">
                    <div className="font-medium">{u.full_name}</div>
                    <div className="text-xs text-zinc-500">{u.email}</div>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">{u.number}</td>
                  <td className="px-4 py-3">{u.plan ? planLabel(u.plan) : "—"}</td>
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
      >
        {detailLoading && !detail ? (
          <p className="text-sm text-zinc-500">{t("app.loading")}</p>
        ) : detail ? (
          <>
            <p className="text-sm text-zinc-500">{detail.email}</p>
            <dl className="mt-6 space-y-3 text-sm">
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t("users.drawerNumber")}</dt>
                <dd className="font-mono">{detail.number}</dd>
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
                    onChange={(e) => setAssignNumber(e.target.value.replace(/\D/g, "").slice(0, 7))}
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

            {detail.recent_payments?.length ? (
              <div className="mt-6">
                <h3 className="text-sm font-semibold">{t("users.recentPayments")}</h3>
                <ul className="mt-2 space-y-2">
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
                  <code className="mt-1 block break-all font-mono text-base">{tempPassword}</code>
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
      </Drawer>

      <ConfirmDialog
        open={confirm?.type === "softDelete"}
        title={t("users.softDelete")}
        message={t("users.confirmSoftDelete", { id: confirm?.type === "softDelete" ? confirm.id : 0 })}
        danger
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "softDelete") {
            void act(`/api/v1/admin/users/${confirm.id}/soft-delete`, { reason: "admin_panel" });
          }
        }}
      />
      <ConfirmDialog
        open={confirm?.type === "restore"}
        title={t("users.restoreAccount")}
        message={t("users.confirmRestore", { id: confirm?.type === "restore" ? confirm.id : 0 })}
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
    </div>
  );
}
