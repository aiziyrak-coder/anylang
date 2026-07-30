"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatDate, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type Req = {
  id: number;
  user_id: number | null;
  email: string;
  number: string | null;
  reason: string;
  status: string;
  created_at: string;
};

type DecideState = { id: number; approve: boolean } | null;

export default function RestorePage() {
  const router = useRouter();
  const list = useAdminList<Req, { status: string }>({
    queryKey: "admin-restore",
    path: "/api/v1/admin/restore-requests",
    enabled: isSuperAdmin(),
    initialFilters: { status: "pending" },
  });

  const [email, setEmail] = useState("");
  const [reason, setReason] = useState("");
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  async function submitDecide(id: number, approve: boolean) {
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/restore-requests/${id}/decide`, {
        method: "POST",
        body: JSON.stringify({ approve }),
      });
      setToast(t("app.success"));
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
      setDecide(null);
    }
  }

  async function create() {
    if (!email.trim() || reason.trim().length < 5) return;
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch("/api/v1/admin/restore-requests", {
        method: "POST",
        body: JSON.stringify({ email, reason }),
      });
      setEmail("");
      setReason("");
      setToast(t("app.success"));
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  if (!isSuperAdmin()) return null;

  return (
    <div className="space-y-6">
      <PageHeader title={t("restore.title")} subtitle={t("restore.subtitle")}>
        <DataToolbar
          search={{
            value: list.q,
            onChange: list.setQ,
            placeholder: t("app.search"),
          }}
          showClear={list.hasActiveFilters}
          onClear={list.clearFilters}
          filters={
            <select
              value={list.filters.status}
              onChange={(e) => list.setFilter("status", e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
            >
              <option value="pending">{t("restore.pending")}</option>
              <option value="approved">{t("restore.approved")}</option>
              <option value="rejected">{t("restore.rejected")}</option>
            </select>
          }
        />
      </PageHeader>

      <div className="rounded-xl border bg-white p-4">
        <h2 className="text-sm font-semibold">{t("restore.fileRequest")}</h2>
        <div className="mt-3 flex flex-wrap gap-2">
          <input
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder={t("restore.email")}
            className="rounded border px-3 py-2 text-sm"
          />
          <input
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={t("restore.reasonPlaceholder")}
            className="min-w-[240px] flex-1 rounded border px-3 py-2 text-sm"
          />
          <button
            type="button"
            disabled={busy}
            onClick={() => void create()}
            className="rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white disabled:opacity-50"
          >
            {t("restore.submit")}
          </button>
        </div>
      </div>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      <ListState
        isLoading={list.isLoading}
        error={list.error}
        isEmpty={list.items.length === 0}
        emptyMessage={t("restore.empty")}
        hasActiveFilters={list.hasActiveFilters}
        onClearFilters={list.clearFilters}
        onRetry={() => void list.refetch()}
      >
        <div className="space-y-3">
          {list.items.map((r) => (
            <article key={r.id} className="rounded-xl border bg-white p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-medium">{r.email}</p>
                  <p className="text-xs text-zinc-500">
                    {t("restore.userId")} #{r.user_id} · {r.number} ·{" "}
                    {formatDate(r.created_at)}
                  </p>
                  <p className="mt-2 text-sm text-zinc-700">{r.reason}</p>
                </div>
                <div className="flex gap-2">
                  {r.status === "pending" ? (
                    <>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => setDecide({ id: r.id, approve: true })}
                        className="rounded bg-emerald-600 px-3 py-1.5 text-sm text-white disabled:opacity-50"
                      >
                        {t("restore.approve")}
                      </button>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => setDecide({ id: r.id, approve: false })}
                        className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                      >
                        {t("restore.reject")}
                      </button>
                    </>
                  ) : (
                    <StatusBadge status={r.status} />
                  )}
                </div>
              </div>
            </article>
          ))}
        </div>
        <div className="overflow-hidden rounded-xl border bg-white">
          <Pagination
            page={list.page}
            total={list.total}
            hasMore={list.hasMore}
            onPageChange={list.setPage}
            limit={list.limit}
            onLimitChange={list.setLimit}
          />
        </div>
      </ListState>

      <ConfirmDialog
        open={decide?.approve === true}
        title={t("restore.approve")}
        message={t("restore.confirmApprove")}
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitDecide(decide.id, true);
        }}
      />
      <ConfirmDialog
        open={decide?.approve === false}
        title={t("restore.reject")}
        message={t("restore.confirmReject")}
        danger
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitDecide(decide.id, false);
        }}
      />
    </div>
  );
}
