"use client";

import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

type SearchProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
};

type Props = {
  search?: SearchProps;
  filters?: ReactNode;
  actions?: ReactNode;
  onClear?: () => void;
  showClear?: boolean;
  className?: string;
};

export function DataToolbar({
  search,
  filters,
  actions,
  onClear,
  showClear,
  className,
}: Props) {
  return (
    <div className={cn("flex flex-wrap items-center gap-2", className)}>
      {search ? (
        <input
          type="search"
          value={search.value}
          onChange={(e) => search.onChange(e.target.value)}
          placeholder={search.placeholder ?? t("app.search")}
          className={cn(
            "min-w-[200px] flex-1 rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-zinc-900 outline-none focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:placeholder:text-zinc-500 dark:focus:border-zinc-400 dark:focus:ring-zinc-400 sm:max-w-xs",
            search.className,
          )}
          aria-label={t("app.search")}
        />
      ) : null}
      {filters}
      {showClear && onClear ? (
        <button
          type="button"
          onClick={onClear}
          className="rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-800 hover:bg-zinc-50 dark:border-zinc-700 dark:text-zinc-100 dark:hover:bg-zinc-800"
        >
          {t("app.clearFilters")}
        </button>
      ) : null}
      {actions}
    </div>
  );
}
