"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { LoadingGrid } from "@/components/admin/loading-grid";
import { PageHeader } from "@/components/admin/page-header";
import { StatCard } from "@/components/admin/stat-card";
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatNumber, t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

type Stats = {
  users_total: number;
  users_active: number;
  subscriptions_active: number;
  products_published: number;
  products_archived: number;
  chats_total: number;
  messages_total: number;
  messages_total_approx?: boolean;
  number_groups_total: number;
};

type HealthCheck = { status: string; latency_ms?: number; error?: string };
type HealthResp = {
  status: string;
  checked_at: string;
  checks: Record<string, HealthCheck>;
};

type Flags = {
  maintenance_mode: boolean;
  region_off: string[];
  push_enabled: boolean;
  translate_enabled: boolean;
  payments_enabled: boolean;
};

type QueuesResp = {
  checked_at: string;
  queues: Record<
    string,
    {
      status?: string;
      queue_depth?: number;
      in_progress_approx?: number;
      pending_catalog_approx?: number;
      arq_queue_depth?: number | null;
      pending?: number;
      failed_or_refund?: number;
      enabled?: boolean;
      error?: string;
    }
  >;
};

type ErrorSpike = {
  hours: number;
  total: number;
  last_hour: number;
  prev_hour: number;
  spike: boolean;
  timeline: { hour: string | null; count: number }[];
  top: {
    fingerprint: string;
    error_code: string;
    message: string;
    path: string;
    count: number;
    last_seen: string | null;
  }[];
};

type DryRun = {
  eligible: number;
  sample: { id: number; email: string; number: string }[];
  confirm_token: string;
  expires_in_seconds: number;
};

function statusTone(s?: string) {
  if (s === "ok") return "bg-emerald-100 text-emerald-800";
  if (s === "degraded" || s === "busy" || s === "spike")
    return "bg-amber-100 text-amber-900";
  if (s === "fail") return "bg-rose-100 text-rose-800";
  return "bg-zinc-100 text-zinc-700";
}

