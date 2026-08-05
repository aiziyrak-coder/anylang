"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { Drawer } from "@/components/admin/drawer";
import { EmptyState } from "@/components/admin/empty-state";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { StatusBadge } from "@/components/admin/status-badge";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch } from "@/lib/api";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { useCallback, useEffect, useState } from "react";

type ProductRow = {
  id: number;
  seller_id: number;
  name: string;
  short_description?: string;
  description?: string;
  price: string;
  currency: string;
  category: string;
  status: string;
  moderation_note?: string;
  is_top_pinned: boolean;
  views_count: number;
  primary_image_url?: string | null;
  image_urls?: string[];
  created_at: string;
};

type TopRequestRow = {
  id: number;
  product_id: number;
  seller_id: number;
  status: string;
  note: string;
  product_name: string | null;
  created_at: string;
  paid_at?: string | null;
  activated_at?: string | null;
  expires_at?: string | null;
  seconds_left?: number | null;
  queue_position?: number | null;
};

type TopListResp = {
  items: TopRequestRow[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
  slots_used?: number;
  max_slots?: number;
  price_usd?: string;
  period_days?: number;
};

type KanbanCard = {
  id: number;
  seller_id: number;
  seller_name?: string | null;
  name: string;
  short_description?: string;
  price: string;
  currency: string;
  category: string;
  ai_risk: number;
  ai_label: string;
  age_hours: number | null;
  sla_breached: boolean;
  primary_image_url?: string | null;
  image_urls?: string[];
};

type KanbanResp = {
  sla_hours: number;
  columns: {
    queue: { title: string; items: KanbanCard[]; total: number };
    ai_flagged: { title: string; items: KanbanCard[]; total: number };
    sla_breached: { title: string; items: KanbanCard[]; total: number };
  };
  reject_macros: { id: string; label: string; text: string }[];
  counts: Record<string, number>;
};

type ModerationDetail = {
  id: number;
  name: string;
  short_description: string;
  description: string;
  price: string;
  currency: string;
  category: string;
  ai_pre_score: Record<string, unknown>;
  ai_risk: number;
  ai_label: string;
  age_hours: number | null;
  sla_breached: boolean;
  image_urls: string[];
  seller: {
    id: number;
    full_name: string;
    email: string;
    number: string;
    company_name?: string | null;
    product_reject_strikes: number;
    listing_restricted: boolean;
    trust_score?: { score?: number; level?: string } | null;
    lifetime_rejects: number;
  } | null;
  side_by_side: {
    images: string[];
    text: Record<string, string | null | undefined>;
  };
  reject_macros: { id: string; label: string; text: string }[];
};

function formatCountdown(seconds: number | null | undefined): string {
  if (seconds == null || seconds < 0) return "—";
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}k ${h}s`;
  if (h > 0) return `${h}s ${m}d`;
  return `${m}d`;
}

export default function ProductsPage() {
  const list = useAdminList<ProductRow, { status: string }>({
    queryKey: "admin-products",
    path: "/api/v1/admin/products",
    searchParam: "search",
    defaultSort: "id",
    initialFilters: { status: "pending" },
  });

  const [activeTops, setActiveTops] = useState<TopListResp | null>(null);
  const [queuedTops, setQueuedTops] = useState<TopListResp | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [archiveId, setArchiveId] = useState<number | null>(null);
  const [decide, setDecide] = useState<{ id: number; approve: boolean } | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [kanban, setKanban] = useState<KanbanResp | null>(null);
  const [selected, setSelected] = useState<number[]>([]);
  const [reviewId, setReviewId] = useState<number | null>(null);
  const [detail, setDetail] = useState<ModerationDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const loadTopLists = useCallback(async () => {
    try {
      const [active, queued] = await Promise.all([
        apiFetch<TopListResp>(`/api/v1/admin/product-top-requests?status=active&limit=50`),
        apiFetch<TopListResp>(`/api/v1/admin/product-top-requests?status=queued&limit=50`),
      ]);
      setActiveTops(active);
      setQueuedTops(queued);
    } catch {
      // non-blocking
    }
  }, []);

  const loadKanban = useCallback(async () => {
    try {
      const data = await apiFetch<KanbanResp>("/api/v1/admin/products/moderation/kanban");
      setKanban(data);
    } catch {
      // non-blocking when not on pending tab
    }
  }, []);

  useEffect(() => {
    void loadTopLists();
  }, [loadTopLists]);

  useEffect(() => {
    if (list.filters.status === "pending") void loadKanban();
  }, [list.filters.status, loadKanban]);

  async function openReview(id: number) {
    setReviewId(id);
    setDetailLoading(true);
    setActionError(null);
    try {
      const d = await apiFetch<ModerationDetail>(
        `/api/v1/admin/products/moderation/${id}`,
      );
      setDetail(d);
      setRejectNote("");
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
      setReviewId(null);
    } finally {
      setDetailLoading(false);
    }
  }

  function toggleSelect(id: number) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  }

  async function pinProduct(id: number, pinned: boolean) {
    setBusyId(id);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/pin`, {
        method: "POST",
        body: JSON.stringify({ pinned }),
      });
      setToast(pinned ? `#${id} ${t("products.pinned")}` : `#${id} pin olib tashlandi`);
      await Promise.all([list.refetch(), loadTopLists()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function archiveProduct(id: number) {
    setBusyId(id);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/archive`, {
        method: "POST",
      });
      setToast(`#${id} arxivlandi`);
      await list.refetch();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
      setArchiveId(null);
    }
  }

  async function submitModerate(id: number, approve: boolean) {
    if (!approve && rejectNote.trim().length < 3) {
      setActionError(t("products.rejectNoteRequired"));
      return;
    }
    setBusyId(id);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/moderate`, {
        method: "POST",
        body: JSON.stringify({
          approve,
          admin_note: approve ? null : rejectNote.trim(),
        }),
      });
      setToast(
        approve
          ? t("products.approvedOk", { id })
          : t("products.rejectedOk", { id }),
      );
      setRejectNote("");
      setDecide(null);
      setReviewId(null);
      setDetail(null);
      await Promise.all([list.refetch(), loadKanban()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function submitBulk(approve: boolean) {
    if (selected.length === 0) return;
    if (!approve && rejectNote.trim().length < 3) {
      setActionError(t("products.rejectNoteRequired"));
      return;
    }
    setBusyId(-1);
    setActionError(null);
    try {
      await apiFetch("/api/v1/admin/products/moderation/bulk", {
        method: "POST",
        body: JSON.stringify({
          product_ids: selected,
          approve,
          admin_note: approve ? null : rejectNote.trim(),
        }),
      });
      setToast(t("app.success"));
      setSelected([]);
      setRejectNote("");
      await Promise.all([list.refetch(), loadKanban()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  const slotsUsed = activeTops?.slots_used ?? activeTops?.total ?? 0;
  const maxSlots = activeTops?.max_slots ?? 10;
  const showModerationCards = list.filters.status === "pending";

  function renderKanbanColumn(
    col: { title: string; items: KanbanCard[]; total: number } | undefined,
  ) {
    if (!col) return null;
    return (
      <div className="min-w-[260px] flex-1 rounded-xl border bg-zinc-50">
        <div className="border-b bg-white px-3 py-2 text-sm font-semibold">
          {col.title}
          <span className="ml-2 text-xs font-normal text-zinc-500">({col.total})</span>
        </div>
        <div className="max-h-[480px] space-y-2 overflow-y-auto p-2">
          {col.items.map((p) => (
            <article
              key={p.id}
              className="rounded-lg border bg-white p-3 shadow-sm"
            >
              <div className="flex items-start gap-2">
                <input
                  type="checkbox"
                  checked={selected.includes(p.id)}
                  onChange={() => toggleSelect(p.id)}
                  className="mt-1"
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{p.name}</p>
                  <p className="text-[11px] text-zinc-500">
                    #{p.id} · {p.seller_name || `seller #${p.seller_id}`} ·{" "}
                    {p.price} {p.currency}
                  </p>
                  <div className="mt-1 flex flex-wrap gap-1 text-[10px]">
                    {p.sla_breached ? (
                      <span className="rounded bg-rose-100 px-1.5 py-0.5 text-rose-800">
                        {t("products.slaBreached")}
                      </span>
                    ) : (
                      <span className="rounded bg-zinc-100 px-1.5 py-0.5 text-zinc-600">
                        {t("products.slaTimer", { hours: p.age_hours ?? 0 })}
                      </span>
                    )}
                    <span className="rounded bg-violet-100 px-1.5 py-0.5 text-violet-800">
                      {t("products.aiRisk", { n: p.ai_risk })}
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => void openReview(p.id)}
                    className="mt-2 text-xs font-medium text-zinc-900 underline"
                  >
                    {t("products.openReview")}
                  </button>
                </div>
                {p.primary_image_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={p.primary_image_url}
                    alt=""
                    className="h-12 w-12 rounded object-cover"
                  />
                ) : null}
              </div>
            </article>
          ))}
          {col.items.length === 0 ? (
            <p className="px-2 py-6 text-center text-xs text-zinc-400">—</p>
          ) : null}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("products.title")} subtitle={t("products.subtitle")}>
        <DataToolbar
          search={{
            value: list.q,
            onChange: list.setQ,
            placeholder: t("products.searchPlaceholder"),
          }}
          showClear={list.hasActiveFilters}
          onClear={list.clearFilters}
          filters={
            <select
              value={list.filters.status}
              onChange={(e) => list.setFilter("status", e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
            >
              <option value="pending">{t("products.statusPending")}</option>
              <option value="published">{t("products.statusPublished")}</option>
              <option value="rejected">{t("products.statusRejected")}</option>
              <option value="draft">{t("products.statusDraft")}</option>
              <option value="archived">{t("products.statusArchived")}</option>
              <option value="">{t("products.statusAll")}</option>
            </select>
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      {showModerationCards ? (
        <section className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-sm font-semibold text-zinc-900">
              {t("products.moderationTitle")}
              <span className="ml-2 text-xs font-normal text-zinc-500">
                ({kanban?.counts?.pending ?? list.total})
              </span>
            </h2>
            {selected.length > 0 ? (
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-xs text-zinc-600">
                  {t("products.bulkSelected", { n: selected.length })}
                </span>
                <button
                  type="button"
                  disabled={busyId === -1}
                  onClick={() => void submitBulk(true)}
                  className="rounded bg-emerald-600 px-3 py-1.5 text-xs text-white disabled:opacity-50"
                >
                  {t("products.bulkApprove")}
                </button>
                <button
                  type="button"
                  disabled={busyId === -1}
                  onClick={() => void submitBulk(false)}
                  className="rounded border px-3 py-1.5 text-xs disabled:opacity-50"
                >
                  {t("products.bulkReject")}
                </button>
              </div>
            ) : null}
          </div>

          {selected.length > 0 || rejectNote ? (
            <div className="space-y-2 rounded-xl border bg-white p-3">
              <p className="text-xs font-medium text-zinc-700">{t("products.rejectMacros")}</p>
              <div className="flex flex-wrap gap-1.5">
                {(kanban?.reject_macros ?? []).map((m) => (
                  <button
                    key={m.id}
                    type="button"
                    onClick={() => setRejectNote(m.text)}
                    className="rounded-full border px-2.5 py-1 text-[11px] hover:bg-zinc-50"
                  >
                    {m.label}
                  </button>
                ))}
              </div>
              <textarea
                value={rejectNote}
                onChange={(e) => setRejectNote(e.target.value)}
                placeholder={t("products.rejectNotePlaceholder")}
                className="w-full rounded-lg border px-3 py-2 text-sm"
                rows={2}
              />
            </div>
          ) : null}

          {kanban ? (
            <div className="flex gap-3 overflow-x-auto pb-2">
              {renderKanbanColumn(kanban.columns.queue)}
              {renderKanbanColumn(kanban.columns.ai_flagged)}
              {renderKanbanColumn(kanban.columns.sla_breached)}
            </div>
          ) : (
            <ListState
              isLoading={list.isLoading}
              error={list.error}
              isEmpty={list.items.length === 0}
              hasActiveFilters={list.hasActiveFilters}
              onClearFilters={list.clearFilters}
              onRetry={() => void list.refetch()}
              emptyMessage={t("products.moderationEmpty")}
            >
              <p className="text-sm text-zinc-500">{t("products.moderationEmpty")}</p>
            </ListState>
          )}
        </section>
      ) : null}

      <div className="rounded-xl border bg-amber-50 px-4 py-3 text-sm text-amber-900">
        {t("products.topPricingHint")} · Slotlar:{" "}
        <span className="font-semibold tabular-nums">
          {slotsUsed}/{maxSlots}
        </span>
      </div>

      <section className="overflow-hidden rounded-xl border bg-white">
        <div className="border-b px-4 py-3">
          <h2 className="text-sm font-semibold text-zinc-900">
            {t("products.topActive")}
            <span className="ml-2 text-xs font-normal text-zinc-500">
              ({activeTops?.total ?? 0})
            </span>
          </h2>
        </div>
        <table className="min-w-full text-left text-sm">
          <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">{t("products.colId")}</th>
              <th className="px-4 py-3">{t("products.colProduct")}</th>
              <th className="px-4 py-3">{t("products.colSeller")}</th>
              <th className="px-4 py-3">{t("products.colExpires")}</th>
              <th className="px-4 py-3">{t("products.colLeft")}</th>
            </tr>
          </thead>
          <tbody>
            {(activeTops?.items ?? []).map((r) => (
              <tr key={r.id} className="border-t hover:bg-zinc-50">
                <td className="px-4 py-3 tabular-nums text-zinc-500">#{r.id}</td>
                <td className="px-4 py-3">
                  <div className="font-medium">{r.product_name ?? `#${r.product_id}`}</div>
                  <div className="text-xs text-zinc-500">product #{r.product_id}</div>
                </td>
                <td className="px-4 py-3 tabular-nums">{r.seller_id}</td>
                <td className="px-4 py-3 text-xs text-zinc-600">
                  {r.expires_at ? new Date(r.expires_at).toLocaleString() : "—"}
                </td>
                <td className="px-4 py-3 tabular-nums font-medium text-amber-800">
                  {formatCountdown(r.seconds_left)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!activeTops?.items.length ? (
          <EmptyState message={t("products.topActiveEmpty")} />
        ) : null}
      </section>

      <section className="overflow-hidden rounded-xl border bg-white">
        <div className="border-b px-4 py-3">
          <h2 className="text-sm font-semibold text-zinc-900">
            {t("products.topQueue")}
            <span className="ml-2 text-xs font-normal text-zinc-500">
              ({queuedTops?.total ?? 0})
            </span>
          </h2>
        </div>
        <table className="min-w-full text-left text-sm">
          <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">{t("products.colQueuePos")}</th>
              <th className="px-4 py-3">{t("products.colId")}</th>
              <th className="px-4 py-3">{t("products.colProduct")}</th>
              <th className="px-4 py-3">{t("products.colSeller")}</th>
              <th className="px-4 py-3">{t("products.colPaidAt")}</th>
            </tr>
          </thead>
          <tbody>
            {(queuedTops?.items ?? []).map((r) => (
              <tr key={r.id} className="border-t hover:bg-zinc-50">
                <td className="px-4 py-3 tabular-nums font-semibold text-blue-700">
                  #{r.queue_position ?? "—"}
                </td>
                <td className="px-4 py-3 tabular-nums text-zinc-500">#{r.id}</td>
                <td className="px-4 py-3">
                  <div className="font-medium">{r.product_name ?? `#${r.product_id}`}</div>
                  <div className="text-xs text-zinc-500">product #{r.product_id}</div>
                </td>
                <td className="px-4 py-3 tabular-nums">{r.seller_id}</td>
                <td className="px-4 py-3 text-xs text-zinc-600">
                  {r.paid_at ? new Date(r.paid_at).toLocaleString() : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!queuedTops?.items.length ? (
          <EmptyState message={t("products.topQueueEmpty")} />
        ) : null}
      </section>

      <div className="overflow-hidden rounded-xl border bg-white">
        {!showModerationCards ? (
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
                  label={t("products.colId")}
                  sortKey="id"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <SortableTh
                  label={t("products.colProduct")}
                  sortKey="name"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <th className="px-4 py-3">{t("products.colSeller")}</th>
                <SortableTh
                  label={t("products.colPrice")}
                  sortKey="price"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <SortableTh
                  label={t("products.colStatus")}
                  sortKey="status"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <th className="px-4 py-3">{t("products.colPin")}</th>
                <th className="px-4 py-3">{t("app.actions")}</th>
              </tr>
            </thead>
            <tbody>
              {list.items.map((p) => (
                <tr key={p.id} className="border-t hover:bg-zinc-50">
                  <td className="px-4 py-3 tabular-nums text-zinc-500">#{p.id}</td>
                  <td className="px-4 py-3">
                    <div className="font-medium">{p.name}</div>
                    <div className="text-xs text-zinc-500">
                      {p.category} · {t("products.views")}: {p.views_count}
                    </div>
                  </td>
                  <td className="px-4 py-3 tabular-nums">{p.seller_id}</td>
                  <td className="px-4 py-3 tabular-nums">
                    {p.price} {p.currency}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={p.status} />
                    {p.status === "rejected" && p.moderation_note ? (
                      <p className="mt-1 max-w-[180px] text-xs text-rose-600">
                        {p.moderation_note}
                      </p>
                    ) : null}
                  </td>
                  <td className="px-4 py-3">
                    {p.is_top_pinned ? (
                      <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
                        TOP
                      </span>
                    ) : (
                      <span className="text-xs text-zinc-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        disabled={busyId === p.id}
                        onClick={() => pinProduct(p.id, !p.is_top_pinned)}
                        className={cn(
                          "rounded border px-2 py-1 text-xs disabled:opacity-40",
                          p.is_top_pinned && "border-amber-300 text-amber-800",
                        )}
                      >
                        {p.is_top_pinned ? t("products.unpin") : t("products.pin")}
                      </button>
                      <button
                        type="button"
                        disabled={busyId === p.id}
                        onClick={() => setArchiveId(p.id)}
                        className="rounded border border-red-200 px-2 py-1 text-xs text-red-700 disabled:opacity-40"
                      >
                        {t("products.archive")}
                      </button>
                    </div>
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
        ) : null}
      </div>

      <ConfirmDialog
        open={archiveId != null}
        title={t("products.confirmArchive", { id: archiveId ?? 0 })}
        message={t("products.confirmArchive", { id: archiveId ?? 0 })}
        danger
        onCancel={() => setArchiveId(null)}
        onConfirm={() => {
          if (archiveId != null) void archiveProduct(archiveId);
        }}
      />
      <ConfirmDialog
        open={decide?.approve === true}
        title={t("products.approve")}
        message={t("products.approveHint")}
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitModerate(decide.id, true);
        }}
      />

      <Drawer
        open={reviewId != null}
        onClose={() => {
          setReviewId(null);
          setDetail(null);
        }}
        title={detail ? `#${detail.id} ${detail.name}` : t("products.openReview")}
        width="xl"
      >
        {detailLoading ? (
          <p className="p-5 text-sm text-zinc-500">…</p>
        ) : detail ? (
          <div className="space-y-4 overflow-y-auto p-5">
            <div className="flex flex-wrap gap-2 text-[11px]">
              {detail.sla_breached ? (
                <span className="rounded bg-rose-100 px-2 py-0.5 text-rose-800">
                  {t("products.slaBreached")}
                </span>
              ) : (
                <span className="rounded bg-zinc-100 px-2 py-0.5">
                  {t("products.slaTimer", { hours: detail.age_hours ?? 0 })}
                </span>
              )}
              <span className="rounded bg-violet-100 px-2 py-0.5 text-violet-800">
                {t("products.aiRisk", { n: detail.ai_risk })} · {detail.ai_label}
              </span>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <h3 className="mb-2 text-xs font-semibold uppercase text-zinc-500">
                  {t("products.sideImages")}
                </h3>
                <div className="flex flex-wrap gap-2">
                  {(detail.side_by_side.images.length
                    ? detail.side_by_side.images
                    : detail.image_urls
                  ).map((url) => (
                    <a
                      key={url}
                      href={url}
                      target="_blank"
                      rel="noreferrer"
                      className="block h-24 w-24 overflow-hidden rounded-lg border"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt="" className="h-full w-full object-cover" />
                    </a>
                  ))}
                  {!detail.image_urls.length ? (
                    <p className="text-xs text-zinc-400">—</p>
                  ) : null}
                </div>
              </div>
              <div>
                <h3 className="mb-2 text-xs font-semibold uppercase text-zinc-500">
                  {t("products.sideText")}
                </h3>
                <p className="text-sm font-medium">{detail.name}</p>
                <p className="mt-1 text-xs text-zinc-500">
                  {detail.price} {detail.currency} · {detail.category}
                </p>
                <p className="mt-2 text-sm text-zinc-700">
                  {detail.short_description || "—"}
                </p>
                <p className="mt-2 max-h-40 overflow-y-auto whitespace-pre-wrap text-sm text-zinc-600">
                  {detail.description || "—"}
                </p>
              </div>
            </div>

            {detail.seller ? (
              <div className="rounded-lg border bg-zinc-50 p-3 text-sm">
                <p className="font-medium">{t("products.sellerTrust")}</p>
                <p className="mt-1 text-zinc-700">
                  {detail.seller.full_name} · #{detail.seller.id}
                  {detail.seller.company_name
                    ? ` · ${detail.seller.company_name}`
                    : ""}
                </p>
                <p className="text-xs text-zinc-500">
                  {detail.seller.email} · {detail.seller.number}
                </p>
                <div className="mt-2 flex flex-wrap gap-2 text-[11px]">
                  <span className="rounded bg-white px-2 py-0.5 border">
                    {t("products.sellerStrikes", {
                      n: detail.seller.product_reject_strikes,
                    })}
                  </span>
                  {detail.seller.listing_restricted ? (
                    <span className="rounded bg-rose-100 px-2 py-0.5 text-rose-800">
                      {t("products.listingRestricted")}
                    </span>
                  ) : null}
                  {detail.seller.trust_score?.score != null ? (
                    <span className="rounded bg-white px-2 py-0.5 border">
                      Trust {detail.seller.trust_score.score}
                      {detail.seller.trust_score.level
                        ? ` (${detail.seller.trust_score.level})`
                        : ""}
                    </span>
                  ) : null}
                  <span className="rounded bg-white px-2 py-0.5 border">
                    Lifetime reject: {detail.seller.lifetime_rejects}
                  </span>
                </div>
              </div>
            ) : null}

            <div className="space-y-2">
              <p className="text-xs font-medium">{t("products.rejectMacros")}</p>
              <div className="flex flex-wrap gap-1.5">
                {(detail.reject_macros ?? []).map((m) => (
                  <button
                    key={m.id}
                    type="button"
                    onClick={() => setRejectNote(m.text)}
                    className="rounded-full border px-2.5 py-1 text-[11px] hover:bg-zinc-50"
                  >
                    {m.label}
                  </button>
                ))}
              </div>
              <textarea
                value={rejectNote}
                onChange={(e) => setRejectNote(e.target.value)}
                placeholder={t("products.rejectNotePlaceholder")}
                className="w-full rounded-lg border px-3 py-2 text-sm"
                rows={3}
              />
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={busyId === detail.id}
                  onClick={() => setDecide({ id: detail.id, approve: true })}
                  className="rounded bg-emerald-600 px-3 py-1.5 text-sm text-white disabled:opacity-50"
                >
                  {t("products.approve")}
                </button>
                <button
                  type="button"
                  disabled={busyId === detail.id}
                  onClick={() => void submitModerate(detail.id, false)}
                  className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                >
                  {t("products.reject")}
                </button>
              </div>
            </div>
          </div>
        ) : null}
      </Drawer>
    </div>
  );
}
