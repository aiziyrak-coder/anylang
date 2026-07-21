import { cn } from "@/lib/utils";

type Props = {
  title: string;
  subtitle?: string;
  children?: React.ReactNode;
  className?: string;
};

export function PageHeader({ title, subtitle, children, className }: Props) {
  return (
    <header className={cn("flex flex-wrap items-end justify-between gap-4", className)}>
      <div>
        <h1 className="text-2xl font-semibold text-zinc-900">{title}</h1>
        {subtitle ? <p className="mt-1 text-sm text-zinc-600">{subtitle}</p> : null}
      </div>
      {children ? <div className="flex flex-wrap items-center gap-2">{children}</div> : null}
    </header>
  );
}
