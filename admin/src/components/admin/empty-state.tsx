import { t } from "@/lib/i18n";

type Props = {
  message?: string;
  action?: { label: string; onClick: () => void };
};

export function EmptyState({ message, action }: Props) {
  return (
    <div className="flex flex-col items-center justify-center rounded-xl border border-dashed bg-white py-16 text-center">
      <p className="text-sm text-zinc-500">{message ?? t("app.noData")}</p>
      {action ? (
        <button
          type="button"
          onClick={action.onClick}
          className="mt-4 rounded-lg border px-3 py-2 text-sm hover:bg-zinc-50"
        >
          {action.label}
        </button>
      ) : null}
    </div>
  );
}
