"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { PageHeader } from "@/components/admin/page-header";
import { StatusBadge } from "@/components/admin/status-badge";
import { ApiError, apiFetch } from "@/lib/api";
import { formatDate, formatNumber, t } from "@/lib/i18n";
import { useCallback, useEffect, useState } from "react";

type Product = {
  id: number;
  name: string;
  price: number | string;
  currency: string;
  category: string;
  image_urls: string[];
  video_url: string | null;
  short_description: string;
  description: string;
};

type Dup = {
  kind: string;
  matched_id: number | null;
  matched_type: string;
  label: string;
};

type AppItem = {
  id: number;
  status: string;
  email: string;
  contact_name: string;
  phone: string | null;
  company_name: string;
  country: string | null;
  business_role: string | null;
  website: string | null;
  bio: string | null;
  description: string | null;
  logo_url: string | null;
  factory_image_urls: string[];
  factory_video_url: string | null;
  admin_note: string | null;
  submitted_at: string | null;
  created_user_id: number | null;
  products: Product[];
  products_count: number;
  duplicates?: Dup[];
  is_duplicate?: boolean;
  gallery_urls?: string[];
  onboarding_checklist?: { id: string; label: string }[];
  welcome_email_sent?: boolean | null;
};

type Board = {
  new: AppItem[];
  review: AppItem[];
  approved: AppItem[];
  rejected: AppItem[];
  counts: Record<string, number>;
};

type AnalyticsSafe = {
  applications: number;
  in_review: number;
  approved: number;
  rejected: number;
  accounts_created: number;
  with_first_listing: number;
  conversion_account_pct: number;
  conversion_listing_pct: number;
  days: number;
};

type DecideState = { id: number; approve: boolean } | null;

type ColumnKey = "new" | "review" | "approved" | "rejected";

