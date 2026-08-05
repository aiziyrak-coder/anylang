import { en } from "./en";
import { ru } from "./ru";
import { uz } from "./uz";

export type Locale = "uz" | "ru" | "en";

type Dict = typeof uz;

const LOCALE_KEY = "anylang_admin_locale";

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function deepMerge(
  base: Record<string, unknown>,
  overlay: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...base };
  for (const [k, v] of Object.entries(overlay)) {
    if (isPlainObject(v) && isPlainObject(out[k])) {
      out[k] = deepMerge(out[k] as Record<string, unknown>, v);
    } else {
      out[k] = v;
    }
  }
  return out;
}

const catalogs: Record<Locale, Record<string, unknown>> = {
  uz: uz as unknown as Record<string, unknown>,
  en: deepMerge(uz as unknown as Record<string, unknown>, en as unknown as Record<string, unknown>),
  ru: deepMerge(uz as unknown as Record<string, unknown>, ru as unknown as Record<string, unknown>),
};

let activeLocale: Locale = "uz";
const listeners = new Set<() => void>();

export function getLocale(): Locale {
  return activeLocale;
}

export function setLocale(locale: Locale): void {
  activeLocale = locale;
  if (typeof window !== "undefined") {
    localStorage.setItem(LOCALE_KEY, locale);
    document.documentElement.lang = locale === "uz" ? "uz" : locale;
  }
  listeners.forEach((l) => l());
}

export function initLocaleFromStorage(): Locale {
  if (typeof window === "undefined") return "uz";
  const raw = localStorage.getItem(LOCALE_KEY);
  const loc = raw === "ru" || raw === "en" || raw === "uz" ? raw : "uz";
  activeLocale = loc;
  document.documentElement.lang = loc === "uz" ? "uz" : loc;
  return loc;
}

export function subscribeLocale(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

function getNested(obj: Record<string, unknown>, path: string): string {
  const parts = path.split(".");
  let cur: unknown = obj;
  for (const p of parts) {
    if (cur == null || typeof cur !== "object") return path;
    cur = (cur as Record<string, unknown>)[p];
  }
  return typeof cur === "string" ? cur : path;
}

/** Active locale matn — `{name}` placeholder. */
export function t(key: string, vars?: Record<string, string | number>): string {
  let text = getNested(catalogs[activeLocale], key);
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      text = text.replace(`{${k}}`, String(v));
    }
  }
  return text;
}

export function roleLabel(role: string): string {
  return (catalogs[activeLocale].roles as Record<string, string>)?.[role] ?? role;
}

export function planLabel(plan: string): string {
  return (catalogs[activeLocale].plan as Record<string, string>)?.[plan] ?? plan;
}

export function statusLabel(status: string): string {
  return (catalogs[activeLocale].status as Record<string, string>)?.[status] ?? status;
}

export function auditActionLabel(action: string): string {
  return (
    (catalogs[activeLocale].auditActions as Record<string, string>)?.[action] ?? action
  );
}

function localeTag(): string {
  if (activeLocale === "ru") return "ru-RU";
  if (activeLocale === "en") return "en-US";
  return "uz-UZ";
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString(localeTag(), {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

export function formatNumber(n: number): string {
  return n.toLocaleString(localeTag());
}

export { uz, en, ru };
export type { Dict };
