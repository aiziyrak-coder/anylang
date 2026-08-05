"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { useAdminList } from "@/hooks/use-admin-list";
import { ApiError, apiFetch, apiFetchBlob } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { auditActionLabel, formatDate, t } from "@/lib/i18n";
import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { Fragment, useEffect, useState } from "react";

type DiffRow = { field: string; before: unknown; after: unknown };

type Log = {
  id: number;
  actor_admin_id: number | null;
  actor_email: string | null;
  actor_name: string | null;
  action: string;
  target_type: string | null;
  target_id: string | null;
  meta: Record<string, unknown>;
  diff: DiffRow[];
  ip: string | null;
  created_at: string;
  content_hash: string | null;
  immutable: boolean;
  integrity_ok: boolean;
  integrity_badge: "verified" | "legacy" | "tampered";
};

type Actor = { id: number; email: string; full_name: string; role: string };

type ActivityAlert = {
  id: number;
  alert_type: string;
  severity: string;
  actor_admin_id: number | null;
  actor_email: string | null;
  actor_name: string | null;
  title: string;
  detail: Record<string, unknown>;
  status: string;
  created_at: string;
};

const KNOWN_ACTIONS = [
  "",
  "chat.list",
  "chat.view_messages",
  "chat.export",
  "number.assign",
  "user.patch",
  "user.soft_delete",
  "user.restore",
  "user.export",
  "verification.decide",
  "restore.decide",
  "audit.export",
];

function badgeClass(badge: Log["integrity_badge"]) {
  if (badge === "verified") return "bg-emerald-100 text-emerald-800";
  if (badge === "tampered") return "bg-red-100 text-red-800";
  return "bg-zinc-100 text-zinc-600";
}

function fmtVal(v: unknown): string {
  if (v === null || v === undefined) return "—";
  if (typeof v === "object") return JSON.stringify(v);
  return String(v);
}

