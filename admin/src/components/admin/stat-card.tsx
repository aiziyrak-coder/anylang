import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

type Props = {
  label: string;
  value: string | number;
  hint?: string;
  accent?: boolean;
  /** Percent change vs previous period; null = no baseline */
  changePct?: number | null;
};

export function StatCard({ label, value, hint, accent, changePct }: Props) {
  const delta =
    changePct == null
      ? null
      : {
          text: `${changePct > 0 ? "+" : ""}${changePct.toFixed(1)}%`,
          up: changePct > 0,
          flat: changePct === 0,
        };

  return (
    <div
      className={cn(
        "rounded-xl border bg-white p-4 shadow-sm",
        accent && "border-l-4 border-l-[var(--accent)]",
      )}
    >
      <p className="text-sm text-zinc-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums text-zinc-900">{value}</p>
      {delta ? (
        <p
          className={cn(
            "mt-1 text-xs font-medium tabular-nums",
            delta.flat ? "text-zinc-400" : delta.up ? "text-emerald-600" : "text-rose-600",
          )}
        >
          {delta.text}
          <span className="ml-1 font-normal text-zinc-400">{t("dashboard.vsPrevious")}</span>
        </p>
      ) : hint ? (
        <p className="mt-1 text-xs text-zinc-400">{hint}</p>
      ) : null}
      {delta && hint ? <p className="mt-0.5 text-xs text-zinc-400">{hint}</p> : null}
    </div>
  );
}
