"use client";

import { Alert } from "@/components/admin/alert";
import { t } from "@/lib/i18n";
import { useEffect } from "react";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="mx-auto max-w-lg space-y-4 pt-16">
      <Alert variant="error">{error.message || t("app.error")}</Alert>
      <button
        type="button"
        onClick={reset}
        className="rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white"
      >
        {t("app.refresh")}
      </button>
    </div>
  );
}
