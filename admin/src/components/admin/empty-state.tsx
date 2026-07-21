import { t } from "@/lib/i18n";

export function EmptyState({ message }: { message?: string }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-xl border border-dashed bg-white py-16 text-center">
      <p className="text-sm text-zinc-500">{message ?? t("app.noData")}</p>
    </div>
  );
}
