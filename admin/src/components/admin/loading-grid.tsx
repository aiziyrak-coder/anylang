export function LoadingGrid({ count = 4 }: { count?: number }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="animate-pulse rounded-xl border bg-white p-4">
          <div className="h-3 w-24 rounded bg-zinc-200" />
          <div className="mt-3 h-8 w-16 rounded bg-zinc-200" />
        </div>
      ))}
    </div>
  );
}

export function TableSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="animate-pulse space-y-2 p-4">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="h-10 rounded bg-zinc-100" />
      ))}
    </div>
  );
}