export default function MaintenancePage() {
  const router = useRouter();
  const [stats, setStats] = useState<Stats | null>(null);
  const [health, setHealth] = useState<HealthResp | null>(null);
  const [flags, setFlags] = useState<Flags | null>(null);
  const [queues, setQueues] = useState<QueuesResp | null>(null);
  const [errors, setErrors] = useState<ErrorSpike | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [counting, setCounting] = useState(false);
  const [exactMessages, setExactMessages] = useState<number | null>(null);
  const [dryRun, setDryRun] = useState<DryRun | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [regionInput, setRegionInput] = useState("");

  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, h, f, q, e] = await Promise.all([
        apiFetch<Stats>("/api/v1/admin/stats"),
        apiFetch<HealthResp>("/api/v1/admin/maintenance/health"),
        apiFetch<{ flags: Flags }>("/api/v1/admin/maintenance/feature-flags"),
        apiFetch<QueuesResp>("/api/v1/admin/maintenance/job-queues"),
        apiFetch<ErrorSpike>("/api/v1/admin/maintenance/error-spikes?hours=24"),
      ]);
      setStats(s);
      setHealth(h);
      setFlags(f.flags);
      setRegionInput((f.flags.region_off || []).join(", "));
      setQueues(q);
      setErrors(e);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  useEffect(() => {
    if (isSuperAdmin()) void loadAll();
  }, [loadAll]);

  async function saveFlags(patch: Partial<Flags>) {
    setBusy(true);
    setError(null);
    try {
      const res = await apiFetch<{ flags: Flags }>(
        "/api/v1/admin/maintenance/feature-flags",
        { method: "PATCH", body: JSON.stringify(patch) },
      );
      setFlags(res.flags);
      setRegionInput((res.flags.region_off || []).join(", "));
      setToast(t("maintenance.flagsSaved"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function runDryRun() {
    setBusy(true);
    setError(null);
    try {
      const res = await apiFetch<DryRun>(
        "/api/v1/admin/maintenance/purge-expired/dry-run",
        { method: "POST" },
      );
      setDryRun(res);
      setToast(t("maintenance.dryRunOk", { n: res.eligible }));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function runConfirmPurge() {
    if (!dryRun?.confirm_token) return;
    setBusy(true);
    setError(null);
    try {
      const res = await apiFetch<{ purged: number }>(
        "/api/v1/admin/maintenance/purge-expired/confirm",
        {
          method: "POST",
          body: JSON.stringify({ confirm_token: dryRun.confirm_token }),
        },
      );
      setToast(t("maintenance.purgeResult", { count: res.purged }));
      setDryRun(null);
      setConfirmOpen(false);
      await loadAll();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function runExactCount() {
    setCounting(true);
    setError(null);
    try {
      const res = await apiFetch<{ messages_total: number }>(
        "/api/v1/admin/maintenance/exact-message-count",
      );
      setExactMessages(res.messages_total);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setCounting(false);
    }
  }

  if (!isSuperAdmin()) return null;

  const maxTimeline = Math.max(
    1,
    ...(errors?.timeline.map((x) => x.count) ?? [1]),
  );

  return (
    <div className="space-y-8">
      <PageHeader title={t("maintenance.title")} subtitle={t("maintenance.subtitle")}>
        <div className="flex items-center gap-2">
          <span className="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">
            {t("maintenance.superOnly")}
          </span>
          <button
            type="button"
            onClick={() => void loadAll()}
            className="rounded-lg border px-3 py-1.5 text-xs hover:bg-zinc-50"
          >
            {t("maintenance.refresh")}
          </button>
        </div>
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {exactMessages !== null ? (
        <Alert variant="success">
          {t("maintenance.messagesExactResult", { count: exactMessages })}
        </Alert>
      ) : null}

      {loading ? (
        <LoadingGrid count={4} />
      ) : (
        <>
          <section className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold">{t("maintenance.healthTitle")}</h2>
              {health ? (
                <span
                  className={cn(
                    "rounded px-2 py-0.5 text-xs font-medium",
                    statusTone(health.status),
                  )}
                >
                  {health.status}
                </span>
              ) : null}
            </div>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {(["api", "redis", "postgres", "minio"] as const).map((key) => {
                const c = health?.checks?.[key];
                return (
                  <div key={key} className="rounded-xl border bg-white p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-xs font-semibold uppercase text-zinc-500">
                        {key}
                      </p>
                      <span
                        className={cn(
                          "rounded px-1.5 py-0.5 text-[10px] font-medium",
                          statusTone(c?.status),
                        )}
                      >
                        {c?.status ?? "—"}
                      </span>
                    </div>
                    <p className="mt-2 text-2xl font-semibold tabular-nums">
                      {c?.latency_ms != null ? `${c.latency_ms} ms` : "—"}
                    </p>
                    {c?.error ? (
                      <p className="mt-1 truncate text-[11px] text-rose-600">
                        {c.error}
                      </p>
                    ) : null}
                  </div>
                );
              })}
            </div>
          </section>

          <section className="rounded-xl border bg-white p-5 space-y-4">
            <h2 className="text-sm font-semibold">{t("maintenance.flagsTitle")}</h2>
            <div className="grid gap-3 sm:grid-cols-2">
              {(
                [
                  ["maintenance_mode", t("maintenance.flagMaintenance")],
                  ["push_enabled", t("maintenance.flagPush")],
                  ["translate_enabled", t("maintenance.flagTranslate")],
                  ["payments_enabled", t("maintenance.flagPayments")],
                ] as const
              ).map(([key, label]) => (
                <label
                  key={key}
                  className="flex items-center justify-between rounded-lg border px-3 py-2 text-sm"
                >
                  <span>{label}</span>
                  <input
                    type="checkbox"
                    disabled={busy || !flags}
                    checked={
                      key === "maintenance_mode"
                        ? Boolean(flags?.maintenance_mode)
                        : Boolean(flags?.[key])
                    }
                    onChange={(e) =>
                      void saveFlags({ [key]: e.target.checked } as Partial<Flags>)
                    }
                  />
                </label>
              ))}
            </div>
            <div>
              <p className="mb-1 text-xs font-medium text-zinc-600">
                {t("maintenance.flagRegionOff")}
              </p>
              <div className="flex flex-wrap gap-2">
                <input
                  value={regionInput}
                  onChange={(e) => setRegionInput(e.target.value)}
                  placeholder="UZ, KZ, RU"
                  className="min-w-[200px] flex-1 rounded-lg border px-3 py-2 text-sm"
                />
                <button
                  type="button"
                  disabled={busy}
                  onClick={() =>
                    void saveFlags({
                      region_off: regionInput
                        .split(/[,\s]+/)
                        .map((x) => x.trim().toUpperCase())
                        .filter(Boolean),
                    })
                  }
                  className="rounded-lg border px-3 py-2 text-sm hover:bg-zinc-50 disabled:opacity-50"
                >
                  {t("maintenance.saveRegions")}
                </button>
              </div>
            </div>
          </section>

          <section className="space-y-3">
            <h2 className="text-sm font-semibold">{t("maintenance.queuesTitle")}</h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {(["arq", "translate", "push", "payments"] as const).map((key) => {
                const q = queues?.queues?.[key];
                return (
                  <div key={key} className="rounded-xl border bg-white p-4 text-sm">
                    <div className="flex items-center justify-between">
                      <p className="font-semibold capitalize">{key}</p>
                      <span
                        className={cn(
                          "rounded px-1.5 py-0.5 text-[10px]",
                          statusTone(q?.status),
                        )}
                      >
                        {q?.status ?? "—"}
                      </span>
                    </div>
                    <ul className="mt-2 space-y-1 text-xs text-zinc-600">
                      {q?.queue_depth != null ? (
                        <li>
                          {t("maintenance.queueDepth")}: {q.queue_depth}
                        </li>
                      ) : null}
                      {q?.arq_queue_depth != null ? (
                        <li>
                          ARQ: {q.arq_queue_depth}
                        </li>
                      ) : null}
                      {q?.pending_catalog_approx != null ? (
                        <li>
                          {t("maintenance.translateBacklog")}:{" "}
                          {q.pending_catalog_approx}
                        </li>
                      ) : null}
                      {q?.pending != null ? (
                        <li>
                          {t("maintenance.payPending")}: {q.pending}
                        </li>
                      ) : null}
                      {q?.failed_or_refund != null ? (
                        <li>
                          {t("maintenance.payFailed")}: {q.failed_or_refund}
                        </li>
                      ) : null}
                      {typeof q?.enabled === "boolean" ? (
                        <li>
                          {q.enabled
                            ? t("maintenance.enabled")
                            : t("maintenance.disabled")}
                        </li>
                      ) : null}
                    </ul>
                  </div>
                );
              })}
            </div>
          </section>

          <section className="rounded-xl border bg-white p-5 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-sm font-semibold">{t("maintenance.errorsTitle")}</h2>
              {errors?.spike ? (
                <span className="rounded bg-rose-100 px-2 py-0.5 text-xs font-medium text-rose-800">
                  {t("maintenance.errorSpike")}
                </span>
              ) : (
                <span className="rounded bg-zinc-100 px-2 py-0.5 text-xs text-zinc-600">
                  {t("maintenance.errorOk")}
                </span>
              )}
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              <StatCard
                label={t("maintenance.errorsTotal")}
                value={formatNumber(errors?.total ?? 0)}
              />
              <StatCard
                label={t("maintenance.errorsLastHour")}
                value={formatNumber(errors?.last_hour ?? 0)}
              />
              <StatCard
                label={t("maintenance.errorsPrevHour")}
                value={formatNumber(errors?.prev_hour ?? 0)}
              />
            </div>
            <div className="flex h-24 items-end gap-1">
              {(errors?.timeline ?? []).slice(-24).map((b, i) => (
                <div
                  key={`${b.hour}-${i}`}
                  className="flex-1 rounded-t bg-rose-300/80"
                  style={{
                    height: `${Math.max(4, Math.round((b.count / maxTimeline) * 100))}%`,
                  }}
                  title={`${b.hour ?? ""}: ${b.count}`}
                />
              ))}
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
                  <tr>
                    <th className="px-3 py-2">{t("maintenance.errCode")}</th>
                    <th className="px-3 py-2">{t("maintenance.errPath")}</th>
                    <th className="px-3 py-2">{t("maintenance.errCount")}</th>
                    <th className="px-3 py-2">{t("maintenance.errMsg")}</th>
                  </tr>
                </thead>
                <tbody>
                  {(errors?.top ?? []).slice(0, 12).map((row) => (
                    <tr key={row.fingerprint} className="border-t">
                      <td className="px-3 py-2 font-mono text-xs">{row.error_code}</td>
                      <td className="px-3 py-2 text-xs text-zinc-600">{row.path}</td>
                      <td className="px-3 py-2 tabular-nums">{row.count}</td>
                      <td className="px-3 py-2 max-w-xs truncate text-xs text-zinc-500">
                        {row.message}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {!errors?.top?.length ? (
                <p className="px-3 py-4 text-xs text-zinc-400">
                  {t("maintenance.errorsEmpty")}
                </p>
              ) : null}
            </div>
          </section>

          {stats ? (
            <section>
              <h2 className="mb-4 text-sm font-semibold">{t("maintenance.statsTitle")}</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <StatCard
                  label={t("maintenance.usersTotal")}
                  value={formatNumber(stats.users_total)}
                />
                <StatCard
                  label={t("maintenance.usersActive")}
                  value={formatNumber(stats.users_active)}
                />
                <StatCard
                  label={t("maintenance.productsPublished")}
                  value={formatNumber(stats.products_published)}
                />
                <StatCard
                  label={t("maintenance.productsArchived")}
                  value={formatNumber(stats.products_archived)}
                />
              </div>
            </section>
          ) : null}
        </>
      )}

      <section className="rounded-xl border bg-white p-6">
        <h2 className="text-lg font-semibold">{t("maintenance.messagesExact")}</h2>
        <p className="mt-2 text-sm text-zinc-600">{t("maintenance.messagesExactDesc")}</p>
        <button
          type="button"
          disabled={counting}
          onClick={() => void runExactCount()}
          className="mt-4 rounded-lg border px-4 py-2 text-sm hover:bg-zinc-50 disabled:opacity-50"
        >
          {counting ? t("app.loading") : t("maintenance.messagesExactRun")}
        </button>
      </section>

      <section className="rounded-xl border bg-white p-6 space-y-4">
        <h2 className="text-lg font-semibold">{t("maintenance.purgeTitle")}</h2>
        <p className="text-sm text-zinc-600">{t("maintenance.purgeDesc")}</p>
        <p className="text-xs text-amber-800 bg-amber-50 rounded-lg px-3 py-2">
          {t("maintenance.purgeFlow")}
        </p>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            disabled={busy}
            onClick={() => void runDryRun()}
            className="rounded-lg border px-4 py-2 text-sm hover:bg-zinc-50 disabled:opacity-50"
          >
            {t("maintenance.dryRun")}
          </button>
          <button
            type="button"
            disabled={busy || !dryRun?.confirm_token}
            onClick={() => setConfirmOpen(true)}
            className="rounded-lg bg-red-600 px-4 py-2 text-sm text-white hover:bg-red-700 disabled:opacity-50"
          >
            {t("maintenance.purgeConfirmBtn")}
          </button>
        </div>
        {dryRun ? (
          <div className="rounded-lg border bg-zinc-50 p-3 text-sm">
            <p>
              {t("maintenance.dryRunEligible", { n: dryRun.eligible })} · token{" "}
              <span className="font-mono text-xs">
                {dryRun.confirm_token.slice(0, 12)}…
              </span>
            </p>
            {dryRun.sample.length > 0 ? (
              <ul className="mt-2 max-h-32 overflow-y-auto text-xs text-zinc-600">
                {dryRun.sample.map((u) => (
                  <li key={u.id}>
                    #{u.id} · {u.email} · {u.number}
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : null}
      </section>

      <ConfirmDialog
        open={confirmOpen}
        title={t("maintenance.purgeTitle")}
        message={t("maintenance.purgeConfirm", {
          n: dryRun?.eligible ?? 0,
        })}
        danger
        onCancel={() => setConfirmOpen(false)}
        onConfirm={() => void runConfirmPurge()}
      />
    </div>
  );
}
