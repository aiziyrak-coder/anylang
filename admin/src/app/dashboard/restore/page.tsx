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
  email_otp_verified: boolean;
  number_verified: boolean;
  device_verified: boolean;
  claimed_device_id: string | null;
  claimed_device_name: string | null;
  risk_impersonation: boolean;
  risk_notes: string | null;
  keep_chats: boolean;
  sla_hours: number;
  age_hours: number | null;
  sla_breached: boolean;
  identity_complete: boolean;
  decision_note: string | null;
};

type DecideState = {
  id: number;
  approve: boolean;
  keepChats: boolean;
} | null;

export default function RestorePage() {
  const router = useRouter();
  const list = useAdminList<
    Req,
    { status: string; sla_only: string; risk_only: string }
  >({
    queryKey: "admin-restore",
    path: "/api/v1/admin/restore-requests",
    enabled: isSuperAdmin(),
    initialFilters: { status: "pending", sla_only: "", risk_only: "" },
  });

  const [email, setEmail] = useState("");
  const [reason, setReason] = useState("");
  const [keepChatsCreate, setKeepChatsCreate] = useState(true);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [decideNote, setDecideNote] = useState("");
  const [toast, setToast] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<
    Record<
      number,
      {
        email_otp_verified: boolean;
        number_verified: boolean;
        device_verified: boolean;
        risk_impersonation: boolean;
        risk_notes: string;
        keep_chats: boolean;
      }
    >
  >({});

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  function draftFor(r: Req) {
    return (
      drafts[r.id] ?? {
        email_otp_verified: r.email_otp_verified,
        number_verified: r.number_verified,
        device_verified: r.device_verified,
        risk_impersonation: r.risk_impersonation,
        risk_notes: r.risk_notes ?? "",
        keep_chats: r.keep_chats,
      }
    );
  }

  function setDraft(
    id: number,
    patch: Partial<ReturnType<typeof draftFor>>,
    base: Req,
  ) {
    const cur = drafts[id] ?? {
      email_otp_verified: base.email_otp_verified,
      number_verified: base.number_verified,
      device_verified: base.device_verified,
      risk_impersonation: base.risk_impersonation,
      risk_notes: base.risk_notes ?? "",
      keep_chats: base.keep_chats,
    };
    setDrafts((d) => ({ ...d, [id]: { ...cur, ...patch } }));
  }

  async function saveChecklist(r: Req) {
    const d = draftFor(r);
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/restore-requests/${r.id}`, {
        method: "PATCH",
        body: JSON.stringify({
          email_otp_verified: d.email_otp_verified,
          number_verified: d.number_verified,
          device_verified: d.device_verified,
          risk_impersonation: d.risk_impersonation,
          risk_notes: d.risk_notes || null,
          keep_chats: d.keep_chats,
        }),
      });
      setToast(t("app.success"));
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function notifyUser(id: number) {
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/restore-requests/${id}/notify`, {
        method: "POST",
        body: JSON.stringify({}),
      });
      setToast(t("app.success"));
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function submitDecide() {
    if (!decide) return;
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/restore-requests/${decide.id}/decide`, {
        method: "POST",
        body: JSON.stringify({
          approve: decide.approve,
          note: decideNote || null,
          keep_chats: decide.keepChats,
          require_identity: decide.approve,
          notify: true,
        }),
      });
      setToast(t("app.success"));
      setDecideNote("");
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
        body: JSON.stringify({
          email,
          reason,
          keep_chats: keepChatsCreate,
        }),
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
            <>
              <select
                value={list.filters.status}
                onChange={(e) => list.setFilter("status", e.target.value)}
                className="rounded-lg border px-3 py-2 text-sm"
              >
                <option value="pending">{t("restore.pending")}</option>
                <option value="approved">{t("restore.approved")}</option>
                <option value="rejected">{t("restore.rejected")}</option>
              </select>
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={list.filters.sla_only === "true"}
                  onChange={(e) =>
                    list.setFilter("sla_only", e.target.checked ? "true" : "")
                  }
                />
                {t("restore.slaOnly")}
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={list.filters.risk_only === "true"}
                  onChange={(e) =>
                    list.setFilter("risk_only", e.target.checked ? "true" : "")
                  }
                />
                {t("restore.riskOnly")}
              </label>
            </>
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
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={keepChatsCreate}
              onChange={(e) => setKeepChatsCreate(e.target.checked)}
            />
            {t("restore.keepChats")}
          </label>
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
          {list.items.map((r) => {
            const d = draftFor(r);
            return (
              <article key={r.id} className="rounded-xl border bg-white p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-medium">{r.email}</p>
                      {r.sla_breached ? (
                        <span className="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-800">
                          {t("restore.slaBreached", {
                            hours: r.sla_hours,
                          })}
                        </span>
                      ) : r.status === "pending" ? (
                        <span className="rounded bg-zinc-100 px-2 py-0.5 text-xs text-zinc-600">
                          {t("restore.slaOk", {
                            hours: r.age_hours ?? 0,
                            sla: r.sla_hours,
                          })}
                        </span>
                      ) : null}
                      {r.risk_impersonation || d.risk_impersonation ? (
                        <span className="rounded bg-red-100 px-2 py-0.5 text-xs text-red-800">
                          {t("restore.riskFlag")}
                        </span>
                      ) : null}
                    </div>
                    <p className="text-xs text-zinc-500">
                      {t("restore.userId")} #{r.user_id} · {r.number} ·{" "}
                      {formatDate(r.created_at)}
                      {r.claimed_device_name
                        ? ` · ${t("restore.deviceClaimed")}: ${r.claimed_device_name}`
                        : ""}
                    </p>
                    <p className="mt-2 text-sm text-zinc-700">{r.reason}</p>

                    {r.status === "pending" ? (
                      <div className="mt-4 space-y-3 rounded-lg border border-zinc-100 bg-zinc-50 p-3">
                        <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
                          {t("restore.checklist")}
                        </p>
                        <div className="flex flex-wrap gap-4 text-sm">
                          {(
                            [
                              ["email_otp_verified", "emailOtp"],
                              ["number_verified", "numberVerify"],
                              ["device_verified", "deviceVerify"],
                            ] as const
                          ).map(([key, label]) => (
                            <label key={key} className="flex items-center gap-2">
                              <input
                                type="checkbox"
                                checked={d[key]}
                                onChange={(e) =>
                                  setDraft(r.id, { [key]: e.target.checked }, r)
                                }
                              />
                              {t(`restore.${label}`)}
                            </label>
                          ))}
                        </div>
                        <label className="flex items-center gap-2 text-sm font-medium text-red-700">
                          <input
                            type="checkbox"
                            checked={d.risk_impersonation}
                            onChange={(e) =>
                              setDraft(
                                r.id,
                                { risk_impersonation: e.target.checked },
                                r,
                              )
                            }
                          />
                          {t("restore.riskFlag")}
                        </label>
                        {d.risk_impersonation ? (
                          <input
                            value={d.risk_notes}
                            onChange={(e) =>
                              setDraft(r.id, { risk_notes: e.target.value }, r)
                            }
                            placeholder={t("restore.riskNotes")}
                            className="w-full rounded border px-3 py-2 text-sm"
                          />
                        ) : null}
                        <label className="flex items-center gap-2 text-sm">
                          <input
                            type="checkbox"
                            checked={d.keep_chats}
                            onChange={(e) =>
                              setDraft(r.id, { keep_chats: e.target.checked }, r)
                            }
                          />
                          {d.keep_chats
                            ? t("restore.keepChats")
                            : t("restore.dropChats")}
                        </label>
                        <div className="flex flex-wrap gap-2">
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => void saveChecklist(r)}
                            className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                          >
                            {t("restore.saveChecklist")}
                          </button>
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => void notifyUser(r.id)}
                            className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                          >
                            {t("restore.notify")}
                          </button>
                        </div>
                      </div>
                    ) : null}
                  </div>
                  <div className="flex flex-col gap-2">
                    {r.status === "pending" ? (
                      <>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => {
                            const cur = draftFor(r);
                            if (
                              !(
                                cur.email_otp_verified &&
                                cur.number_verified &&
                                cur.device_verified
                              )
                            ) {
                              setActionError(t("restore.identityIncomplete"));
                              return;
                            }
                            void (async () => {
                              setBusy(true);
                              setActionError(null);
                              try {
                                await apiFetch(
                                  `/api/v1/admin/restore-requests/${r.id}`,
                                  {
                                    method: "PATCH",
                                    body: JSON.stringify({
                                      email_otp_verified: cur.email_otp_verified,
                                      number_verified: cur.number_verified,
                                      device_verified: cur.device_verified,
                                      risk_impersonation: cur.risk_impersonation,
                                      risk_notes: cur.risk_notes || null,
                                      keep_chats: cur.keep_chats,
                                    }),
                                  },
                                );
                                setDecide({
                                  id: r.id,
                                  approve: true,
                                  keepChats: cur.keep_chats,
                                });
                                setDecideNote("");
                              } catch (err) {
                                setActionError(
                                  err instanceof ApiError
                                    ? err.message
                                    : t("app.error"),
                                );
                              } finally {
                                setBusy(false);
                              }
                            })();
                          }}
                          className="rounded bg-emerald-600 px-3 py-1.5 text-sm text-white disabled:opacity-50"
                        >
                          {t("restore.approve")}
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => {
                            setDecide({
                              id: r.id,
                              approve: false,
                              keepChats: draftFor(r).keep_chats,
                            });
                            setDecideNote("");
                          }}
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
            );
          })}
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
        open={decide != null}
        title={decide?.approve ? t("restore.approve") : t("restore.reject")}
        message={
          decide?.approve
            ? t("restore.confirmApprove")
            : t("restore.confirmReject")
        }
        danger={decide?.approve === false}
        onCancel={() => {
          setDecide(null);
          setDecideNote("");
        }}
        onConfirm={() => void submitDecide()}
      >
        <textarea
          value={decideNote}
          onChange={(e) => setDecideNote(e.target.value)}
          placeholder={t("restore.notePlaceholder")}
          className="mt-3 w-full rounded border px-3 py-2 text-sm"
          rows={3}
        />
      </ConfirmDialog>
    </div>
  );
}
