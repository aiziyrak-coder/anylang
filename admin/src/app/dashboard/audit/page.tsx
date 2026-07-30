"use client";

import { Alert } from "@/components/admin/alert";
import { DataToolbar } from "@/components/admin/data-toolbar";
import { ListState } from "@/components/admin/list-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { SortableTh } from "@/components/admin/sortable-th";
import { useAdminList } from "@/hooks/use-admin-list";
import { isSuperAdmin } from "@/lib/auth";
import { auditActionLabel, formatDate, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

type Log = {
  id: number;
  actor_admin_id: number | null;
  action: string;
  target_type: string | null;
  target_id: string | null;
  meta: Record<string, unknown>;
  ip: string | null;
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
  "verification.decide",
  "restore.decide",
];

export default function AuditPage() {
  const router = useRouter();
  const list = useAdminList<Log>({
    queryKey: "admin-audit",
    path: "/api/v1/admin/audit-logs",
    searchParam: "action",
    defaultSort: "id",
    enabled: isSuperAdmin(),
  });

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  if (!isSuperAdmin()) return null;

  return (
    <div className="space-y-6">
      <PageHeader title={t("audit.title")} subtitle={t("audit.subtitle")}>
        <DataToolbar
          search={{
            value: list.q,
            onChange: list.setQ,
            placeholder: t("audit.filterAction"),
          }}
          showClear={list.hasActiveFilters}
          onClear={list.clearFilters}
          filters={
            <select
              value={KNOWN_ACTIONS.includes(list.q) ? list.q : ""}
              onChange={(e) => list.setQ(e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
            >
              {KNOWN_ACTIONS.map((a) => (
                <option key={a || "all"} value={a}>
                  {a ? auditActionLabel(a) : t("app.all")}
                </option>
              ))}
            </select>
          }
        />
      </PageHeader>

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
              </tr>
            </thead>
            <tbody>
              {list.items.map((row) => (
                <tr key={row.id} className="border-t">
                  <td className="px-4 py-2 text-xs text-zinc-500">
                    {formatDate(row.created_at)}
                  </td>
                  <td className="px-4 py-2 tabular-nums">{row.actor_admin_id ?? "—"}</td>
                  <td className="px-4 py-2">{auditActionLabel(row.action)}</td>
                  <td className="px-4 py-2 text-xs">
                    {row.target_type ?? "—"}
                    {row.target_id ? ` #${row.target_id}` : ""}
                  </td>
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
    </div>
  );
}
