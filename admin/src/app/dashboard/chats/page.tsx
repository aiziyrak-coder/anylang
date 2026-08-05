"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { getAdminProfile } from "@/lib/auth";
import { formatDate, t } from "@/lib/i18n";
import { can } from "@/lib/rbac";
import { useRouter } from "next/navigation";
import { FormEvent, useCallback, useEffect, useState, type ReactNode } from "react";

type ChatHit = {
  id: number;
  user_low_id: number | null;
  user_high_id: number | null;
  message_count: number;
  title: string | null;
};

type Highlight = {
  type: "card" | "phone" | "keyword";
  start: number;
  end: number;
  masked: string | null;
};

type Msg = {
  id: number;
  sender_id: number;
  type: string;
  text_original: string | null;
  created_at: string;
  is_deleted: boolean;
  highlights?: Highlight[];
};

type CaseRow = {
  id: number;
  chat_id: number;
  reason: string;
  description: string;
  status: string;
  decision: string | null;
  source: string;
  search_query: string | null;
  created_at: string | null;
};

type AccessInfo = {
  remaining_seconds?: number;
  expires_at?: string;
  case_id?: number | null;
  reason?: string;
};

type WatchPreset = {
  id: string;
  reason: string;
  label_uz: string;
  label_ru: string;
  label_en: string;
  hint_uz: string;
  keywords: string[];
};

type Tab = "search" | "cases";

const CASE_REASON_OPTIONS = [
  ["extremism", "chats.reasonExtremism"],
  ["terrorism", "chats.reasonTerrorism"],
  ["illegal_trade", "chats.reasonIllegal"],
  ["scam", "chats.reasonScam"],
  ["spam", "chats.reasonSpam"],
  ["harassment", "chats.reasonHarassment"],
  ["pii", "chats.reasonPii"],
  ["other", "chats.reasonOther"],
] as const;

function HighlightedText({ text, highlights }: { text: string; highlights?: Highlight[] }) {
  if (!highlights?.length) {
    return <>{text}</>;
  }
  const parts: ReactNode[] = [];
  let cursor = 0;
  const sorted = [...highlights].sort((a, b) => a.start - b.start);
  sorted.forEach((h, i) => {
    if (h.start > cursor) {
      parts.push(<span key={`t-${i}`}>{text.slice(cursor, h.start)}</span>);
    }
    const slice = text.slice(h.start, h.end);
    const color =
      h.type === "card"
        ? "bg-red-200 text-red-900"
        : h.type === "phone"
          ? "bg-amber-200 text-amber-950"
          : "bg-sky-200 text-sky-950";
    parts.push(
      <mark key={`h-${i}`} className={`rounded px-0.5 ${color}`} title={h.type}>
        {h.masked ?? slice}
      </mark>
    );
    cursor = h.end;
  });
  if (cursor < text.length) {
    parts.push(<span key="tail">{text.slice(cursor)}</span>);
  }
  return <>{parts}</>;
}