export default function PartnerApplicationsPage() {
  const [board, setBoard] = useState<Board | null>(null);
  const [analytics, setAnalytics] = useState<AnalyticsSafe | null>(null);
  const [days, setDays] = useState(30);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [decide, setDecide] = useState<DecideState>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [toast, setToast] = useState<string | null>(null);
  const [openId, setOpenId] = useState<number | null>(null);
  const [zoomUrl, setZoomUrl] = useState<string | null>(null);
  const [checklist, setChecklist] = useState<{ id: string; label: string }[] | null>(
    null,
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [b, a] = await Promise.all([
        apiFetch<Board>("/api/v1/admin/partner-applications/board?per_column=40"),
        apiFetch<AnalyticsSafe>(
          `/api/v1/admin/partner-applications/analytics?days=${days}`,
        ),
      ]);
      setBoard(b);
      setAnalytics(a);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    void load();
  }, [load]);

  async function setStage(id: number, stage: "pending" | "review") {
    setBusy(true);
    setActionError(null);
    try {
      await apiFetch(`/api/v1/admin/partner-applications/${id}/stage`, {
        method: "POST",
        body: JSON.stringify({ stage }),
      });
      setToast(t("app.success"));
      await load();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function submitDecide(id: number, approve: boolean) {
    if (!approve && rejectNote.trim().length < 3) {
      setActionError(t("applications.rejectNoteRequired"));
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      const res = await apiFetch<AppItem>(
        `/api/v1/admin/partner-applications/${id}/decide`,
        {
          method: "POST",
          body: JSON.stringify({
            approve,
            admin_note: approve ? null : rejectNote.trim(),
          }),
        },
      );
      if (approve) {
        setToast(
          res.welcome_email_sent
            ? `${t("applications.approvedOk")} · ${t("applications.welcomeSent")}`
            : `${t("applications.approvedOk")} · ${t("applications.welcomeSkipped")}`,
        );
        if (res.onboarding_checklist?.length) {
          setChecklist(res.onboarding_checklist);
        }
      } else {
        setToast(t("applications.rejectedOk"));
      }
      setRejectNote("");
      setDecide(null);
      setOpenId(null);
      await load();
    } catch (err) {
      setActionError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  function renderCard(item: AppItem, column: ColumnKey) {
    const open = openId === item.id;
    const canDecide = item.status === "pending" || item.status === "review";
    return (
      <article
        key={item.id}
        className={`rounded-xl border bg-white p-3 shadow-sm ${
          item.is_duplicate ? "border-amber-400 ring-1 ring-amber-200" : ""
        }`}
      >
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold">{item.company_name}</p>
            <p className="truncate text-[11px] text-zinc-500">
              #{item.id} · {item.contact_name}
            </p>
            <p className="truncate text-[11px] text-zinc-500">{item.email}</p>
          </div>
          <StatusBadge status={item.status === "pending" ? "pending" : item.status} />
        </div>

        {(item.gallery_urls?.length || item.logo_url) ? (
          <div className="mt-2 flex gap-1 overflow-x-auto">
            {(item.gallery_urls?.length
              ? item.gallery_urls
              : [item.logo_url].filter(Boolean) as string[]
            )
              .slice(0, 5)
              .map((url) => (
                <button
                  key={url}
                  type="button"
                  onClick={() => setZoomUrl(url)}
                  className="h-12 w-12 shrink-0 overflow-hidden rounded border"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={url} alt="" className="h-full w-full object-cover" />
                </button>
              ))}
          </div>
        ) : null}

        <p className="mt-2 text-[11px] text-zinc-500">
          {item.products_count} {t("applications.products")} ·{" "}
          {formatDate(item.submitted_at)}
        </p>

        {item.is_duplicate ? (
          <div className="mt-2 rounded bg-amber-50 px-2 py-1 text-[11px] text-amber-900">
            <p className="font-semibold">{t("applications.duplicates")}</p>
            <ul className="mt-0.5 list-disc pl-3">
              {(item.duplicates ?? []).slice(0, 3).map((d, i) => (
                <li key={`${d.kind}-${d.matched_id}-${i}`}>{d.label}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <div className="mt-2 flex flex-wrap gap-1">
          <button
            type="button"
            className="rounded border px-2 py-1 text-[11px]"
            onClick={() => setOpenId(open ? null : item.id)}
          >
            {open ? t("applications.hide") : t("applications.show")}
          </button>
          {column === "new" ? (
            <button
              type="button"
              disabled={busy}
              className="rounded border border-sky-300 bg-sky-50 px-2 py-1 text-[11px] text-sky-800 disabled:opacity-40"
              onClick={() => void setStage(item.id, "review")}
            >
              {t("applications.moveReview")}
            </button>
          ) : null}
          {column === "review" ? (
            <button
              type="button"
              disabled={busy}
              className="rounded border px-2 py-1 text-[11px] disabled:opacity-40"
              onClick={() => void setStage(item.id, "pending")}
            >
              {t("applications.moveNew")}
            </button>
          ) : null}
        </div>

        {open ? (
          <div className="mt-3 space-y-2 border-t pt-2 text-xs text-zinc-700">
            {item.phone ? <p>Tel: {item.phone}</p> : null}
            {item.bio ? <p>{item.bio}</p> : null}
            {item.description ? (
              <p className="whitespace-pre-wrap text-zinc-600">{item.description}</p>
            ) : null}

            <p className="font-medium">{t("applications.gallery")}</p>
            <div className="flex flex-wrap gap-1">
              {(item.gallery_urls ?? []).map((url) => (
                <button
                  key={url}
                  type="button"
                  onClick={() => setZoomUrl(url)}
                  className="h-16 w-16 overflow-hidden rounded border"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={url} alt="" className="h-full w-full object-cover" />
                </button>
              ))}
            </div>

            <p className="font-medium">{t("applications.products")}</p>
            {item.products.map((p) => (
              <div key={p.id} className="rounded-lg border bg-zinc-50 px-2 py-1.5">
                <p className="font-medium">
                  {p.name} — {String(p.price)} {p.currency}
                </p>
                <div className="mt-1 flex gap-1 overflow-x-auto">
                  {(p.image_urls || []).slice(0, 6).map((url) => (
                    <button
                      key={url}
                      type="button"
                      onClick={() => setZoomUrl(url)}
                      className="h-14 w-14 shrink-0 overflow-hidden rounded border"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt="" className="h-full w-full object-cover" />
                    </button>
                  ))}
                </div>
              </div>
            ))}

            {item.duplicates?.length ? (
              <div>
                <p className="font-medium text-amber-800">{t("applications.duplicates")}</p>
                <ul className="list-disc pl-4 text-amber-900">
                  {item.duplicates.map((d, i) => (
                    <li key={`${d.label}-${i}`}>{d.label}</li>
                  ))}
                </ul>
              </div>
            ) : (
              <p className="text-emerald-700">{t("applications.noDuplicates")}</p>
            )}

            {canDecide ? (
              <div className="space-y-2 pt-1">
                <textarea
                  value={decide?.id === item.id && !decide.approve ? rejectNote : ""}
                  onChange={(e) => {
                    setDecide({ id: item.id, approve: false });
                    setRejectNote(e.target.value);
                  }}
                  placeholder={t("applications.rejectNotePlaceholder")}
                  className="w-full rounded-lg border px-2 py-1.5 text-xs"
                  rows={2}
                />
                <div className="flex flex-wrap gap-1">
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setDecide({ id: item.id, approve: true })}
                    className="rounded bg-emerald-600 px-2.5 py-1.5 text-xs text-white disabled:opacity-50"
                  >
                    {t("applications.approve")}
                  </button>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => {
                      setDecide({ id: item.id, approve: false });
                      if (rejectNote.trim().length < 3) {
                        setActionError(t("applications.rejectNoteRequired"));
                        return;
                      }
                      void submitDecide(item.id, false);
                    }}
                    className="rounded border px-2.5 py-1.5 text-xs disabled:opacity-50"
                  >
                    {t("applications.reject")}
                  </button>
                </div>
              </div>
            ) : null}

            {item.created_user_id ? (
              <p className="text-emerald-700">
                {t("applications.userCreated", { id: item.created_user_id })}
              </p>
            ) : null}
            {item.admin_note ? (
              <p className="text-rose-600">{item.admin_note}</p>
            ) : null}
          </div>
        ) : null}
      </article>
    );
  }

  const columns: { key: ColumnKey; title: string; items: AppItem[]; count: number }[] =
    board
      ? [
          {
            key: "new",
            title: t("applications.pending"),
            items: board.new,
            count: board.counts.new ?? board.counts.pending ?? 0,
          },
          {
            key: "review",
            title: t("applications.review"),
            items: board.review,
            count: board.counts.review ?? 0,
          },
          {
            key: "approved",
            title: t("applications.approved"),
            items: board.approved,
            count: board.counts.approved ?? 0,
          },
          {
            key: "rejected",
            title: t("applications.rejected"),
            items: board.rejected,
            count: board.counts.rejected ?? 0,
          },
        ]
      : [];

  return (
    <div className="space-y-6">
      <PageHeader title={t("applications.title")} subtitle={t("applications.subtitle")}>
        <select
          value={days}
          onChange={(e) => setDays(Number(e.target.value))}
          className="rounded-lg border px-3 py-2 text-sm"
        >
          <option value={7}>{t("applications.days7")}</option>
          <option value={30}>{t("applications.days30")}</option>
          <option value={90}>{t("applications.days90")}</option>
        </select>
        <button
          type="button"
          onClick={() => void load()}
          className="rounded-lg border bg-white px-4 py-2 text-sm hover:bg-zinc-50"
        >
          {t("app.refresh")}
        </button>
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {actionError ? <Alert variant="error">{actionError}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

      {analytics ? (
        <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("applications.analyticsApps")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">
              {formatNumber(analytics.applications)}
            </p>
          </div>
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("applications.analyticsAccounts")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">
              {formatNumber(analytics.accounts_created)}
            </p>
            <p className="mt-1 text-xs text-emerald-700">
              {t("applications.analyticsAccountPct")}: {analytics.conversion_account_pct}%
            </p>
          </div>
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("applications.analyticsListings")}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">
              {formatNumber(analytics.with_first_listing)}
            </p>
            <p className="mt-1 text-xs text-emerald-700">
              {t("applications.analyticsListingPct")}: {analytics.conversion_listing_pct}%
            </p>
          </div>
          <div className="rounded-xl border bg-white p-4">
            <p className="text-xs text-zinc-500">{t("applications.analytics")}</p>
            <p className="mt-1 text-sm text-zinc-600">
              {t("applications.review")}: {formatNumber(analytics.in_review)} ·{" "}
              {t("applications.rejected")}: {formatNumber(analytics.rejected)}
            </p>
          </div>
        </section>
      ) : null}

      {checklist ? (
        <section className="rounded-xl border border-emerald-200 bg-emerald-50 p-4">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-sm font-semibold text-emerald-900">
              {t("applications.onboarding")}
            </h2>
            <button
              type="button"
              className="text-xs text-emerald-800 underline"
              onClick={() => setChecklist(null)}
            >
              {t("app.close")}
            </button>
          </div>
          <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm text-emerald-900">
            {checklist.map((c) => (
              <li key={c.id}>{c.label}</li>
            ))}
          </ol>
        </section>
      ) : null}

      {loading && !board ? (
        <p className="text-sm text-zinc-500">{t("app.loading")}</p>
      ) : (
        <div className="grid gap-4 xl:grid-cols-4">
          {columns.map((col) => (
            <section key={col.key} className="min-h-[420px] rounded-xl border bg-zinc-50/80 p-3">
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-sm font-semibold">{col.title}</h2>
                <span className="rounded-full bg-white px-2 py-0.5 text-xs tabular-nums text-zinc-600">
                  {col.count}
                </span>
              </div>
              <div className="space-y-3">
                {col.items.length === 0 ? (
                  <p className="text-xs text-zinc-400">{t("applications.emptyColumn")}</p>
                ) : (
                  col.items.map((item) => renderCard(item, col.key))
                )}
              </div>
            </section>
          ))}
        </div>
      )}

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
        open={decide?.approve === true}
        title={t("applications.approve")}
        message={t("applications.approveHint")}
        onCancel={() => setDecide(null)}
        onConfirm={() => {
          if (decide) void submitDecide(decide.id, true);
        }}
      />
    </div>
  );
}
