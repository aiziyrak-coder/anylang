import { uz } from "./uz";

type Dict = typeof uz;

function getNested(obj: Record<string, unknown>, path: string): string {
  const parts = path.split(".");
  let cur: unknown = obj;
  for (const p of parts) {
    if (cur == null || typeof cur !== "object") return path;
    cur = (cur as Record<string, unknown>)[p];
  }
  return typeof cur === "string" ? cur : path;
}

/** O‘zbek matn — `{name}` placeholder qo‘llab-quvvatlanadi */
export function t(key: string, vars?: Record<string, string | number>): string {
  let text = getNested(uz as unknown as Record<string, unknown>, key);
  if (vars) {
    for (const [k, v] of Object.entries(vars)) {
      text = text.replace(`{${k}}`, String(v));
    }
  }
  return text;
}

export function roleLabel(role: string): string {
  const key = `roles.${role}` as keyof Dict["roles"];
  return (uz.roles as Record<string, string>)[role] ?? role;
}

export function planLabel(plan: string): string {
  return (uz.plan as Record<string, string>)[plan] ?? plan;
}

export function statusLabel(status: string): string {
  return (uz.status as Record<string, string>)[status] ?? status;
}

export function auditActionLabel(action: string): string {
  return (uz.auditActions as Record<string, string>)[action] ?? action;
}

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("uz-UZ", {
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
  return n.toLocaleString("uz-UZ");
}

export { uz };
