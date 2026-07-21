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

export default function ProductsPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<ListResp | null>(null);
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

  useEffect(() => {
    const timer = setTimeout(load, 250);
    return () => clearTimeout(timer);
  }, [load]);

  async function pinProduct(id: number, pinned: boolean) {
    setBusyId(id);
    try {
      await apiFetch(`/api/v1/admin/products/${id}/pin`, {
        method: "POST",
        body: JSON.stringify({ pinned }),
      });
      setToast(pinned ? `#${id} ${t("products.pinned")}` : `#${id} pin olib tashlandi`);
      await load();
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
                <td className="px-4 py-3 tabular-nums text-zinc-500">{p.id}</td>
                <td className="px-4 py-3">
                  <div className="font-medium">{p.name}</div>
                  <div className="text-xs text-zinc-500">
                    {p.category} · {t("products.views")}: {p.views_count}
                  </div>
                </td>
                <td className="px-4 py-3 tabular-nums">{p.seller_id}</td>
                <td className="px-4 py-3 font-medium">
                  {p.price} {p.currency}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={p.status} />
                </td>
                <td className="px-4 py-3">
                  {p.is_top_pinned ? (
                    <span className="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-800">
                      {t("products.pinned")}
                    </span>
                  ) : (
                    <span className="text-xs text-zinc-400">—</span>
                  )}
                </td>
                <td className="px-4 py-3">
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      disabled={busyId === p.id || p.status === "archived"}
                      onClick={() => pinProduct(p.id, !p.is_top_pinned)}
                      className={cn(
                        "rounded border px-2 py-1 text-xs disabled:opacity-40",
                        p.is_top_pinned && "border-amber-300 text-amber-800",
                      )}
                    >
                      {p.is_top_pinned ? t("products.unpin") : t("products.pin")}
                    </button>
                    {p.status !== "archived" ? (
                      <button
                        type="button"
                        disabled={busyId === p.id}
                        onClick={() => setArchiveId(p.id)}
                        className="rounded border border-red-200 px-2 py-1 text-xs text-red-700 disabled:opacity-40"
                      >
                        {t("products.archive")}
                      </button>
                    ) : null}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data?.items.length ? <EmptyState /> : null}
        {data ? (
          <Pagination page={page} total={data.total} hasMore={data.has_more} onPageChange={setPage} />
        ) : null}
      </div>

      <ConfirmDialog
        open={archiveId !== null}
        title={t("products.archive")}
        message={t("products.confirmArchive", { id: archiveId ?? 0 })}
        danger
        onCancel={() => setArchiveId(null)}
        onConfirm={() => {
          if (archiveId) void archiveProduct(archiveId);
        }}
      />
    </div>
  );
}
