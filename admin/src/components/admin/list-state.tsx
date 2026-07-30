"use client";

import { Alert } from "@/components/admin/alert";
import { EmptyState } from "@/components/admin/empty-state";
import { TableSkeleton } from "@/components/admin/loading-grid";
import { t } from "@/lib/i18n";
import type { ReactNode } from "react";

type Props = {
  isLoading: boolean;
  error?: string | null;
  isEmpty: boolean;
  emptyMessage?: string;
  onRetry?: () => void;
  onClearFilters?: () => void;
  hasActiveFilters?: boolean;
  children: ReactNode;
  skeleton?: ReactNode;
};

export function ListState({
  isLoading,
  error,
  isEmpty,
  emptyMessage,
  onRetry,
  onClearFilters,
  hasActiveFilters,
  children,
  skeleton,
}: Props) {
  if (isLoading) {
    return <>{skeleton ?? <TableSkeleton />}</>;
  }

  if (error) {
    return (
      <div className="space-y-3 p-4">
        <Alert variant="error">{error}</Alert>
        {onRetry ? (
          <button
            type="button"
            onClick={onRetry}
            className="rounded-lg border px-3 py-2 text-sm hover:bg-zinc-50"
          >
            {t("app.retry")}
          </button>
        ) : null}
      </div>
    );
  }

  if (isEmpty) {
    return (
      <EmptyState
        message={
          emptyMessage ??
          (hasActiveFilters ? t("app.noResults") : t("app.noData"))
        }
        action={
          hasActiveFilters && onClearFilters
            ? {
                label: t("app.clearFilters"),
                onClick: onClearFilters,
              }
            : undefined
        }
      />
    );
  }

  return <>{children}</>;
}
