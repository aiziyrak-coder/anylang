"use client";

import { t } from "@/lib/i18n";

type Props = {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
};

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel,
  cancelLabel,
  danger,
  onConfirm,
  onCancel,
}: Props) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
      <button type="button" className="absolute inset-0 bg-black/40" onClick={onCancel} />
      <div className="relative w-full max-w-md rounded-xl border bg-white p-5 shadow-xl">
        <h3 className="text-lg font-semibold">{title}</h3>
        <p className="mt-2 text-sm text-zinc-600">{message}</p>
        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            className="rounded-lg border px-4 py-2 text-sm hover:bg-zinc-50"
          >
            {cancelLabel ?? t("app.cancel")}
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className={
              danger
                ? "rounded-lg bg-red-600 px-4 py-2 text-sm text-white hover:bg-red-700"
                : "rounded-lg bg-zinc-900 px-4 py-2 text-sm text-white hover:bg-zinc-800"
            }
          >
            {confirmLabel ?? t("app.confirm")}
          </button>
        </div>
      </div>
    </div>
  );
}
