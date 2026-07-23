"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { Drawer } from "@/components/admin/drawer";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatDate, planLabel, t } from "@/lib/i18n";
import { useCallback, useEffect, useState } from "react";

type UserRow = {
  id: number;
  full_name: string;
  email: string;
  number: string;
  is_active: boolean;
  is_verified: boolean;
  verified_badge: boolean;
  deleted_at: string | null;
  plan?: string;
  created_at: string;
};

type ListResp = {
  items: UserRow[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
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
  | null;

export default function UsersPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [data, setData] = useState<ListResp | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmState>(null);
  const [tempPassword, setTempPassword] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const q = new URLSearchParams({
        page: String(page),
        limit: "50",
        status,
      });
      if (search.trim()) q.set("search", search.trim());
      const res = await apiFetch<ListResp>(`/api/v1/admin/users?${q}`);
      setData(res);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }, [page, search, status]);

  useEffect(() => {
    const timer = setTimeout(load, 250);
    return () => clearTimeout(timer);
  }, [load]);

  async function openDetail(id: number) {
    setDetailLoading(true);
    setTempPassword(null);
    try {
      const d = await apiFetch<Detail>(`/api/v1/admin/users/${id}/detail`);
      setDetail(d);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
      await load();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
      await load();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
      await load();
      if (detail) await openDetail(detail.id);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
        <input
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
          placeholder={t("users.searchPlaceholder")}
          className="rounded-lg border px-3 py-2 text-sm"
        />
        <select
          value={status}
          onChange={(e) => {
            setPage(1);
            setStatus(e.target.value);
          }}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value="all">{t("users.statusAll")}</option>
          <option value="active">{t("users.statusActive")}</option>
          <option value="inactive">{t("users.statusInactive")}</option>
          <option value="deleted">{t("users.statusDeleted")}</option>
        </select>
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="overflow-hidden rounded-xl border bg-white">
        <table className="min-w-full text-left text-sm">
          <thead className="sticky top-0 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">{t("users.colId")}</th>
              <th className="px-4 py-3">{t("users.colUser")}</th>
              <th className="px-4 py-3">{t("users.colNumber")}</th>
              <th className="px-4 py-3">{t("users.colPlan")}</th>
              <th className="px-4 py-3">{t("users.colStatus")}</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((u) => (
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
        {!data?.items.length ? <EmptyState /> : null}
        {data ? (
          <Pagination
            page={page}
            total={data.total}
            hasMore={data.has_more}
            onPageChange={setPage}
          />
        ) : null}
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
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t("users.verified")}</dt>
                <dd>{detail.is_verified ? t("app.yes") : t("app.no")}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t("users.badge")}</dt>
                <dd>{detail.verified_badge ? t("app.yes") : t("app.no")}</dd>
              </div>
              {detail.deleted_at ? (
                <div className="flex justify-between">
                  <dt className="text-zinc-500">{t("users.drawerDeleted")}</dt>
                  <dd className="text-xs text-amber-700">{formatDate(detail.deleted_at)}</dd>
                </div>
              ) : null}
            </dl>

            {detail.recent_payments?.length ? (
              <div className="mt-6">
                <h3 className="text-sm font-semibold">{t("users.recentPayments")}</h3>
                <ul className="mt-2 space-y-2">
                  {detail.recent_payments.map((p) => (
                    <li key={p.id} className="rounded border px-3 py-2 text-xs">
                      <div className="flex justify-between">
                        <span>#{p.id} · {p.kind}</span>
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
                  <button
                    type="button"
                    className="mt-2 text-xs underline"
                    onClick={() => navigator.clipboard.writeText(tempPassword)}
                  >
                    {t("users.copyPassword")}
                  </button>
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
        message={t("users.confirmSoftDelete", { id: confirm?.id ?? 0 })}
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
        message={t("users.confirmRestore", { id: confirm?.id ?? 0 })}
        onCancel={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm?.type === "restore") {
            void act(`/api/v1/admin/users/${confirm.id}/restore`);
          }
        }}
      />
    </div>
  );
}
