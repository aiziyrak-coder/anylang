"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, t } from "@/lib/i18n";
import { useEffect, useState } from "react";

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

const DOC_LABELS: Record<string, string> = {
  business_license: "Guvohnoma / registratsiya",
  tax_certificate: "STIR / soliq",
  owner_id: "Rahbar ID",
  iso_certificate: "ISO / CE / FDA",
  factory_photo: "Zavod foto",
  audit_report: "Audit report",
};

export default function VerificationPage() {
  const [statusFilter, setStatusFilter] = useState("pending");
  const [items, setItems] = useState<Req[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [toast, setToast] = useState<string | null>(null);

  async function load() {
    try {
      const res = await apiFetch<{ items: Req[] }>(
        `/api/v1/admin/verification-requests?status=${statusFilter}`,
        {},
      );
      setItems(res.items);
      setError(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  useEffect(() => {
    void load();
  }, [statusFilter]);

  async function submitDecide(id: number, approve: boolean) {
    if (!approve && rejectNote.trim().length < 3) {
      setError(t("verification.rejectNoteRequired"));
      return;
    }
    setBusy(true);
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
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
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
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value="pending">{t("verification.pending")}</option>
          <option value="approved">{t("verification.approved")}</option>
          <option value="rejected">{t("verification.rejected")}</option>
          <option value="all">{t("app.all")}</option>
        </select>
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="space-y-3">
        {items.map((item) => (
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
                  {DOC_LABELS[doc.doc_type] || doc.doc_type}
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
                        setError(t("verification.rejectNoteRequired"));
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
        {items.length === 0 ? (
          <EmptyState message={t("app.noData")} />
        ) : null}
      </div>

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
