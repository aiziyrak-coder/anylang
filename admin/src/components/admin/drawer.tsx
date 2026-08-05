"use client";

import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

type Props = {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  width?: "md" | "lg" | "xl";
};

export function Drawer({ open, onClose, title, children, width = "lg" }: Props) {
  if (!open) return null;

  const w = { md: "max-w-md", lg: "max-w-lg", xl: "max-w-xl" }[width];

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button
        type="button"
        aria-label={t("app.close")}
        className="absolute inset-0 bg-black/60"
        onClick={onClose}
      />
      <aside
        className={cn(
          "relative flex h-full w-full flex-col border-l border-zinc-200 bg-white shadow-xl dark:border-zinc-800 dark:bg-zinc-950 dark:text-white",
          w,
        )}
      >
        <div className="flex items-center justify-between border-b border-zinc-200 px-5 py-4 dark:border-zinc-800">
          <h2 className="text-lg font-semibold text-zinc-900 dark:text-white">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg px-2 py-1 text-sm text-zinc-500 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800"
          >
            {t("app.close")}
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-5 text-zinc-900 dark:text-zinc-100">
          {children}
        </div>
      </aside>
    </div>
  );
}
