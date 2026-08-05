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
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";

type Review = {
  id: number;
  business_user_id: number;
  author_id: number;
  author_name: string;
  rating: number;
  text: string;
  status: string;
  moderation_note: string;
  company_name: string | null;
  company_reply?: string;
  created_at: string;
  client_ip?: string | null;
  sentiment?: string;
  toxic?: number;
  is_toxic?: boolean;
  fake_flag?: boolean;
  fake_signals?: { same_ip_same_day?: number };
  is_hidden?: boolean;
  hidden_reason?: string;
};

type DecideState = { id: number; approve: boolean } | null;

type StatsResp = {
  business_user_id: number | null;
  company_name: string | null;
  rating_distribution: { buckets: Record<string, number>; total: number };
  pending: number;
  fake_pending: number;
  hidden: number;
  companies: {
    business_user_id: number;
    company_name: string;
    reviews_count: number;
  }[];
};

export default function ReviewsPage() {
  const list = useAdminList<
    Review,
    {
      status: string;
      fake_only: string;
      toxic_only: string;
      business_user_id: string;
    }
  >({
    queryKey: "admin-business-reviews",
    path: "/api/v1/admin/business-reviews",
    initialFilters: {
      status: "pending",
      fake_only: "",
      toxic_only: "",
      business_user_id: "",
    },
  });

  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [toast, setToast] = useState<string | null>(null);
  const [selected, setSelected] = useState<number[]>([]);
  const [chartCompany, setChartCompany] = useState<string>("");

  const statsQ = useQuery({
    queryKey: ["admin-review-stats", chartCompany],
    queryFn: () => {
      const qs = chartCompany
        ? `?business_user_id=${encodeURIComponent(chartCompany)}`
        : "";
      return apiFetch<StatsResp>(`/api/v1/admin/business-reviews/stats${qs}`);
    },
  });

  const buckets = statsQ.data?.rating_distribution.buckets ?? {
    "1": 0,
    "2": 0,
    "3": 0,
    "4": 0,
    "5": 0,
  };
  const maxBucket = useMemo(
    () => Math.max(1, ...Object.values(buckets).map(Number)),
    [buckets],
  );

  function toggleSelect(id: number) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  }

  async function submitDecide(id: number, approve: boolean) {
    if (!approve && rejectNote.trim().length < 3) {
      setActionError(t("reviews.rejectNoteRequired"));
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/business-reviews/${id}/moderate`, {
        method: "POST",
        body: JSON.stringify({
          approve,
          admin_note: approve ? null : rejectNote.trim(),
        }),
      });
      setToast(
        approve
          ? t("reviews.approvedOk", { id })
          : t("reviews.rejectedOk", { id }),
      );
      setRejectNote("");
      setDecide(null);
      setSelected((prev) => prev.filter((x) => x !== id));
      await Promise.all([list.refetch(), statsQ.refetch()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function hideOne(id: number, hide: boolean) {
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/business-reviews/${id}/hide`, {
        method: "POST",
        body: JSON.stringify({
          hide,
          reason: hide ? rejectNote.trim() || t("reviews.hideDefault") : null,
        }),
      });
      setToast(hide ? t("reviews.hiddenOk", { id }) : t("reviews.unhiddenOk", { id }));
      await Promise.all([list.refetch(), statsQ.refetch()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function submitBulk(action: "approve" | "reject" | "hide" | "unhide") {
    if (selected.length === 0) return;
    if (action === "reject" && rejectNote.trim().length < 3) {
      setActionError(t("reviews.rejectNoteRequired"));
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch("/api/v1/admin/business-reviews/bulk", {
        method: "POST",
        body: JSON.stringify({
          review_ids: selected,
          action,
          admin_note:
            action === "reject" || action === "hide"
              ? rejectNote.trim() || t("reviews.hideDefault")
              : null,
        }),
      });
      setToast(t("reviews.bulkOk", { n: selected.length, action }));
      setSelected([]);
      if (action !== "approve" && action !== "unhide") setRejectNote("");
      await Promise.all([list.refetch(), statsQ.refetch()]);
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t("reviews.title")} subtitle={t("reviews.subtitle")}>
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
                <option value="pending">{t("reviews.pending")}</option>
                <option value="approved">{t("reviews.approved")}</option>
                <option value="rejected">{t("reviews.rejected")}</option>
                <option value="hidden">{t("reviews.hidden")}</option>
                <option value="all">{t("app.all")}</option>
              </select>
              <label className="flex items-center gap-1.5 text-xs text-zinc-600">
                <input
                  type="checkbox"
                  checked={list.filters.fake_only === "true"}
                  onChange={(e) =>
                    list.setFilter("fake_only", e.target.checked ? "true" : "")
                  }
                />
                {t("reviews.fakeOnly")}
              </label>
              <label className="flex items-center gap-1.5 text-xs text-zinc-600">
                <input
                  type="checkbox"
                  checked={list.filters.toxic_only === "true"}
                  onChange={(e) =>
                    list.setFilter("toxic_only", e.target.checked ? "true" : "")
                  }
                />
                {t("reviews.toxicOnly")}
              </label>
            </>
          }
        />
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}

      <section className="rounded-xl border bg-white p-4">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-sm font-semibold">{t("reviews.chartTitle")}</h2>
          <select
            value={chartCompany}
            onChange={(e) => setChartCompany(e.target.value)}
            className="rounded-lg border px-3 py-1.5 text-sm"
          >
            <option value="">{t("reviews.chartAll")}</option>
            {(statsQ.data?.companies ?? []).map((c) => (
              <option key={c.business_user_id} value={String(c.business_user_id)}>
                {c.company_name} ({c.reviews_count})
              </option>
            ))}
          </select>
        </div>
        <p className="mb-3 text-xs text-zinc-500">
          {statsQ.data?.company_name
            ? statsQ.data.company_name
            : t("reviews.chartAll")}{" "}
          · {t("reviews.chartTotal", { n: statsQ.data?.rating_distribution.total ?? 0 })}
          {" · "}
          {t("reviews.pendingShort", { n: statsQ.data?.pending ?? 0 })}
          {" · "}
          {t("reviews.fakeShort", { n: statsQ.data?.fake_pending ?? 0 })}
        </p>
        <div className="flex items-end gap-3 h-36">
          {[5, 4, 3, 2, 1].map((star) => {
            const n = Number(buckets[String(star)] || 0);
            const h = Math.round((n / maxBucket) * 100);
            return (
              <div key={star} className="flex flex-1 flex-col items-center gap-1">
                <span className="text-[11px] tabular-nums text-zinc-600">{n}</span>
                <div className="flex h-24 w-full items-end rounded bg-zinc-50">
                  <div
                    className="w-full rounded-t bg-amber-400"
                    style={{ height: `${Math.max(n > 0 ? 8 : 0, h)}%` }}
                  />
                </div>
                <span className="text-xs font-medium">{star}★</span>
              </div>
            );
          })}
        </div>
      </section>

      {selected.length > 0 ? (
        <div className="flex flex-wrap items-center gap-2 rounded-xl border bg-zinc-50 px-4 py-3">
          <span className="text-xs text-zinc-600">
            {t("reviews.bulkSelected", { n: selected.length })}
          </span>
          <button
            type="button"
            disabled={busy}
            onClick={() => void submitBulk("approve")}
            className="rounded bg-emerald-600 px-3 py-1.5 text-xs text-white disabled:opacity-50"
          >
            {t("reviews.bulkApprove")}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void submitBulk("reject")}
            className="rounded border px-3 py-1.5 text-xs disabled:opacity-50"
          >
            {t("reviews.bulkReject")}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void submitBulk("hide")}
            className="rounded border border-amber-300 px-3 py-1.5 text-xs text-amber-900 disabled:opacity-50"
          >
            {t("reviews.bulkHide")}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void submitBulk("unhide")}
            className="rounded border px-3 py-1.5 text-xs disabled:opacity-50"
          >
            {t("reviews.bulkUnhide")}
          </button>
          <textarea
            value={rejectNote}
            onChange={(e) => setRejectNote(e.target.value)}
            placeholder={t("reviews.rejectNotePlaceholder")}
            className="mt-1 w-full rounded-lg border px-3 py-2 text-sm"
            rows={2}
          />
        </div>
      ) : null}

      <ListState
        isLoading={list.isLoading}
        error={list.error}
        isEmpty={list.items.length === 0}
        hasActiveFilters={list.hasActiveFilters}
        onClearFilters={list.clearFilters}
        onRetry={() => void list.refetch()}
        emptyMessage={t("reviews.empty")}
      >
        <div className="space-y-3">
          {list.items.map((item) => (
            <article key={item.id} className="rounded-xl border bg-white p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="flex min-w-0 flex-1 gap-3">
                  <input
                    type="checkbox"
                    className="mt-1"
                    checked={selected.includes(item.id)}
                    onChange={() => toggleSelect(item.id)}
                  />
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">
                      {item.company_name || `User #${item.business_user_id}`}
                    </p>
                    <p className="text-xs text-zinc-500">
                      #{item.id} · {t("reviews.author")}: {item.author_name} (#
                      {item.author_id}) · {formatDate(item.created_at)}
                      {item.client_ip ? ` · IP ${item.client_ip}` : ""}
                    </p>
                    <p className="mt-2 text-amber-700 text-sm font-semibold">
                      {"★".repeat(item.rating)}
                      {"☆".repeat(Math.max(0, 5 - item.rating))} · {item.rating}/5
                    </p>
                    <p className="mt-2 text-sm text-zinc-700 whitespace-pre-wrap">
                      {item.text}
                    </p>
                    {item.company_reply ? (
                      <p className="mt-2 rounded-lg bg-zinc-50 px-3 py-2 text-sm text-zinc-700">
                        <span className="text-xs font-semibold text-zinc-500">
                          {t("reviews.companyReply")}:{" "}
                        </span>
                        {item.company_reply}
                      </p>
                    ) : null}
                    <div className="mt-2 flex flex-wrap gap-1.5 text-[10px]">
                      {item.sentiment ? (
                        <span
                          className={cn(
                            "rounded px-1.5 py-0.5",
                            item.sentiment === "positive" &&
                              "bg-emerald-100 text-emerald-800",
                            item.sentiment === "negative" &&
                              "bg-orange-100 text-orange-800",
                            item.sentiment === "toxic" &&
                              "bg-rose-100 text-rose-800",
                            item.sentiment === "neutral" &&
                              "bg-zinc-100 text-zinc-700",
                          )}
                        >
                          {t("reviews.sentiment", { s: item.sentiment })}
                        </span>
                      ) : null}
                      {item.is_toxic ? (
                        <span className="rounded bg-rose-100 px-1.5 py-0.5 text-rose-800">
                          {t("reviews.toxicFlag", {
                            n: Math.round((item.toxic ?? 0) * 100),
                          })}
                        </span>
                      ) : null}
                      {item.fake_flag ? (
                        <span className="rounded bg-violet-100 px-1.5 py-0.5 text-violet-800">
                          {t("reviews.fakeFlag", {
                            n: item.fake_signals?.same_ip_same_day ?? 2,
                          })}
                        </span>
                      ) : null}
                      {item.is_hidden ? (
                        <span className="rounded bg-amber-100 px-1.5 py-0.5 text-amber-900">
                          {t("reviews.hiddenBadge")}
                        </span>
                      ) : null}
                    </div>
                  </div>
                </div>
                <StatusBadge status={item.is_hidden ? "hidden" : item.status} />
              </div>

              {item.status === "pending" ? (
                <div className="mt-4 space-y-2">
                  <textarea
                    value={
                      decide?.id === item.id && !decide.approve ? rejectNote : ""
                    }
                    onChange={(e) => {
                      setDecide({ id: item.id, approve: false });
                      setRejectNote(e.target.value);
                    }}
                    placeholder={t("reviews.rejectNotePlaceholder")}
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
                      {t("reviews.approve")}
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => {
                        setDecide({ id: item.id, approve: false });
                        if (rejectNote.trim().length < 3) {
                          setActionError(t("reviews.rejectNoteRequired"));
                          return;
                        }
                        void submitDecide(item.id, false);
                      }}
                      className="rounded border px-3 py-1.5 text-sm disabled:opacity-50"
                    >
                      {t("reviews.reject")}
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void hideOne(item.id, true)}
                      className="rounded border border-amber-300 px-3 py-1.5 text-sm text-amber-900 disabled:opacity-50"
                    >
                      {t("reviews.hide")}
                    </button>
                  </div>
                </div>
              ) : null}

              {item.status === "approved" && !item.is_hidden ? (
                <div className="mt-3">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => void hideOne(item.id, true)}
                    className="rounded border border-amber-300 px-3 py-1.5 text-xs text-amber-900 disabled:opacity-50"
                  >
                    {t("reviews.hide")}
                  </button>
                </div>
              ) : null}

              {item.is_hidden ? (
                <div className="mt-3">
                  {item.hidden_reason ? (
                    <p className="mb-2 text-xs text-amber-800">{item.hidden_reason}</p>
                  ) : null}
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => void hideOne(item.id, false)}
                    className="rounded border px-3 py-1.5 text-xs disabled:opacity-50"
                  >
                    {t("reviews.unhide")}
                  </button>
                </div>
              ) : null}

              {item.moderation_note ? (
                <p className="mt-3 text-sm text-rose-600">{item.moderation_note}</p>
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
        title={t("reviews.approve")}
        message={t("reviews.approveHint")}
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitDecide(decide.id, true);
        }}
      />
    </div>
  );
}
