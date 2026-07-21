import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";
const SUPERADMIN_PATHS = ["/dashboard/chats", "/dashboard/restore", "/dashboard/audit", "/dashboard/maintenance"];

export function middleware(request: NextRequest) {
  const token = request.cookies.get(COOKIE)?.value;
  const { pathname } = request.nextUrl;

  if (pathname.startsWith("/dashboard")) {
    if (!token) {
      return NextResponse.redirect(new URL("/login", request.url));
    }
    // Role check happens server-side; middleware only gates auth presence.
    if (SUPERADMIN_PATHS.some((p) => pathname.startsWith(p))) {
      // Optional: decode JWT role — backend enforces regardless.
    }
  }

  if (pathname === "/login" && token) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
};
