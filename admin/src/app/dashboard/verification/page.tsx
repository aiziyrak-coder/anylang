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
import { formatDate, t } from "@/lib/i18n";
import { useState } from "react";

type Doc = {
  id: number;
  doc_type: string;
  url: string;
  file_name: string | null;
};

type Req = {
  id: number;
  status: string;
  user_id: number;
  business_id: number;
  company_name: string | null;
  email: string | null;
  number: string | null;
  note: string | null;
  admin_note: string | null;
  submitted_at: string | null;
  reviewed_at: string | null;
  documents: Doc[];
  documents_verified: boolean;
  verified_badge: boolean;
};

type DecideState = { id: number; approve: boolean } | null;

function docLabel(docType: string): string {
  const label = t(`verification.doc.${docType}`);
  return label === `verification.doc.${docType}` ? docType : label;
}

export default function VerificationPage() {
  const list = useAdminList<Req, { status: string }>({
    queryKey: "admin-verification",
    path: "/api/v1/admin/verification-requests",
    initialFilters: { status: "pending" },
  });

  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [toast, setToast] = useState<string | null>(null);

  async function submitDecide(id: number, approve: boolean) {
    if (!approve && rejectNote.trim().length < 3) {
      setActionError(t("verification.rejectNoteRequired"));
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/verification-requests/${id}/decide`, {
        method: "POST",
        body: JSON.stringify({
          approve,
          admin_note: approve ? null : rejectNote.trim(),
        }),
      });
      setToast(t("app.success"));
      setRejectNote("");
      setDecide(null);
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("verification.title")}
        subtitle={t("verification.subtitle")}
      >
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
              <option value="pending">{t("verification.pending")}</option>
              <option value="approved">{t("verification.approved")}</option>
              <option value="rejected">{t("verification.rejected")}</option>
              <option value="all">{t("app.all")}</option>
            </select>
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      <ListState
        isLoading={list.isLoading}
        error={list.error}
        isEmpty={list.items.length === 0}
        hasActiveFilters={list.hasActiveFilters}
        onClearFilters={list.clearFilters}
        onRetry={() => void list.refetch()}
      >
        <div className="space-y-3">
          {list.items.map((item) => (
            <article key={item.id} className="rounded-xl border bg-white p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-medium">
                    {item.company_name || `User #${item.user_id}`}
                  </p>
                  <p className="text-xs text-zinc-500">
                    #{item.id} · {item.email} · {item.number} ·{" "}
                    {formatDate(item.submitted_at)}
                  </p>
                  {item.note ? (
                    <p className="mt-2 text-sm text-zinc-700">{item.note}</p>
                  ) : null}
                </div>
                <StatusBadge status={item.status} />
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                {item.documents.map((doc) => (
                  <a
                    key={doc.id}
                    href={doc.url}
                    target="_blank"
                    rel="noreferrer"
                    className="rounded border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-sm text-emerald-800"
                  >
                    {docLabel(doc.doc_type)}
                  </a>
                ))}
              </div>

              {item.status === "pending" ? (
                <div className="mt-4 space-y-2">
                  <textarea
                    value={decide?.id === item.id && !decide.approve ? rejectNote : ""}
                    onChange={(e) => {
                      setDecide({ id: item.id, approve: false });
                      setRejectNote(e.target.value);
                    }}
                    placeholder={t("verification.rejectNotePlaceholder")}
                    className="w-full rounded-lg border px-3 py-2 text-sm"
                    rows={2}
                  />
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => setDecide({ id: item.id, approve: true })}
                      className="rounded bg-emerald-600 px-3 py-1.5 text-sm text-white disabled:opacity-50"
                    >
                      {t("verification.approve")}
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => {
                        setDecide({ id: item.id, approve: false });
                        if (rejectNote.trim().length < 3) {
                          setActionError(t("verification.rejectNoteRequired"));
                          return;
                        }
                        void submitDecide(item.id, false);
                      }}
                      className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                    >
                      {t("verification.reject")}
                    </button>
                  </div>
                </div>
              ) : null}

              {item.admin_note ? (
                <p className="mt-3 text-sm text-rose-600">{item.admin_note}</p>
              ) : null}
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
        title={t("verification.approve")}
        message={t("verification.approveHint")}
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitDecide(decide.id, true);
        }}
      />
    </div>
  );
}
