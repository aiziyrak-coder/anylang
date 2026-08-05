"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { Drawer } from "@/components/admin/drawer";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, t } from "@/lib/i18n";
import { useMemo, useState } from "react";

type Doc = {
  id: number;
  doc_type: string;
  url: string;
  file_name: string | null;
  review_status?: string;
  review_note?: string | null;
  checklist?: { id: string; label: string }[];
};

type Macro = { id: string; text: string; uz: string; ru: string; en: string };

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
  age_hours?: number | null;
  sla_breached?: boolean;
  rejection_count?: number;
};

type Detail = Req & {
  history?: {
    id: number;
    status: string;
    admin_note: string | null;
    submitted_at: string | null;
    reviewed_at: string | null;
  }[];
  reject_macros?: Macro[];
};

type DocDecision = {
  review_status: "approved" | "resubmit" | "rejected" | "";
  review_note: string;
  checked: Record<string, boolean>;
};

type ConfirmKind = "approve_all" | "reject_all" | "partial" | null;

function docLabel(docType: string): string {
  const label = t(`verification.doc.${docType}`);
  return label === `verification.doc.${docType}` ? docType : label;
}

function isPdf(url: string, fileName?: string | null) {
  const u = (url || "").toLowerCase();
  const n = (fileName || "").toLowerCase();
  return u.includes(".pdf") || n.endsWith(".pdf");
}

