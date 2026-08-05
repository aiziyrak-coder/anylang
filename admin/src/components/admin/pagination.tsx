"use client";

import { t } from "@/lib/i18n";

const PAGE_SIZES = [25, 50, 100] as const;

type Props = {
  page: number;
  total: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
  limit?: number;
  onLimitChange?: (limit: number) => void;
};

export function Pagination({
  page,
  total,
  hasMore,
  onPageChange,
  limit,
  onLimitChange,
}: Props) {
  const size = limit ?? 50;
  const from = total === 0 ? 0 : (page - 1) * size + 1;
  const to = Math.min(page * size, total);
  const totalPages = Math.max(1, Math.ceil(total / size) || 1);

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-zinc-200 px-4 py-3 text-sm text-zinc-600 dark:border-zinc-800 dark:text-zinc-300">
      <div className="flex flex-wrap items-center gap-3">
        <span>
          {t("app.total")}: {total.toLocaleString("uz-UZ")}
          {total > 0 ? (
            <>
              {" "}
              · {from}–{to}
            </>
          ) : null}{" "}
          · {t("app.page")} {page}/{totalPages}
        </span>
        {onLimitChange ? (
          <label className="flex items-center gap-2">
            <span className="text-xs text-zinc-500 dark:text-zinc-400">{t("app.pageSize")}</span>
            <select
              value={size}
              onChange={(e) => onLimitChange(Number(e.target.value))}
              className="rounded border border-zinc-200 bg-white px-2 py-1 text-sm dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
            >
              {PAGE_SIZES.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
        ) : null}
      </div>
      <div className="flex items-center gap-2">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="rounded border border-zinc-200 px-3 py-1 hover:bg-zinc-50 disabled:opacity-40 dark:border-zinc-700 dark:text-white dark:hover:bg-zinc-800"
        >
          {t("app.prev")}
        </button>
        <button
          type="button"
          disabled={!hasMore}
          onClick={() => onPageChange(page + 1)}
          className="rounded border border-zinc-200 px-3 py-1 hover:bg-zinc-50 disabled:opacity-40 dark:border-zinc-700 dark:text-white dark:hover:bg-zinc-800"
        >
          {t("app.next")}
        </button>
      </div>
    </div>
  );
}
