/** Frontend RBAC — mirrors backend role matrix. */

export type AdminRole = "superadmin" | "moderator" | "support" | "finance";

export type Permission =
  | "overview"
  | "users"
  | "verification"
  | "applications"
  | "subscriptions"
  | "promos"
  | "payments"
  | "chats"
  | "restore"
  | "audit"
  | "numberGroups"
  | "products"
  | "reviews"
  | "maintenance";

const ROLE_PERMS: Record<AdminRole, Permission[]> = {
  superadmin: [
    "overview",
    "users",
    "verification",
    "applications",
    "subscriptions",
    "promos",
    "payments",
    "chats",
    "restore",
    "audit",
    "numberGroups",
    "products",
    "reviews",
    "maintenance",
  ],
  moderator: [
    "overview",
    "users",
    "verification",
    "applications",
    "numberGroups",
    "products",
    "reviews",
  ],
  support: ["overview", "users", "verification", "chats", "restore"],
  finance: ["overview", "subscriptions", "promos", "payments"],
};

export const PATH_PERMISSION: { prefix: string; permission: Permission }[] = [
  { prefix: "/dashboard/users", permission: "users" },
  { prefix: "/dashboard/verification", permission: "verification" },
  { prefix: "/dashboard/applications", permission: "applications" },
  { prefix: "/dashboard/subscriptions", permission: "subscriptions" },
  { prefix: "/dashboard/promo-codes", permission: "promos" },
  { prefix: "/dashboard/payments", permission: "payments" },
  { prefix: "/dashboard/chats", permission: "chats" },
  { prefix: "/dashboard/restore", permission: "restore" },
  { prefix: "/dashboard/audit", permission: "audit" },
  { prefix: "/dashboard/number-groups", permission: "numberGroups" },
  { prefix: "/dashboard/products", permission: "products" },
  { prefix: "/dashboard/reviews", permission: "reviews" },
  { prefix: "/dashboard/maintenance", permission: "maintenance" },
  { prefix: "/dashboard", permission: "overview" },
];

export function normalizeRole(role: string | null | undefined): AdminRole {
  if (role === "moderator" || role === "support" || role === "finance") return role;
  return "superadmin";
}

export function can(role: string | null | undefined, permission: Permission): boolean {
  const r = normalizeRole(role);
  return ROLE_PERMS[r].includes(permission);
}

export function permissionForPath(pathname: string): Permission {
  const hit = PATH_PERMISSION.find((p) => {
    if (p.prefix === "/dashboard") return pathname === "/dashboard" || pathname === "/dashboard/";
    return pathname.startsWith(p.prefix);
  });
  return hit?.permission ?? "overview";
}

export function canAccessPath(role: string | null | undefined, pathname: string): boolean {
  return can(role, permissionForPath(pathname));
}

export function firstAllowedPath(role: string | null | undefined): string {
  const r = normalizeRole(role);
  const order = PATH_PERMISSION.map((p) => p.prefix);
  for (const prefix of order) {
    const perm = PATH_PERMISSION.find((p) => p.prefix === prefix)?.permission;
    if (perm && ROLE_PERMS[r].includes(perm)) {
      return prefix === "/dashboard" ? "/dashboard" : prefix;
    }
  }
  return "/dashboard";
}
