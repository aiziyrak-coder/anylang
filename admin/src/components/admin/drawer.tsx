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
        className="absolute inset-0 bg-black/30"
        onClick={onClose}
      />
      <aside
        className={cn(
          "relative flex h-full w-full flex-col border-l bg-white shadow-xl",
          w,
        )}
      >
        <div className="flex items-center justify-between border-b px-5 py-4">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg px-2 py-1 text-sm text-zinc-500 hover:bg-zinc-100"
          >
            {t("app.close")}
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
      </aside>
    </div>
  );
}
