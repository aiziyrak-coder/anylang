"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { PageHeader } from "@/components/admin/page-header";
import { Pagination } from "@/components/admin/pagination";
import { ApiError, apiFetch } from "@/lib/api";
import { isSuperAdmin } from "@/lib/auth";
import { auditActionLabel, formatDate, t } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

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

type ListResp = {
  items: Log[];
  total: number;
  has_more: boolean;
};

export default function AuditPage() {
  const router = useRouter();
  const [items, setItems] = useState<Log[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);

  useEffect(() => {
    if (!isSuperAdmin()) router.replace("/dashboard");
  }, [router]);

  useEffect(() => {
    const q = new URLSearchParams({ limit: "50", page: String(page) });
    if (action) q.set("action", action);
    apiFetch<ListResp>(`/api/v1/admin/audit-logs?${q}`)
      .then((r) => {
        setItems(r.items);
        setTotal(r.total ?? r.items.length);
        setHasMore(r.has_more ?? false);
      })
      .catch((err) => setError(err instanceof ApiError ? err.message : t("app.error")));
  }, [action, page]);

  if (!isSuperAdmin()) return null;

  return (
    <div className="space-y-6">
      <PageHeader title={t("audit.title")} subtitle={t("audit.subtitle")}>
        <input
          value={action}
          onChange={(e) => {
            setPage(1);
            setAction(e.target.value);
          }}
          placeholder={t("audit.filterAction")}
          className="rounded-lg border px-3 py-2 text-sm"
        />
      </PageHeader>

      {error ? <Alert variant="error">{error}</Alert> : null}

      <div className="overflow-hidden rounded-xl border bg-white">
        <table className="min-w-full text-sm">
          <thead className="bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3 text-left">{t("audit.colWhen")}</th>
              <th className="px-4 py-3 text-left">{t("audit.colAdmin")}</th>
              <th className="px-4 py-3 text-left">{t("audit.colAction")}</th>
              <th className="px-4 py-3 text-left">{t("audit.colTarget")}</th>
              <th className="px-4 py-3 text-left">{t("audit.colIp")}</th>
            </tr>
          </thead>
          <tbody>
            {items.map((l) => (
              <tr key={l.id} className="border-t">
                <td className="px-4 py-2 text-xs text-zinc-500">{formatDate(l.created_at)}</td>
                <td className="px-4 py-2">#{l.actor_admin_id}</td>
                <td className="px-4 py-2">
                  <div className="font-medium">{auditActionLabel(l.action)}</div>
                  <div className="font-mono text-[10px] text-zinc-400">{l.action}</div>
                </td>
                <td className="px-4 py-2 text-xs">
                  {l.target_type}:{l.target_id}
                </td>
                <td className="px-4 py-2 text-xs">{l.ip ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!items.length ? <EmptyState /> : null}
        <Pagination page={page} total={total} hasMore={hasMore} onPageChange={setPage} />
      </div>
    </div>
  );
}
