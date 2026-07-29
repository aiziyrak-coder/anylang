"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { useCallback, useEffect, useState } from "react";

type ProductRow = {
  id: number;
  seller_id: number;
  name: string;
  price: string;
  currency: string;
  category: string;
  status: string;
  is_top_pinned: boolean;
  views_count: number;
  created_at: string;
};

type ListResp = {
  items: ProductRow[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
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
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<ListResp | null>(null);
  const [activeTops, setActiveTops] = useState<TopListResp | null>(null);
  const [queuedTops, setQueuedTops] = useState<TopListResp | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [archiveId, setArchiveId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const q = new URLSearchParams({ page: String(page), limit: "50" });
      if (status) q.set("status", status);
      if (search.trim()) q.set("search", search.trim());
      const res = await apiFetch<ListResp>(`/api/v1/admin/products?${q}`);
      setData(res);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }, [page, search, status]);

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

  useEffect(() => {
    const timer = setTimeout(load, 250);
    return () => clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    void loadTopLists();
  }, [loadTopLists]);

  async function pinProduct(id: number, pinned: boolean) {
    setBusyId(id);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/pin`, {
        method: "POST",
        body: JSON.stringify({ pinned }),
      });
      setToast(pinned ? `#${id} ${t("products.pinned")}` : `#${id} pin olib tashlandi`);
      await Promise.all([load(), loadTopLists()]);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
    }
  }

  async function archiveProduct(id: number) {
    setBusyId(id);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/archive`, {
        method: "POST",
      });
      setToast(`#${id} arxivlandi`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusyId(null);
      setArchiveId(null);
    }
  }

  const slotsUsed = activeTops?.slots_used ?? activeTops?.total ?? 0;
  const maxSlots = activeTops?.max_slots ?? 10;

  return (
    <div className="space-y-6">
      <PageHeader title={t("products.title")} subtitle={t("products.subtitle")}>
        <input
          value={search}
          onChange={(e) => {
            setPage(1);
            setSearch(e.target.value);
          }}
          placeholder={t("products.searchPlaceholder")}
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
          <option value="">{t("products.statusAll")}</option>
          <option value="published">published</option>
          <option value="draft">draft</option>
          <option value="archived">archived</option>
        </select>
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

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
        <table className="min-w-full text-left text-sm">
          <thead className="sticky top-0 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">{t("products.colId")}</th>
              <th className="px-4 py-3">{t("products.colProduct")}</th>
              <th className="px-4 py-3">{t("products.colSeller")}</th>
              <th className="px-4 py-3">{t("products.colPrice")}</th>
              <th className="px-4 py-3">{t("products.colStatus")}</th>
              <th className="px-4 py-3">{t("products.colPin")}</th>
              <th className="px-4 py-3">{t("app.actions")}</th>
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((p) => (
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
        {!data?.items.length ? <EmptyState message={t("app.empty")} /> : null}
        {data ? (
          <Pagination
            page={data.page}
            total={data.total}
            hasMore={data.has_more}
            onPageChange={setPage}
          />
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
    </div>
  );
}
