import { backendFetch } from "@/lib/server-api";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";

export async function POST(request: Request) {
  const body = await request.json();
  const res = await backendFetch("/api/v1/admin/auth/login", {
    method: "POST",
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) {
    return NextResponse.json(data, { status: res.status });
  }

  const jar = await cookies();
  jar.set(COOKIE, data.access_token as string, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/",
    maxAge: (data.expires_in as number) ?? 28800,
  });

  return NextResponse.json({
    admin: data.admin,
    expires_in: data.expires_in,
  });
}
