import { cn } from "@/lib/utils";

type Props = {
  label: string;
  value: string | number;
  hint?: string;
  accent?: boolean;
};

export function StatCard({ label, value, hint, accent }: Props) {
  return (
    <div
      className={cn(
        "rounded-xl border bg-white p-4 shadow-sm",
        accent && "border-l-4 border-l-[var(--accent)]",
      )}
    >
      <p className="text-sm text-zinc-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums text-zinc-900">{value}</p>
      {hint ? <p className="mt-1 text-xs text-zinc-400">{hint}</p> : null}
    </div>
  );
}