export default function ChatsPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("search");

  const [query, setQuery] = useState("");
  const [searchReason, setSearchReason] = useState("");
  const [hits, setHits] = useState<ChatHit[]>([]);
  const [searching, setSearching] = useState(false);

  const [cases, setCases] = useState<CaseRow[]>([]);
  const [caseStatus, setCaseStatus] = useState("open");
  const [casesLoading, setCasesLoading] = useState(false);

  const [selected, setSelected] = useState<number | null>(null);
  const [caseId, setCaseId] = useState<number | null>(null);
  const [accessReason, setAccessReason] = useState("");
  const [access, setAccess] = useState<AccessInfo | null>(null);
  const [remaining, setRemaining] = useState(0);

  const [messages, setMessages] = useState<Msg[]>([]);
  const [msgPage, setMsgPage] = useState(1);
  const [msgTotal, setMsgTotal] = useState(0);
  const [msgHasMore, setMsgHasMore] = useState(false);
  const [msgLoading, setMsgLoading] = useState(false);

  const [exportReason, setExportReason] = useState("");
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const [newCase, setNewCase] = useState({
    chat_id: "",
    reason: "illegal_trade",
    description: "",
    reporter_user_id: "",
    reported_user_id: "",
  });
  const [decideNote, setDecideNote] = useState("");
  const [watchlist, setWatchlist] = useState<WatchPreset[]>([]);
  const [category, setCategory] = useState<string | null>(null);

  useEffect(() => {
    if (!can(getAdminProfile()?.role, "chats")) router.replace("/dashboard");
  }, [router]);

  useEffect(() => {
    void apiFetch<{ items: WatchPreset[] }>("/api/v1/admin/chats/watchlist")
      .then((res) => setWatchlist(res.items ?? []))
      .catch(() => setWatchlist([]));
  }, []);

  const loadCases = useCallback(async () => {
    setCasesLoading(true);
    setError(null);
    try {
      const res = await apiFetch<{ items: CaseRow[] }>(
        `/api/v1/admin/chats/cases?status=${caseStatus}&limit=50`
      );
      setCases(res.items ?? []);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setCasesLoading(false);
    }
  }, [caseStatus]);

  useEffect(() => {
    if (tab === "cases") void loadCases();
  }, [tab, loadCases]);

  useEffect(() => {
    if (!access?.remaining_seconds) {
      setRemaining(0);
      return;
    }
    setRemaining(access.remaining_seconds);
    const tmr = setInterval(() => {
      setRemaining((s) => {
        if (s <= 1) {
          clearInterval(tmr);
          setAccess(null);
          setMessages([]);
          return 0;
        }
        return s - 1;
      });
    }, 1000);
    return () => clearInterval(tmr);
  }, [access?.expires_at, access?.remaining_seconds, selected]);

  async function runSearch(e: FormEvent) {
    e.preventDefault();
    setSearching(true);
    setError(null);
    try {
      const res = await apiFetch<{ items: ChatHit[] }>("/api/v1/admin/chats/search", {
        method: "POST",
        body: JSON.stringify({
          query,
          reason: searchReason,
          category: category || null,
        }),
      });
      setHits(res.items ?? []);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setSearching(false);
    }
  }

  async function openAccess(chatId: number, opts?: { caseId?: number; searchQuery?: string }) {
    setError(null);
    setToast(null);
    const reason = accessReason.trim() || searchReason.trim();
    if (reason.length < 5) {
      setError(t("chats.accessReason"));
      return;
    }
    try {
      const res = await apiFetch<{
        access: AccessInfo;
        case_id: number;
      }>(`/api/v1/admin/chats/${chatId}/access`, {
        method: "POST",
        body: JSON.stringify({
          reason,
          case_id: opts?.caseId ?? null,
          search_query: opts?.searchQuery ?? (query || null),
          category: category || null,
        }),
      });
      setSelected(chatId);
      setCaseId(res.case_id);
      setAccess(res.access);
      setMsgPage(1);
      await loadMessages(chatId, 1);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  function applyPreset(p: WatchPreset) {
    setCategory(p.id);
    setQuery(p.keywords.join(" | "));
    setSearchReason(`${p.label_uz} nazorati`);
    setAccessReason(`${p.label_uz} tekshiruvi`);
    setNewCase((prev) => ({ ...prev, reason: p.reason }));
    setTab("search");
  }

  async function loadMessages(chatId: number, page = 1) {
    setMsgLoading(true);
    setError(null);
    try {
      const res = await apiFetch<{
        items: Msg[];
        total: number;
        has_more: boolean;
        page: number;
        access: AccessInfo;
      }>(`/api/v1/admin/chats/${chatId}/messages?page=${page}&limit=50`);
      setMessages(res.items);
      setMsgTotal(res.total);
      setMsgHasMore(res.has_more);
      setMsgPage(res.page);
      setAccess(res.access);
    } catch (err) {
      setMessages([]);
      if (err instanceof ApiError && err.errorCode === "CHAT_ACCESS_EXPIRED") {
        setAccess(null);
        setError(t("chats.expired"));
      } else {
        setError(err instanceof ApiError ? err.message : t("app.error"));
      }
    } finally {
      setMsgLoading(false);
    }
  }

  async function closeAccess() {
    if (!selected) return;
    try {
      await apiFetch(`/api/v1/admin/chats/${selected}/access`, { method: "DELETE" });
    } catch {
      /* ignore */
    }
    setAccess(null);
    setMessages([]);
    setSelected(null);
  }

  async function exportChat(fmt: "json" | "csv") {
    if (!selected || exporting) return;
    if (exportReason.trim().length < 5) {
      setError(t("chats.exportReason"));
      return;
    }
    setExporting(true);
    setError(null);
    try {
      const { blob, filename } = await apiFetchBlob(`/api/v1/admin/chats/${selected}/export`, {
        method: "POST",
        body: JSON.stringify({ reason: exportReason, format: fmt, limit: 500 }),
      });
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

  async function createCase(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiFetch("/api/v1/admin/chats/cases", {
        method: "POST",
        body: JSON.stringify({
          chat_id: Number(newCase.chat_id),
          reason: newCase.reason,
          description: newCase.description,
          reporter_user_id: newCase.reporter_user_id
            ? Number(newCase.reporter_user_id)
            : null,
          reported_user_id: newCase.reported_user_id
            ? Number(newCase.reported_user_id)
            : null,
          source: "report",
        }),
      });
      setToast(t("app.success"));
      setNewCase({
        chat_id: "",
        reason: "spam",
        description: "",
        reporter_user_id: "",
        reported_user_id: "",
      });
      await loadCases();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  async function decide(caseRow: CaseRow, decision: string) {
    setError(null);
    try {
      await apiFetch(`/api/v1/admin/chats/cases/${caseRow.id}/decide`, {
        method: "POST",
        body: JSON.stringify({ decision, decision_note: decideNote || null }),
      });
      setToast(t("app.success"));
      await loadCases();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    }
  }

  if (!can(getAdminProfile()?.role, "chats")) return null;

  return (
    <div className="space-y-6">
      <PageHeader title={t("chats.title")} subtitle={t("chats.subtitle")} />

      <div className="rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-950 dark:border-amber-800 dark:bg-amber-950/40 dark:text-amber-100">
        {t("chats.noScan")}
      </div>

      {watchlist.length > 0 ? (
        <div className="space-y-2 rounded-xl border bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900">
          <p className="text-sm font-semibold text-zinc-900 dark:text-white">
            {t("chats.watchlistTitle")}
          </p>
          <p className="text-xs text-zinc-600 dark:text-zinc-300">{t("chats.watchlistHint")}</p>
          <div className="flex flex-wrap gap-2">
            {watchlist.map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => applyPreset(p)}
                className={`rounded-full border px-3 py-1.5 text-xs font-medium ${
                  category === p.id
                    ? "border-zinc-900 bg-zinc-900 text-white dark:border-white dark:bg-white dark:text-black"
                    : "border-zinc-300 text-zinc-800 hover:bg-zinc-100 dark:border-zinc-600 dark:text-zinc-100 dark:hover:bg-zinc-800"
                }`}
                title={p.hint_uz}
              >
                {p.label_uz}
              </button>
            ))}
          </div>
        </div>
      ) : null}

      <div className="flex flex-wrap gap-1 border-b pb-2">
        {(
          [
            ["search", "chats.tabSearch"],
            ["cases", "chats.tabCases"],
          ] as const
        ).map(([id, key]) => (
          <button
            key={id}
            type="button"
            onClick={() => setTab(id)}
            className={`rounded-lg px-3 py-1.5 text-sm ${
              tab === id ? "bg-zinc-900 text-white" : "text-zinc-600 hover:bg-zinc-100"
            }`}
          >
            {t(key)}
          </button>
        ))}
      </div>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {toast ? <Alert variant="success">{toast}</Alert> : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="space-y-4">
          {tab === "search" ? (
            <>
              <form
                onSubmit={(e) => void runSearch(e)}
                className="space-y-2 rounded-xl border bg-white p-4"
              >
                <label className="block text-xs font-medium text-zinc-600">
                  {t("chats.searchQuery")}
                  <input
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    required
                    minLength={3}
                  />
                </label>
                <label className="block text-xs font-medium text-zinc-600">
                  {t("chats.searchReason")}
                  <input
                    className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
                    value={searchReason}
                    onChange={(e) => setSearchReason(e.target.value)}
                    required
                    minLength={5}
                  />
                </label>
                <button
                  type="submit"
                  disabled={searching}
                  className="rounded-lg bg-zinc-900 px-3 py-2 text-sm text-white disabled:opacity-50"
                >
                  {searching ? t("app.loading") : t("chats.search")}
                </button>
              </form>

              <div className="max-h-[50vh] overflow-auto rounded-xl border bg-white">
                <div className="border-b px-3 py-2 text-xs font-semibold uppercase text-zinc-500">
                  {t("chats.hits")}
                </div>
                {hits.length === 0 ? (
                  <p className="p-4 text-sm text-zinc-500">{t("chats.noHits")}</p>
                ) : (
                  <table className="min-w-full text-sm">
                    <tbody>
                      {hits.map((c) => (
                        <tr key={c.id} className="border-t hover:bg-zinc-50">
                          <td className="px-3 py-2 font-mono text-xs">#{c.id}</td>
                          <td className="px-3 py-2 text-xs">
                            {c.user_low_id ?? "—"} ↔ {c.user_high_id ?? "—"}
                          </td>
                          <td className="px-3 py-2 tabular-nums">{c.message_count}</td>
                          <td className="px-3 py-2">
                            <button
                              type="button"
                              className="text-xs font-medium text-emerald-700"
                              onClick={() =>
                                void openAccess(c.id, { searchQuery: query })
                              }
                            >
                              {t("chats.openAccess")}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            </>
          ) : (
            <>
              <form
                onSubmit={(e) => void createCase(e)}
                className="space-y-2 rounded-xl border bg-white p-4"
              >
                <h3 className="text-sm font-semibold">{t("chats.createCase")}</h3>
                <div className="grid grid-cols-2 gap-2">
                  <input
                    className="rounded-lg border px-3 py-2 text-sm"
                    placeholder="chat_id"
                    value={newCase.chat_id}
                    onChange={(e) =>
                      setNewCase({ ...newCase, chat_id: e.target.value.replace(/\D/g, "") })
                    }
                    required
                  />
                  <select
                    className="rounded-lg border px-3 py-2 text-sm"
                    value={newCase.reason}
                    onChange={(e) => setNewCase({ ...newCase, reason: e.target.value })}
                  >
                    {CASE_REASON_OPTIONS.map(([value, key]) => (
                      <option key={value} value={value}>
                        {t(key)}
                      </option>
                    ))}
                  </select>
                </div>
                <textarea
                  className="w-full rounded-lg border px-3 py-2 text-sm"
                  rows={2}
                  placeholder={t("chats.caseDesc")}
                  value={newCase.description}
                  onChange={(e) => setNewCase({ ...newCase, description: e.target.value })}
                  required
                  minLength={5}
                />
                <div className="grid grid-cols-2 gap-2">
                  <input
                    className="rounded-lg border px-3 py-2 text-sm"
                    placeholder="reporter user_id"
                    value={newCase.reporter_user_id}
                    onChange={(e) =>
                      setNewCase({
                        ...newCase,
                        reporter_user_id: e.target.value.replace(/\D/g, ""),
                      })
                    }
                  />
                  <input
                    className="rounded-lg border px-3 py-2 text-sm"
                    placeholder="reported user_id"
                    value={newCase.reported_user_id}
                    onChange={(e) =>
                      setNewCase({
                        ...newCase,
                        reported_user_id: e.target.value.replace(/\D/g, ""),
                      })
                    }
                  />
                </div>
                <button
                  type="submit"
                  className="rounded-lg bg-emerald-600 px-3 py-2 text-sm text-white"
                >
                  {t("chats.createCase")}
                </button>
              </form>

              <div className="flex gap-2">
                <select
                  value={caseStatus}
                  onChange={(e) => setCaseStatus(e.target.value)}
                  className="rounded-lg border px-2 py-1.5 text-sm"
                >
                  <option value="open">{t("chats.statusOpen")}</option>
                  <option value="reviewing">{t("chats.statusReviewing")}</option>
                  <option value="decided">{t("chats.statusDecided")}</option>
                </select>
                <button
                  type="button"
                  onClick={() => void loadCases()}
                  className="rounded-lg border px-3 py-1.5 text-sm"
                >
                  {t("app.retry")}
                </button>
              </div>

              <div className="max-h-[50vh] space-y-2 overflow-auto">
                {casesLoading ? (
                  <p className="text-sm text-zinc-500">{t("app.loading")}</p>
                ) : cases.length === 0 ? (
                  <p className="text-sm text-zinc-500">{t("chats.noHits")}</p>
                ) : (
                  cases.map((c) => (
                    <div key={c.id} className="rounded-xl border bg-white p-3 text-sm">
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono text-xs">
                          case #{c.id} · chat #{c.chat_id}
                        </span>
                        <StatusBadge status={c.status === "open" ? "pending" : c.status} />
                      </div>
                      <p className="mt-1 text-xs text-zinc-600">
                        {c.reason}: {c.description}
                      </p>
                      <div className="mt-2 flex flex-wrap gap-2">
                        <button
                          type="button"
                          className="text-xs font-medium text-emerald-700"
                          onClick={() => {
                            setAccessReason(c.description.slice(0, 200));
                            void openAccess(c.chat_id, { caseId: c.id });
                          }}
                        >
                          {t("chats.openAccess")}
                        </button>
                        {c.status !== "decided" ? (
                          <>
                            <button
                              type="button"
                              className="text-xs text-amber-700"
                              onClick={() => void decide(c, "warn")}
                            >
                              {t("chats.decisionWarn")}
                            </button>
                            <button
                              type="button"
                              className="text-xs text-red-700"
                              onClick={() => void decide(c, "ban")}
                            >
                              {t("chats.decisionBan")}
                            </button>
                            <button
                              type="button"
                              className="text-xs text-zinc-600"
                              onClick={() => void decide(c, "dismiss")}
                            >
                              {t("chats.decisionDismiss")}
                            </button>
                          </>
                        ) : (
                          <span className="text-xs text-zinc-500">
                            {c.decision}
                          </span>
                        )}
                      </div>
                    </div>
                  ))
                )}
                <input
                  className="w-full rounded-lg border px-3 py-2 text-sm"
                  placeholder={t("chats.decisionNote")}
                  value={decideNote}
                  onChange={(e) => setDecideNote(e.target.value)}
                />
              </div>
            </>
          )}

          <label className="block rounded-xl border bg-white p-3 text-xs font-medium text-zinc-600">
            {t("chats.accessReason")}
            <input
              className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
              value={accessReason}
              onChange={(e) => setAccessReason(e.target.value)}
              placeholder={t("chats.accessReason")}
            />
          </label>
        </div>

        <div className="flex max-h-[80vh] flex-col rounded-xl border bg-white">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b px-4 py-3">
            <div>
              <h2 className="text-sm font-semibold">
                {selected ? t("chats.chatTitle", { id: selected }) : t("chats.selectChat")}
              </h2>
              {access && remaining > 0 ? (
                <p className="text-xs text-amber-700">
                  {t("chats.remaining", { sec: remaining })}
                  {caseId ? ` · case #${caseId}` : ""}
                </p>
              ) : selected ? (
                <p className="text-xs text-red-600">{t("chats.expired")}</p>
              ) : null}
            </div>
            {selected ? (
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => void closeAccess()}
                  className="rounded border px-2 py-1 text-xs"
                >
                  {t("chats.closeAccess")}
                </button>
              </div>
            ) : null}
          </div>

          {selected && remaining > 0 ? (
            <div className="flex flex-wrap items-end gap-2 border-b px-4 py-2">
              <label className="flex-1 text-xs text-zinc-600">
                {t("chats.exportReason")}
                <input
                  className="mt-1 w-full rounded border px-2 py-1 text-sm"
                  value={exportReason}
                  onChange={(e) => setExportReason(e.target.value)}
                />
              </label>
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

          <div className="flex-1 space-y-3 overflow-y-auto p-4">
            {msgLoading ? (
              <p className="text-sm text-zinc-500">{t("app.loading")}</p>
            ) : (
              messages.map((m) => (
                <div key={m.id} className="rounded-lg bg-zinc-50 px-3 py-2 text-sm">
                  <div className="text-[10px] text-zinc-500">
                    #{m.id} · {m.sender_id} · {formatDate(m.created_at)}
                    {m.is_deleted ? ` · ${t("chats.deletedMsg")}` : ""}
                    {m.highlights?.length ? (
                      <span className="ml-1 text-amber-700">
                        ·{" "}
                        {[...new Set(m.highlights.map((h) => h.type))].join(", ")}
                      </span>
                    ) : null}
                  </div>
                  <div className="mt-1 whitespace-pre-wrap text-zinc-900">
                    {m.text_original ? (
                      <HighlightedText text={m.text_original} highlights={m.highlights} />
                    ) : (
                      `[${m.type}]`
                    )}
                  </div>
                </div>
              ))
            )}
            {selected && !msgLoading && !messages.length ? <EmptyState /> : null}
          </div>
          {selected && remaining > 0 ? (
            <Pagination
              page={msgPage}
              total={msgTotal}
              hasMore={msgHasMore}
              onPageChange={(p) => void loadMessages(selected, p)}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
