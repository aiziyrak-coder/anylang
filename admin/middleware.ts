import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";
const SUPERADMIN_PATHS = [
  "/dashboard/chats",
  "/dashboard/restore",
  "/dashboard/audit",
  "/dashboard/maintenance",
];

function roleFromJwt(token: string): string | null {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const json = Buffer.from(parts[1].replace(/-/g, "+").replace(/_/g, "/"), "base64").toString(
      "utf8",
    );
    const payload = JSON.parse(json) as { role?: string; type?: string; exp?: number };
    if (payload.type !== "admin") return null;
    if (typeof payload.exp === "number" && payload.exp * 1000 < Date.now()) return null;
    return payload.role ?? null;
  } catch {
    return null;
  }
}

export function middleware(request: NextRequest) {
  const token = request.cookies.get(COOKIE)?.value;
  const { pathname } = request.nextUrl;
  // basePath=/admin is stripped from pathname in middleware
  const path = pathname;

  if (path.startsWith("/dashboard")) {
    if (!token) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    const role = roleFromJwt(token);
    if (!role) {
      const res = NextResponse.redirect(new URL("/login", request.url));
      res.cookies.delete(COOKIE);
      return res;
    }
    if (SUPERADMIN_PATHS.some((p) => path.startsWith(p)) && role !== "superadmin") {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
  }

  if (path === "/login" && token) {
    const role = roleFromJwt(token);
    if (role) {
      return NextResponse.redirect(new URL("/dashboard", request.url));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
};
