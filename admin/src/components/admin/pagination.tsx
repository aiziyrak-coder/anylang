import { t } from "@/lib/i18n";

type Props = {
  page: number;
  total: number;
  hasMore: boolean;
  onPageChange: (page: number) => void;
};

export function Pagination({ page, total, hasMore, onPageChange }: Props) {
  return (
    <div className="flex items-center justify-between border-t px-4 py-3 text-sm text-zinc-600">
      <span>
        {t("app.total")}: {total.toLocaleString("uz-UZ")} · {t("app.page")} {page}
      </span>
      <div className="flex gap-2">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="rounded border px-3 py-1 disabled:opacity-40 hover:bg-zinc-50"
        >
          {t("app.prev")}
        </button>
        <button
          type="button"
          disabled={!hasMore}
          onClick={() => onPageChange(page + 1)}
          className="rounded border px-3 py-1 disabled:opacity-40 hover:bg-zinc-50"
        >
          {t("app.next")}
        </button>
      </div>
    </div>
  );
}
