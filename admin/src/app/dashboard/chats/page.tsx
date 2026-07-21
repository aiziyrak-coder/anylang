"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatDate, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type ChatRow = {
  id: number;
  user_low_id: number;
  user_high_id: number;
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
  const [userId, setUserId] = useState("");
  const [chats, setChats] = useState<ChatRow[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [messages, setMessages] = useState<Msg[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  async function loadChats() {
    setError(null);
    setLoading(true);
    try {
      const q = new URLSearchParams({ limit: "50" });
      if (userId.trim()) q.set("user_id", userId.trim());
      const res = await apiFetch<{ items: ChatRow[] }>(`/api/v1/admin/chats?${q}`);
      setChats(res.items);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadChats();
  }, []);

  async function openChat(id: number) {
    setSelected(id);
    setError(null);
    try {
      const res = await apiFetch<{ items: Msg[] }>(
        `/api/v1/admin/chats/${id}/messages?limit=200`,
      );
      setMessages(res.items);
    } catch (err) {
      setMessages([]);
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function exportChat(fmt: "json" | "csv") {
    if (!selected || exporting) return;
    setExporting(true);
    setError(null);
    try {
      const { blob, filename } = await apiFetchBlob(
        `/api/v1/admin/chats/${selected}/export?format=${fmt}`,
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
      <PageHeader title={t("chats.title")} subtitle={t("chats.subtitle")} />

      <div className="flex gap-2">
        <input
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          placeholder={t("chats.filterUserId")}
          className="rounded-lg border px-3 py-2 text-sm"
        />
        <button
          type="button"
          disabled={loading}
          onClick={() => void loadChats()}
          className="rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white disabled:opacity-50"
        >
          {loading ? t("app.loading") : t("chats.load")}
        </button>
      </div>

      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="max-h-[70vh] overflow-auto rounded-xl border bg-white">
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-3 py-2 text-left">{t("chats.colChat")}</th>
                <th className="px-3 py-2 text-left">{t("chats.colUsers")}</th>
                <th className="px-3 py-2 text-left">{t("chats.colMsgs")}</th>
              </tr>
            </thead>
            <tbody>
              {chats.map((c) => (
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
                    {c.user_low_id} ↔ {c.user_high_id}
                  </td>
                  <td className="px-3 py-2 tabular-nums">{c.message_count}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!chats.length ? <EmptyState /> : null}
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
            {messages.map((m) => (
              <div key={m.id} className="rounded-lg bg-zinc-50 px-3 py-2 text-sm">
                <div className="text-[10px] text-zinc-500">
                  #{m.id} · {m.sender_id} · {formatDate(m.created_at)}
                  {m.is_deleted ? ` · ${t("chats.deletedMsg")}` : ""}
                </div>
                <div className="mt-1 whitespace-pre-wrap text-zinc-900">
                  {m.text_original || `[${m.type}]`}
                </div>
              </div>
            ))}
            {selected && !messages.length ? <EmptyState /> : null}
          </div>
        </div>
      </div>
    </div>
  );
}
