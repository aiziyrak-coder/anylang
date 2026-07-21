const ADMIN_PROFILE_KEY = "anylang_admin_profile";
const ADMIN_EXPIRES_KEY = "anylang_admin_expires_at";

export type AdminProfile = {
  id: number;
  email: string;
  full_name: string;
  role: string;
};

export function setAdminProfile(profile: AdminProfile): void {
  if (typeof window === "undefined") return;
  sessionStorage.setItem(ADMIN_PROFILE_KEY, JSON.stringify(profile));
}

export function setSessionExpiry(expiresInSeconds: number): void {
  if (typeof window === "undefined") return;
  const expiresAt = Date.now() + expiresInSeconds * 1000;
  sessionStorage.setItem(ADMIN_EXPIRES_KEY, String(expiresAt));
}

export function isSessionExpired(): boolean {
  if (typeof window === "undefined") return true;
  const raw = sessionStorage.getItem(ADMIN_EXPIRES_KEY);
  if (!raw) return false;
  return Date.now() >= Number(raw);
}

export function getAdminProfile(): AdminProfile | null {
  if (typeof window === "undefined") return null;
  if (isSessionExpired()) return null;
  const raw = sessionStorage.getItem(ADMIN_PROFILE_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AdminProfile;
  } catch {
    return null;
  }
}

export function isSuperAdmin(): boolean {
  return getAdminProfile()?.role === "superadmin";
}

export function isModeratorPlus(): boolean {
  const role = getAdminProfile()?.role;
  return role === "superadmin" || role === "moderator";
}

export async function clearAdminSession(): Promise<void> {
  if (typeof window === "undefined") return;
  sessionStorage.removeItem(ADMIN_PROFILE_KEY);
  sessionStorage.removeItem(ADMIN_EXPIRES_KEY);
  await fetch("/api/auth/logout", { method: "POST" });
}

/** Load fresh profile from backend (validates cookie + role). */
export async function refreshAdminProfile(): Promise<AdminProfile | null> {
  const res = await fetch("/api/auth/me");
  if (!res.ok) return null;
  const profile = (await res.json()) as AdminProfile;
  setAdminProfile(profile);
  return profile;
}
