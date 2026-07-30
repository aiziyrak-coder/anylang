"use client";

import { cn } from "@/lib/utils";

type Props = {
  label: string;
  sortKey: string;
  sortBy?: string | null;
  sortDir?: "asc" | "desc";
  onSort: (key: string) => void;
  className?: string;
};

export function SortableTh({
  label,
  sortKey,
  sortBy,
  sortDir = "desc",
  onSort,
  className,
}: Props) {
  const active = sortBy === sortKey;
  return (
    <th className={cn("px-4 py-3", className)}>
      <button
        type="button"
        onClick={() => onSort(sortKey)}
        className={cn(
          "inline-flex items-center gap-1 font-medium uppercase tracking-wide hover:text-zinc-900",
          active ? "text-zinc-900" : "text-zinc-500",
        )}
      >
        {label}
        <span className="text-[10px] tabular-nums" aria-hidden>
          {active ? (sortDir === "asc" ? "▲" : "▼") : "↕"}
        </span>
      </button>
    </th>
  );
}
