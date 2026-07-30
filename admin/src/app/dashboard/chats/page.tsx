"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { EmptyState } from "@/components/admin/empty-state";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatDate, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type ChatRow = {
  id: number;
  user_low_id: number | null;
  user_high_id: number | null;
  message_count: number;
  last_preview: string | null;
  last_message_at: string | null;
};

type Msg = {
  id: number;
  sender_id: number;
  type: string;
  text_original: string | null;
  created_at: string;
  is_deleted: boolean;
};

export default function ChatsPage() {
  const router = useRouter();
  const list = useAdminList<ChatRow, { user_id: string }>({
    queryKey: "admin-chats",
    path: "/api/v1/admin/chats",
    defaultSort: "id",
    defaultLimit: 30,
    enabled: isSuperAdmin(),
    initialFilters: { user_id: "" },
  });

  const [selected, setSelected] = useState<number | null>(null);
  const [messages, setMessages] = useState<Msg[]>([]);
  const [msgPage, setMsgPage] = useState(1);
  const [msgTotal, setMsgTotal] = useState(0);
  const [msgHasMore, setMsgHasMore] = useState(false);
  const [msgLoading, setMsgLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  async function openChat(id: number, page = 1) {
    setSelected(id);
    setMsgPage(page);
    setError(null);
    setMsgLoading(true);
    try {
      const res = await apiFetch<{
        items: Msg[];
        total: number;
        has_more: boolean;
        page: number;
      }>(`/api/v1/admin/chats/${id}/messages?page=${page}&limit=50`);
      setMessages(res.items);
      setMsgTotal(res.total);
      setMsgHasMore(res.has_more);
    } catch (err) {
      setMessages([]);
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setMsgLoading(false);
    }
  }

  async function exportChat(fmt: "json" | "csv") {
    if (!selected || exporting) return;
    setExporting(true);
    setError(null);
    try {
      const { blob, filename } = await apiFetchBlob(
        `/api/v1/admin/chats/${selected}/export?format=${fmt}&limit=500`,
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("app.error"));
    } finally {
      setExporting(false);
    }
  }

  if (!isSuperAdmin()) return null;

  return (
    <div className="space-y-6">
      <PageHeader title={t("chats.title")} subtitle={t("chats.subtitle")}>
        <DataToolbar
          search={{
            value: list.q,
            onChange: list.setQ,
            placeholder: t("app.search"),
          }}
          showClear={list.hasActiveFilters}
          onClear={list.clearFilters}
          filters={
            <input
              value={list.filters.user_id}
              onChange={(e) => list.setFilter("user_id", e.target.value.replace(/\D/g, ""))}
              placeholder={t("chats.filterUserId")}
              className="rounded-lg border px-3 py-2 text-sm"
              inputMode="numeric"
            />
          }
        />
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="max-h-[70vh] overflow-auto rounded-xl border bg-white">
          <ListState
            isLoading={list.isLoading}
            error={list.error}
            isEmpty={list.items.length === 0}
            hasActiveFilters={list.hasActiveFilters}
            onClearFilters={list.clearFilters}
            onRetry={() => void list.refetch()}
          >
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 bg-zinc-50 text-xs uppercase text-zinc-500">
                <tr>
                  <SortableTh
                    label={t("chats.colChat")}
                    sortKey="id"
                    sortBy={list.sort}
                    sortDir={list.order}
                    onSort={list.toggleSort}
                  />
                  <th className="px-3 py-2 text-left">{t("chats.colUsers")}</th>
                  <SortableTh
                    label={t("chats.colMsgs")}
                    sortKey="message_count"
                    sortBy={list.sort}
                    sortDir={list.order}
                    onSort={list.toggleSort}
                  />
                </tr>
              </thead>
              <tbody>
                {list.items.map((c) => (
                  <tr
                    key={c.id}
                    className="cursor-pointer border-t hover:bg-zinc-50"
                    onClick={() => void openChat(c.id)}
                  >
                    <td className="px-3 py-2">
                      <div className="font-mono text-xs">#{c.id}</div>
                      {c.last_preview ? (
                        <div className="mt-0.5 max-w-[180px] truncate text-[10px] text-zinc-500">
                          {c.last_preview}
                        </div>
                      ) : null}
                    </td>
                    <td className="px-3 py-2 text-xs">
                      {c.user_low_id ?? "—"} ↔ {c.user_high_id ?? "—"}
                    </td>
                    <td className="px-3 py-2 tabular-nums">{c.message_count}</td>
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

        <div className="flex max-h-[70vh] flex-col rounded-xl border bg-white">
          <div className="flex items-center justify-between border-b px-4 py-3">
            <h2 className="text-sm font-semibold">
              {selected ? t("chats.chatTitle", { id: selected }) : t("chats.selectChat")}
            </h2>
            {selected ? (
              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={exporting}
                  onClick={() => void exportChat("json")}
                  className="rounded border px-2 py-1 text-xs disabled:opacity-40"
                >
                  {exporting ? t("chats.exporting") : t("chats.downloadJson")}
                </button>
                <button
                  type="button"
                  disabled={exporting}
                  onClick={() => void exportChat("csv")}
                  className="rounded border px-2 py-1 text-xs disabled:opacity-40"
                >
                  {t("chats.downloadCsv")}
                </button>
              </div>
            ) : null}
          </div>
          <div className="flex-1 space-y-3 overflow-y-auto p-4">
            {msgLoading ? (
              <p className="text-sm text-zinc-500">{t("app.loading")}</p>
            ) : (
              messages.map((m) => (
                <div key={m.id} className="rounded-lg bg-zinc-50 px-3 py-2 text-sm">
                  <div className="text-[10px] text-zinc-500">
                    #{m.id} · {m.sender_id} · {formatDate(m.created_at)}
                    {m.is_deleted ? ` · ${t("chats.deletedMsg")}` : ""}
                  </div>
                  <div className="mt-1 whitespace-pre-wrap text-zinc-900">
                    {m.text_original || `[${m.type}]`}
                  </div>
                </div>
              ))
            )}
            {selected && !msgLoading && !messages.length ? <EmptyState /> : null}
          </div>
          {selected ? (
            <Pagination
              page={msgPage}
              total={msgTotal}
              hasMore={msgHasMore}
              onPageChange={(p) => void openChat(selected, p)}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
