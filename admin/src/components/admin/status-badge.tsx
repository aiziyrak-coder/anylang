import { statusLabel } from "@/lib/i18n";
import { cn } from "@/lib/utils";

const tone: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-800",
  succeeded: "bg-emerald-100 text-emerald-800",
  approved: "bg-emerald-100 text-emerald-800",
  published: "bg-emerald-100 text-emerald-800",
  pending: "bg-amber-100 text-amber-800",
  inactive: "bg-zinc-200 text-zinc-700",
  deleted: "bg-red-100 text-red-800",
  banned: "bg-red-100 text-red-800",
  failed: "bg-red-100 text-red-800",
  rejected: "bg-red-100 text-red-800",
  needs_refund: "bg-orange-100 text-orange-800",
  draft: "bg-zinc-100 text-zinc-600",
  archived: "bg-zinc-200 text-zinc-600",
};

export function StatusBadge({ status }: { status: string }) {
  return (
    <span
      className={cn(
        "inline-flex rounded px-2 py-0.5 text-xs font-medium",
        tone[status] ?? "bg-zinc-100 text-zinc-700",
      )}
    >
      {statusLabel(status)}
    </span>
  );
}
