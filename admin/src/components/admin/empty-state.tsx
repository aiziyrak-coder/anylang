import { t } from "@/lib/i18n";

type Props = {
  message?: string;
  action?: { label: string; onClick: () => void };
};

export function EmptyState({ message, action }: Props) {
  return (
    <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-zinc-200 bg-white py-16 text-center dark:border-zinc-700 dark:bg-zinc-900">
      <p className="text-sm text-zinc-500 dark:text-zinc-300">
        {message ?? t("app.noData")}
      </p>
      {action ? (
        <button
          type="button"
          onClick={action.onClick}
          className="mt-4 rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-800 hover:bg-zinc-50 dark:border-zinc-600 dark:text-zinc-100 dark:hover:bg-zinc-800"
        >
          {action.label}
        </button>
      ) : null}
    </div>
  );
}
