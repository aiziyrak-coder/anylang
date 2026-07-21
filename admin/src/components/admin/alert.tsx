import { cn } from "@/lib/utils";

type Variant = "error" | "success" | "warning" | "info";

const styles: Record<Variant, string> = {
  error: "border-red-200 bg-red-50 text-red-800",
  success: "border-emerald-200 bg-emerald-50 text-emerald-800",
  warning: "border-amber-200 bg-amber-50 text-amber-900",
  info: "border-zinc-200 bg-zinc-50 text-zinc-700",
};

export function Alert({
  variant = "info",
  children,
  className,
}: {
  variant?: Variant;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("rounded-lg border px-3 py-2 text-sm", styles[variant], className)}>
      {children}
    </div>
  );
}