export default function AuditPage() {
  const router = useRouter();
  const list = useAdminList<
    Log,
    {
      actor_admin_id: string;
      target_type: string;
      target_id: string;
      ip: string;
      from: string;
      to: string;
    }
  >({
    queryKey: "admin-audit",
    path: "/api/v1/admin/audit-logs",
    searchParam: "action",
    defaultSort: "created_at",
    enabled: isSuperAdmin(),
    initialFilters: {
      actor_admin_id: "",
      target_type: "",
      target_id: "",
      ip: "",
      from: "",
      to: "",
    },
  });

  const [expanded, setExpanded] = useState<number | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const actorsQ = useQuery({
    queryKey: ["admin-audit-actors"],
    enabled: isSuperAdmin(),
    queryFn: () => apiFetch<{ items: Actor[] }>("/api/v1/admin/audit-logs/actors"),
  });

  const alertsQ = useQuery({
    queryKey: ["admin-audit-alerts"],
    enabled: isSuperAdmin(),
    queryFn: () =>
      apiFetch<{ items: ActivityAlert[]; total: number }>(
        "/api/v1/admin/audit-alerts?status=open&limit=20",
      ),
    refetchInterval: 60_000,
  });

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  async function exportLogs(fmt: "csv" | "json") {
    setBusy(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      params.set("fmt", fmt);
      for (const [k, v] of Object.entries(list.filters)) {
        if (v) params.set(k, String(v));
      }
      if (list.q.trim()) params.set("action", list.q.trim());
      const { blob, filename } = await apiFetchBlob(
        `/api/v1/admin/audit-logs/export?${params}`,
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      setToast(t("app.success"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function ackAlert(id: number) {
    setBusy(true);
    try {
      await apiFetch(`/api/v1/admin/audit-alerts/${id}/ack`, {
        method: "POST",
        body: JSON.stringify({}),
      });
      await alertsQ.refetch();
      setToast(t("app.success"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  async function scanNow() {
    setBusy(true);
    try {
      await apiFetch("/api/v1/admin/audit-alerts/scan", {
        method: "POST",
        body: JSON.stringify({}),
      });
      await alertsQ.refetch();
      setToast(t("app.success"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t("app.error"));
    } finally {
      setBusy(false);
    }
  }

  if (!isSuperAdmin()) return null;

  const alerts = alertsQ.data?.items ?? [];

  return (
    <div className="space-y-6">
      <PageHeader title={t("audit.title")} subtitle={t("audit.subtitle")}>
        <div className="flex flex-wrap items-center gap-2">
          <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-medium text-emerald-800">
            {t("audit.immutableBadge")}
          </span>
          <button
            type="button"
            disabled={busy}
            onClick={() => void exportLogs("csv")}
            className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50"
          >
            {t("audit.exportCsv")}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void exportLogs("json")}
            className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50"
          >
            {t("audit.exportJson")}
          </button>
        </div>
      </PageHeader>

      {toast ? <Alert variant="success">{toast}</Alert> : null}
      {error ? <Alert variant="error">{error}</Alert> : null}

      {alerts.length > 0 ? (
        <div className="space-y-2 rounded-xl border border-amber-200 bg-amber-50 p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-sm font-semibold text-amber-900">
              {t("audit.alertsTitle")} ({alerts.length})
            </h2>
            <button
              type="button"
              disabled={busy}
              onClick={() => void scanNow()}
              className="rounded border border-amber-300 px-2 py-1 text-xs disabled:opacity-50"
            >
              {t("audit.scanNow")}
            </button>
          </div>
          <ul className="space-y-2">
            {alerts.map((a) => (
              <li
                key={a.id}
                className="flex flex-wrap items-start justify-between gap-2 rounded-lg bg-white px-3 py-2 text-sm"
              >
                <div>
                  <p className="font-medium">
                    <span
                      className={
                        a.severity === "critical"
                          ? "text-red-700"
                          : a.severity === "high"
                            ? "text-amber-800"
                            : "text-zinc-700"
                      }
                    >
                      [{a.severity}]
                    </span>{" "}
                    {a.title}
                  </p>
                  <p className="text-xs text-zinc-500">
                    {a.actor_email ?? a.actor_name ?? "—"} · {formatDate(a.created_at)} ·{" "}
                    {a.alert_type}
                  </p>
                </div>
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => void ackAlert(a.id)}
                  className="rounded border px-2 py-1 text-xs disabled:opacity-50"
                >
                  {t("audit.ack")}
                </button>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <DataToolbar
        search={{
          value: list.q,
          onChange: list.setQ,
          placeholder: t("audit.filterAction"),
        }}
        showClear={list.hasActiveFilters}
        onClear={list.clearFilters}
        filters={
          <>
            <select
              value={KNOWN_ACTIONS.includes(list.q) ? list.q : list.q ? list.q : ""}
              onChange={(e) => list.setQ(e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
            >
              {KNOWN_ACTIONS.map((a) => (
                <option key={a || "all"} value={a}>
                  {a ? auditActionLabel(a) : t("app.all")}
                </option>
              ))}
            </select>
            <select
              value={list.filters.actor_admin_id}
              onChange={(e) => list.setFilter("actor_admin_id", e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
            >
              <option value="">{t("audit.filterAdmin")}</option>
              {(actorsQ.data?.items ?? []).map((a) => (
                <option key={a.id} value={String(a.id)}>
                  {a.full_name || a.email} (#{a.id})
                </option>
              ))}
            </select>
            <input
              value={list.filters.target_type}
              onChange={(e) => list.setFilter("target_type", e.target.value)}
              placeholder={t("audit.filterTargetType")}
              className="w-28 rounded-lg border px-3 py-2 text-sm"
            />
            <input
              value={list.filters.target_id}
              onChange={(e) => list.setFilter("target_id", e.target.value)}
              placeholder={t("audit.filterTargetId")}
              className="w-28 rounded-lg border px-3 py-2 text-sm"
            />
            <input
              value={list.filters.ip}
              onChange={(e) => list.setFilter("ip", e.target.value)}
              placeholder={t("audit.filterIp")}
              className="w-32 rounded-lg border px-3 py-2 text-sm"
            />
            <input
              type="date"
              value={list.filters.from}
              onChange={(e) => list.setFilter("from", e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
              title={t("audit.filterFrom")}
            />
            <input
              type="date"
              value={list.filters.to}
              onChange={(e) => list.setFilter("to", e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
              title={t("audit.filterTo")}
            />
          </>
        }
      />

      <div className="overflow-hidden rounded-xl border bg-white">
        <ListState
          isLoading={list.isLoading}
          error={list.error}
          isEmpty={list.items.length === 0}
          hasActiveFilters={list.hasActiveFilters}
          onClearFilters={list.clearFilters}
          onRetry={() => void list.refetch()}
        >
          <table className="min-w-full text-sm">
            <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <SortableTh
                  label={t("audit.colWhen")}
                  sortKey="created_at"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <th className="px-4 py-3 text-left">{t("audit.colAdmin")}</th>
                <SortableTh
                  label={t("audit.colAction")}
                  sortKey="action"
                  sortBy={list.sort}
                  sortDir={list.order}
                  onSort={list.toggleSort}
                />
                <th className="px-4 py-3 text-left">{t("audit.colTarget")}</th>
                <th className="px-4 py-3 text-left">{t("audit.colIp")}</th>
                <th className="px-4 py-3 text-left">{t("audit.colIntegrity")}</th>
              </tr>
            </thead>
            <tbody>
              {list.items.map((row) => (
                <Fragment key={row.id}>
                  <tr
                    className="cursor-pointer border-t hover:bg-zinc-50"
                    onClick={() =>
                      setExpanded((id) => (id === row.id ? null : row.id))
                    }
                  >
                    <td className="px-4 py-2 text-xs text-zinc-500">
                      {formatDate(row.created_at)}
                    </td>
                    <td className="px-4 py-2">
                      <span className="block text-sm">
                        {row.actor_name || row.actor_email || "—"}
                      </span>
                      <span className="text-xs text-zinc-400 tabular-nums">
                        #{row.actor_admin_id ?? "—"}
                      </span>
                    </td>
                    <td className="px-4 py-2">{auditActionLabel(row.action)}</td>
                    <td className="px-4 py-2 text-xs">
                      {row.target_type ?? "—"}
                      {row.target_id ? ` #${row.target_id}` : ""}
                    </td>
                    <td className="px-4 py-2 font-mono text-xs">{row.ip ?? "—"}</td>
                    <td className="px-4 py-2">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs ${badgeClass(row.integrity_badge)}`}
                      >
                        {t(`audit.badge.${row.integrity_badge}`)}
                      </span>
                    </td>
                  </tr>
                  {expanded === row.id ? (
                    <tr className="border-t bg-zinc-50">
                      <td colSpan={6} className="px-4 py-3">
                        <p className="mb-2 text-xs font-semibold uppercase text-zinc-500">
                          {t("audit.diffTitle")}
                        </p>
                        {row.diff?.length ? (
                          <table className="w-full text-xs">
                            <thead>
                              <tr className="text-left text-zinc-500">
                                <th className="py-1 pr-3">{t("audit.diffField")}</th>
                                <th className="py-1 pr-3">{t("audit.diffBefore")}</th>
                                <th className="py-1">{t("audit.diffAfter")}</th>
                              </tr>
                            </thead>
                            <tbody>
                              {row.diff.map((d) => (
                                <tr key={d.field} className="border-t border-zinc-200">
                                  <td className="py-1.5 pr-3 font-medium">{d.field}</td>
                                  <td className="py-1.5 pr-3 text-rose-700">
                                    {fmtVal(d.before)}
                                  </td>
                                  <td className="py-1.5 text-emerald-700">
                                    {fmtVal(d.after)}
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        ) : (
                          <pre className="overflow-x-auto rounded bg-white p-2 text-xs text-zinc-600">
                            {JSON.stringify(row.meta ?? {}, null, 2)}
                          </pre>
                        )}
                        {row.content_hash ? (
                          <p className="mt-2 font-mono text-[10px] text-zinc-400">
                            hash: {row.content_hash.slice(0, 16)}…
                          </p>
                        ) : null}
                      </td>
                    </tr>
                  ) : null}
                </Fragment>
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
    </div>
  );
}
