"use client";

import { Alert } from "@/components/admin/alert";
import { ConfirmDialog } from "@/components/admin/confirm-dialog";
import { LoadingGrid } from "@/components/admin/loading-grid";
import { PageHeader } from "@/components/admin/page-header";
import { StatCard } from "@/components/admin/stat-card";
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { formatNumber, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type Stats = {
  users_total: number;
  users_active: number;
  subscriptions_active: number;
  products_published: number;
  products_archived: number;
  chats_total: number;
  messages_total: number;
  number_groups_total: number;
};

export default function MaintenancePage() {
  const router = useRouter();
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [purging, setPurging] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [purgeResult, setPurgeResult] = useState<number | null>(null);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  useEffect(() => {
    apiFetch<Stats>("/api/v1/admin/stats")
      .then(setStats)
      .catch((err) => setError(err instanceof ApiError ? err.message : t("app.error")))
      .finally(() => setLoading(false));
  }, []);

  async function runPurge() {
    setPurging(true);
    setError(null);
    try {
      const res = await apiFetch<{ purged: number }>("/api/v1/admin/maintenance/purge-expired", {
        method: "POST",
      });
      setPurgeResult(res.purged);
      const fresh = await apiFetch<Stats>("/api/v1/admin/stats");
      setStats(fresh);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setPurging(false);
      setConfirmOpen(false);
    }
  }

  if (!isSuperAdmin()) return null;

  return (
    <div className="space-y-8">
      <PageHeader title={t("maintenance.title")} subtitle={t("maintenance.subtitle")}>
        <span className="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">
          {t("maintenance.superOnly")}
        </span>
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}
      {purgeResult !== null ? (
        <Alert variant="success">{t("maintenance.purgeResult", { count: purgeResult })}</Alert>
      ) : null}

      {loading ? (
        <LoadingGrid count={4} />
      ) : stats ? (
        <section>
          <h2 className="mb-4 text-sm font-semibold">{t("maintenance.statsTitle")}</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard label={t("maintenance.usersTotal")} value={formatNumber(stats.users_total)} />
            <StatCard label={t("maintenance.usersActive")} value={formatNumber(stats.users_active)} />
            <StatCard
              label={t("maintenance.productsPublished")}
              value={formatNumber(stats.products_published)}
            />
            <StatCard
              label={t("maintenance.productsArchived")}
              value={formatNumber(stats.products_archived)}
            />
            <StatCard label={t("dashboard.chatsTotal")} value={formatNumber(stats.chats_total)} />
            <StatCard
              label={t("dashboard.messagesTotal")}
              value={formatNumber(stats.messages_total)}
            />
            <StatCard
              label={t("maintenance.numberGroups")}
              value={formatNumber(stats.number_groups_total)}
            />
            <StatCard
              label={t("dashboard.subsActive")}
              value={formatNumber(stats.subscriptions_active)}
            />
          </div>
        </section>
      ) : null}

      <section className="rounded-xl border bg-white p-6">
        <h2 className="text-lg font-semibold">{t("maintenance.purgeTitle")}</h2>
        <p className="mt-2 text-sm text-zinc-600">{t("maintenance.purgeDesc")}</p>
        <button
          type="button"
          disabled={purging}
          onClick={() => setConfirmOpen(true)}
          className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm text-white hover:bg-red-700 disabled:opacity-50"
        >
          {purging ? t("app.saving") : t("maintenance.purgeRun")}
        </button>
      </section>

      <ConfirmDialog
        open={confirmOpen}
        title={t("maintenance.purgeTitle")}
        message={t("maintenance.purgeConfirm")}
        danger
        onCancel={() => setConfirmOpen(false)}
        onConfirm={() => void runPurge()}
      />
    </div>
  );
}