export default function VerificationPage() {
  const list = useAdminList<Req, { status: string; sla_only: string }>({
    queryKey: "admin-verification",
    path: "/api/v1/admin/verification-requests",
    initialFilters: { status: "pending", sla_only: "" },
    defaultSort: "priority",
  });

  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [decisions, setDecisions] = useState<Record<number, DocDecision>>({});
  const [adminNote, setAdminNote] = useState("");
  const [macros, setMacros] = useState<Macro[]>([]);
  const [zoomUrl, setZoomUrl] = useState<string | null>(null);
  const [compareIds, setCompareIds] = useState<number[]>([]);
  const [confirm, setConfirm] = useState<ConfirmKind>(null);

  async function openReview(id: number) {
    setDetailLoading(true);
    setActionError(null);
    setCompareIds([]);
    setZoomUrl(null);
    try {
      const d = await apiFetch<Detail>(`/api/v1/admin/verification-requests/${id}`);
      setDetail(d);
      if (d.reject_macros?.length) setMacros(d.reject_macros);
      const init: Record<number, DocDecision> = {};
      for (const doc of d.documents) {
        init[doc.id] = {
          review_status: "",
          review_note: "",
          checked: Object.fromEntries((doc.checklist ?? []).map((c) => [c.id, false])),
        };
      }
      setDecisions(init);
      setAdminNote("");
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setDetailLoading(false);
    }
  }

  function setDocStatus(docId: number, status: DocDecision["review_status"]) {
    setDecisions((prev) => ({
      ...prev,
      [docId]: { ...prev[docId], review_status: status },
    }));
  }

  function setDocNote(docId: number, note: string) {
    setDecisions((prev) => ({
      ...prev,
      [docId]: { ...prev[docId], review_note: note },
    }));
  }

  function toggleCheck(docId: number, checkId: string) {
    setDecisions((prev) => {
      const cur = prev[docId];
      return {
        ...prev,
        [docId]: {
          ...cur,
          checked: { ...cur.checked, [checkId]: !cur.checked[checkId] },
        },
      };
    });
  }

  function applyMacro(text: string, docId?: number) {
    if (docId != null) {
      setDocNote(docId, text);
      return;
    }
    setAdminNote((prev) => (prev ? `${prev}\n${text}` : text));
  }

  function toggleCompare(docId: number) {
    setCompareIds((prev) => {
      if (prev.includes(docId)) return prev.filter((x) => x !== docId);
      if (prev.length >= 2) return [prev[1], docId];
      return [...prev, docId];
    });
  }

  const compareDocs = useMemo(() => {
    if (!detail || compareIds.length !== 2) return null;
    const a = detail.documents.find((d) => d.id === compareIds[0]);
    const b = detail.documents.find((d) => d.id === compareIds[1]);
    return a && b ? [a, b] : null;
  }, [detail, compareIds]);

  const allDecided =
    detail?.documents.every((d) => decisions[d.id]?.review_status) ?? false;

  async function submitApproveAll() {
    if (!detail) return;
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/verification-requests/${detail.id}/decide`, {
        method: "POST",
        body: JSON.stringify({ approve: true, admin_note: adminNote.trim() || null }),
      });
      setToast(t("app.success"));
      setDetail(null);
      setConfirm(null);
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function submitRejectAll() {
    if (!detail) return;
    if (adminNote.trim().length < 3) {
      setActionError(t("verification.rejectNoteRequired"));
      setConfirm(null);
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/verification-requests/${detail.id}/decide`, {
        method: "POST",
        body: JSON.stringify({ approve: false, admin_note: adminNote.trim() }),
      });
      setToast(t("app.success"));
      setDetail(null);
      setConfirm(null);
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function submitPartial() {
    if (!detail) return;
    if (!allDecided) {
      setActionError(t("verification.allDocsNeeded"));
      setConfirm(null);
      return;
    }
    const payload = detail.documents.map((d) => {
      const dec = decisions[d.id];
      return {
        id: d.id,
        review_status: dec.review_status,
        review_note:
          dec.review_status === "approved" ? null : dec.review_note.trim() || null,
      };
    });
    const needsNote = payload.some((p) => p.review_status !== "approved");
    if (needsNote) {
      for (const p of payload) {
        if (p.review_status !== "approved" && !(p.review_note && p.review_note.length >= 3)) {
          setActionError(t("verification.rejectNoteRequired"));
          setConfirm(null);
          return;
        }
      }
      if (adminNote.trim().length < 3 && !payload.some((p) => p.review_note)) {
        setActionError(t("verification.rejectNoteRequired"));
        setConfirm(null);
        return;
      }
    }
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/verification-requests/${detail.id}/partial`, {
        method: "POST",
        body: JSON.stringify({
          documents: payload,
          admin_note: adminNote.trim() || null,
        }),
      });
      setToast(t("app.success"));
      setDetail(null);
      setConfirm(null);
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("verification.title")} subtitle={t("verification.subtitle")}>
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
                <option value="pending">{t("verification.pending")}</option>
                <option value="needs_resubmit">{t("verification.needsResubmit")}</option>
                <option value="approved">{t("verification.approved")}</option>
                <option value="rejected">{t("verification.rejected")}</option>
                <option value="all">{t("app.all")}</option>
              </select>
              <label className="flex items-center gap-2 rounded-lg border px-3 py-2 text-sm">
                <input
                  type="checkbox"
                  checked={list.filters.sla_only === "1"}
                  onChange={(e) =>
                    list.setFilter("sla_only", e.target.checked ? "1" : "")
                  }
                />
                {t("verification.slaOnly")}
              </label>
            </>
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
            <article
              key={item.id}
              className={`rounded-xl border bg-white p-4 ${
                item.sla_breached
                  ? "border-rose-400 ring-1 ring-rose-200"
                  : ""
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-medium">
                    {item.company_name || `User #${item.user_id}`}
                  </p>
                  <p className="text-xs text-zinc-500">
                    #{item.id} · {item.email} · {item.number} ·{" "}
                    {formatDate(item.submitted_at)}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-2 text-xs">
                    {item.sla_breached ? (
                      <span className="rounded bg-rose-100 px-2 py-0.5 font-semibold text-rose-800">
                        {t("verification.slaBreached", {
                          hours: Math.floor(item.age_hours ?? 24),
                        })}
                      </span>
                    ) : item.age_hours != null ? (
                      <span className="rounded bg-zinc-100 px-2 py-0.5 text-zinc-600">
                        {t("verification.slaOk", { hours: item.age_hours })}
                      </span>
                    ) : null}
                    {(item.rejection_count ?? 0) > 0 ? (
                      <span className="rounded bg-amber-50 px-2 py-0.5 text-amber-800">
                        {t("verification.rejectionHistory", {
                          n: item.rejection_count ?? 0,
                        })}
                      </span>
                    ) : null}
                  </div>
                  {item.note ? (
                    <p className="mt-2 text-sm text-zinc-700">{item.note}</p>
                  ) : null}
                </div>
                <div className="flex flex-col items-end gap-2">
                  <StatusBadge status={item.status} />
                  <button
                    type="button"
                    onClick={() => void openReview(item.id)}
                    className="rounded-lg bg-zinc-900 px-3 py-1.5 text-sm text-white"
                  >
                    {t("verification.openReview")}
                  </button>
                </div>
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                {item.documents.map((doc) => (
                  <span
                    key={doc.id}
                    className="rounded border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-sm text-emerald-800"
                  >
                    {docLabel(doc.doc_type)}
                  </span>
                ))}
              </div>

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

      <Drawer
        open={!!detail || detailLoading}
        onClose={() => {
          setDetail(null);
          setZoomUrl(null);
          setCompareIds([]);
        }}
        title={
          detail
            ? t("verification.reviewTitle", { id: detail.id })
            : t("app.loading")
        }
        width="xl"
      >
        {detailLoading && !detail ? (
          <p className="text-sm text-zinc-500">{t("app.loading")}</p>
        ) : detail ? (
          <div className="space-y-5">
            <div>
              <p className="font-medium">
                {detail.company_name || `User #${detail.user_id}`}
              </p>
              <p className="text-xs text-zinc-500">
                {detail.email} · {detail.number}
              </p>
              <div className="mt-2 flex flex-wrap gap-2 text-xs">
                <StatusBadge status={detail.status} />
                {detail.sla_breached ? (
                  <span className="rounded bg-rose-100 px-2 py-0.5 font-semibold text-rose-800">
                    {t("verification.slaBreached", {
                      hours: Math.floor(detail.age_hours ?? 24),
                    })}
                  </span>
                ) : null}
                <span className="rounded bg-amber-50 px-2 py-0.5 text-amber-800">
                  {t("verification.rejectionHistory", {
                    n: detail.rejection_count ?? 0,
                  })}
                </span>
              </div>
            </div>

            {/* History */}
            <section>
              <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-400">
                {t("verification.historyTitle")}
              </h3>
              {detail.history?.length ? (
                <ul className="mt-2 max-h-28 space-y-1 overflow-y-auto text-xs">
                  {detail.history.map((h) => (
                    <li key={h.id} className="rounded border px-2 py-1.5">
                      #{h.id} · <StatusBadge status={h.status} /> ·{" "}
                      {formatDate(h.reviewed_at || h.submitted_at)}
                      {h.admin_note ? (
                        <span className="mt-0.5 block text-rose-600">{h.admin_note}</span>
                      ) : null}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="mt-2 text-xs text-zinc-500">{t("verification.historyEmpty")}</p>
              )}
            </section>

            {/* Compare strip */}
            {compareDocs ? (
              <section className="rounded-lg border bg-zinc-50 p-3">
                <p className="mb-2 text-xs font-semibold">{t("verification.compare")}</p>
                <div className="grid grid-cols-2 gap-2">
                  {compareDocs.map((doc) => (
                    <div key={doc.id} className="overflow-hidden rounded border bg-white">
                      <p className="border-b px-2 py-1 text-[11px] font-medium">
                        {docLabel(doc.doc_type)}
                      </p>
                      {isPdf(doc.url, doc.file_name) ? (
                        <a
                          href={doc.url}
                          target="_blank"
                          rel="noreferrer"
                          className="block p-6 text-center text-sm underline"
                        >
                          {t("verification.pdfOpen")}
                        </a>
                      ) : (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={doc.url}
                          alt={docLabel(doc.doc_type)}
                          className="h-48 w-full cursor-zoom-in object-contain"
                          onClick={() => setZoomUrl(doc.url)}
                        />
                      )}
                    </div>
                  ))}
                </div>
              </section>
            ) : (
              <p className="text-xs text-zinc-400">{t("verification.compareHint")}</p>
            )}

            {/* Documents */}
            <div className="space-y-4">
              {detail.documents.map((doc) => {
                const dec = decisions[doc.id];
                const selected = compareIds.includes(doc.id);
                return (
                  <div key={doc.id} className="rounded-xl border p-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="text-sm font-semibold">{docLabel(doc.doc_type)}</p>
                      <div className="flex gap-2">
                        <button
                          type="button"
                          onClick={() => toggleCompare(doc.id)}
                          className={`rounded border px-2 py-1 text-xs ${
                            selected ? "border-emerald-500 bg-emerald-50" : ""
                          }`}
                        >
                          {t("verification.compare")}
                        </button>
                        {!isPdf(doc.url, doc.file_name) ? (
                          <button
                            type="button"
                            onClick={() => setZoomUrl(doc.url)}
                            className="rounded border px-2 py-1 text-xs"
                          >
                            {t("verification.zoom")}
                          </button>
                        ) : (
                          <a
                            href={doc.url}
                            target="_blank"
                            rel="noreferrer"
                            className="rounded border px-2 py-1 text-xs"
                          >
                            {t("verification.pdfOpen")}
                          </a>
                        )}
                      </div>
                    </div>

                    {!isPdf(doc.url, doc.file_name) ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={doc.url}
                        alt={docLabel(doc.doc_type)}
                        className="mt-2 max-h-40 w-full cursor-zoom-in rounded object-contain bg-zinc-50"
                        onClick={() => setZoomUrl(doc.url)}
                      />
                    ) : null}

                    <div className="mt-3">
                      <p className="text-[11px] font-semibold uppercase text-zinc-400">
                        {t("verification.checklist")}
                      </p>
                      <ul className="mt-1 space-y-1">
                        {(doc.checklist ?? []).map((c) => (
                          <li key={c.id}>
                            <label className="flex items-start gap-2 text-xs text-zinc-700">
                              <input
                                type="checkbox"
                                checked={!!dec?.checked[c.id]}
                                onChange={() => toggleCheck(doc.id, c.id)}
                                className="mt-0.5"
                              />
                              {c.label}
                            </label>
                          </li>
                        ))}
                      </ul>
                    </div>

                    {detail.status === "pending" ? (
                      <>
                        <div className="mt-3 flex flex-wrap gap-2">
                          {(
                            [
                              ["approved", t("verification.docApprove")],
                              ["resubmit", t("verification.docResubmit")],
                              ["rejected", t("verification.docReject")],
                            ] as const
                          ).map(([st, label]) => (
                            <button
                              key={st}
                              type="button"
                              onClick={() => setDocStatus(doc.id, st)}
                              className={`rounded-lg px-3 py-1.5 text-xs font-medium ${
                                dec?.review_status === st
                                  ? st === "approved"
                                    ? "bg-emerald-600 text-white"
                                    : st === "resubmit"
                                      ? "bg-amber-500 text-white"
                                      : "bg-rose-600 text-white"
                                  : "border"
                              }`}
                            >
                              {label}
                            </button>
                          ))}
                        </div>
                        {dec?.review_status && dec.review_status !== "approved" ? (
                          <div className="mt-2 space-y-2">
                            <textarea
                              value={dec.review_note}
                              onChange={(e) => setDocNote(doc.id, e.target.value)}
                              placeholder={t("verification.docNote")}
                              rows={2}
                              className="w-full rounded-lg border px-3 py-2 text-sm"
                            />
                            <div className="flex flex-wrap gap-1">
                              {(macros.length ? macros : detail.reject_macros ?? []).map(
                                (m) => (
                                  <button
                                    key={m.id}
                                    type="button"
                                    onClick={() => applyMacro(m.text, doc.id)}
                                    className="rounded-full border bg-zinc-50 px-2 py-0.5 text-[10px] text-zinc-700 hover:bg-zinc-100"
                                  >
                                    {m.id}
                                  </button>
                                ),
                              )}
                            </div>
                          </div>
                        ) : null}
                      </>
                    ) : null}
                  </div>
                );
              })}
            </div>

            {detail.status === "pending" ? (
              <section className="space-y-3 border-t pt-4">
                <p className="text-xs font-semibold uppercase text-zinc-400">
                  {t("verification.macros")}
                </p>
                <div className="flex flex-wrap gap-1">
                  {(macros.length ? macros : detail.reject_macros ?? []).map((m) => (
                    <button
                      key={`g-${m.id}`}
                      type="button"
                      onClick={() => applyMacro(m.text)}
                      className="rounded-full border px-2.5 py-1 text-xs hover:bg-zinc-50"
                      title={m.text}
                    >
                      {m.id}
                    </button>
                  ))}
                </div>
                <textarea
                  value={adminNote}
                  onChange={(e) => setAdminNote(e.target.value)}
                  placeholder={t("verification.adminNote")}
                  rows={2}
                  className="w-full rounded-lg border px-3 py-2 text-sm"
                />
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setConfirm("approve_all")}
                    className="rounded-lg bg-emerald-600 px-3 py-2 text-sm text-white disabled:opacity-50"
                  >
                    {t("verification.approve")}
                  </button>
                  <button
                    type="button"
                    disabled={busy || !allDecided}
                    onClick={() => setConfirm("partial")}
                    className="rounded-lg border border-amber-400 bg-amber-50 px-3 py-2 text-sm text-amber-900 disabled:opacity-50"
                  >
                    {t("verification.partialSubmit")}
                  </button>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setConfirm("reject_all")}
                    className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50"
                  >
                    {t("verification.reject")}
                  </button>
                </div>
              </section>
            ) : null}
          </div>
        ) : null}
      </Drawer>

      {/* Zoom lightbox */}
      {zoomUrl ? (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/70 p-4">
          <button
            type="button"
            className="absolute inset-0"
            aria-label={t("app.close")}
            onClick={() => setZoomUrl(null)}
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={zoomUrl}
            alt=""
            className="relative z-10 max-h-[90vh] max-w-[95vw] rounded object-contain shadow-2xl"
          />
        </div>
      ) : null}

      <ConfirmDialog
        open={confirm === "approve_all"}
        title={t("verification.approve")}
        message={t("verification.approveHint")}
        onCancel={() => setConfirm(null)}
        onConfirm={() => void submitApproveAll()}
      />
      <ConfirmDialog
        open={confirm === "reject_all"}
        title={t("verification.reject")}
        message={t("verification.confirmReject")}
        danger
        onCancel={() => setConfirm(null)}
        onConfirm={() => void submitRejectAll()}
      />
      <ConfirmDialog
        open={confirm === "partial"}
        title={t("verification.partialSubmit")}
        message={t("verification.confirmPartial")}
        onCancel={() => setConfirm(null)}
        onConfirm={() => void submitPartial()}
      />
    </div>
  );
}
