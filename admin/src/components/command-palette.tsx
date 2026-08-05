"use client";

import { canAccessPath } from "@/lib/rbac";
import { getAdminProfile } from "@/lib/auth";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

type Hit = { id: string; label: string; href: string };

function parseQuery(q: string): Hit[] {
  const raw = q.trim();
  const lower = raw.toLowerCase();
  const hits: Hit[] = [];

  const userMatch = lower.match(/^(?:user|u|#)\s*#?\s*(\d+)$/i) || lower.match(/^#(\d+)$/);
  if (userMatch) {
    const id = userMatch[1];
    hits.push({
      id: `user-${id}`,
      label: t("command.goUser", { id }),
      href: `/dashboard/users?q=${id}&highlight=${id}`,
    });
  }

  if (
    /payment\s*fail|failed\s*payment|to['’`]?lov\s*fail|неуспешн/i.test(lower) ||
    lower === "payment fail"
  ) {
    hits.push({
      id: "pay-fail",
      label: t("command.goPaymentsFail"),
      href: "/dashboard/payments?status=failed",
    });
  }

  const shortcuts: { test: RegExp; id: string; labelKey: string; href: string }[] = [
    { test: /^products?$|mahsulot|товар/i, id: "products", labelKey: "command.goProducts", href: "/dashboard/products" },
    { test: /^reviews?$|otziv|отзыв/i, id: "reviews", labelKey: "command.goReviews", href: "/dashboard/reviews" },
    { test: /^verif|verification/i, id: "verification", labelKey: "command.goVerification", href: "/dashboard/verification" },
    { test: /^restore|tiklash|восстанов/i, id: "restore", labelKey: "command.goRestore", href: "/dashboard/restore" },
    { test: /^payments?$|to['’`]?lov|платеж/i, id: "payments", labelKey: "command.goPayments", href: "/dashboard/payments" },
  ];

  for (const s of shortcuts) {
    if (s.test.test(lower) || (lower.length >= 2 && s.href.includes(lower))) {
      hits.push({ id: s.id, label: t(s.labelKey), href: s.href });
    }
  }

  if (raw && hits.length === 0) {
    hits.push({
      id: "search-users",
      label: t("command.goSearch", { q: raw }),
      href: `/dashboard/users?q=${encodeURIComponent(raw)}`,
    });
  }

  const role = getAdminProfile()?.role;
  return hits.filter((h) => canAccessPath(role, h.href.split("?")[0]));
}

export function CommandPalette() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [active, setActive] = useState(0);

  const hits = useMemo(() => parseQuery(q), [q]);

  const close = useCallback(() => {
    setOpen(false);
    setQ("");
    setActive(0);
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((v) => !v);
      }
      if (e.key === "Escape") close();
    }
    function onOpen() {
      setOpen(true);
    }
    window.addEventListener("keydown", onKey);
    window.addEventListener("anylang:open-command", onOpen);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("anylang:open-command", onOpen);
    };
  }, [close]);

  function go(href: string) {
    close();
    router.push(href);
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-start justify-center bg-black/40 p-4 pt-[12vh]">
      <button type="button" className="absolute inset-0" aria-label={t("app.close")} onClick={close} />
      <div className="relative w-full max-w-lg overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-2xl dark:border-zinc-700 dark:bg-zinc-900">
        <div className="border-b border-zinc-200 px-3 py-2 dark:border-zinc-700">
          <input
            autoFocus
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setActive(0);
            }}
            onKeyDown={(e) => {
              if (e.key === "ArrowDown") {
                e.preventDefault();
                setActive((i) => Math.min(i + 1, Math.max(0, hits.length - 1)));
              } else if (e.key === "ArrowUp") {
                e.preventDefault();
                setActive((i) => Math.max(0, i - 1));
              } else if (e.key === "Enter" && hits[active]) {
                e.preventDefault();
                go(hits[active].href);
              }
            }}
            placeholder={t("command.placeholder")}
            className="w-full bg-transparent px-2 py-2 text-sm outline-none dark:text-zinc-100"
          />
        </div>
        <ul className="max-h-72 overflow-y-auto p-1">
          {hits.map((h, i) => (
            <li key={h.id}>
              <button
                type="button"
                onClick={() => go(h.href)}
                className={cn(
                  "flex w-full rounded-lg px-3 py-2 text-left text-sm",
                  i === active
                    ? "bg-zinc-100 dark:bg-zinc-800"
                    : "hover:bg-zinc-50 dark:hover:bg-zinc-800/60",
                )}
              >
                {h.label}
              </button>
            </li>
          ))}
          {hits.length === 0 ? (
            <li className="px-3 py-6 text-center text-xs text-zinc-500">
              {t("command.noResults")}
            </li>
          ) : null}
        </ul>
        <p className="border-t border-zinc-100 px-3 py-1.5 text-[10px] text-zinc-400 dark:border-zinc-800">
          {t("command.hint")} · {t("command.title")}
        </p>
      </div>
    </div>
  );
}
