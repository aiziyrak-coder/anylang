"use client";

import { cn } from "@/lib/utils";

type ToggleProps = {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  label: string;
  id?: string;
};

export function Toggle({
  checked,
  onChange,
  disabled = false,
  label,
  id,
}: ToggleProps) {
  const toggleId = id ?? label.replace(/\s+/g, "-").toLowerCase();

  return (
    <button
      type="button"
      role="switch"
      id={toggleId}
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cn(
        "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-900 disabled:cursor-not-allowed disabled:opacity-50",
        checked ? "bg-emerald-600" : "bg-zinc-300",
      )}
    >
      <span
        aria-hidden="true"
        className={cn(
          "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition",
          checked ? "translate-x-5" : "translate-x-0",
        )}
      />
    </button>
  );
}
