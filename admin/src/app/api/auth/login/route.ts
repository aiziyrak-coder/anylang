import { backendFetch } from "@/lib/server-api";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";

export async function POST(request: Request) {
  const body = await request.json();
  let res: Response;
  let data: Record<string, unknown>;
  try {
    res = await backendFetch("/api/v1/admin/auth/login", {
      method: "POST",
      body: JSON.stringify(body),
    });
    data = await res.json();
  } catch {
    return NextResponse.json(
      { message: "Backend unavailable", error_code: "BAD_GATEWAY" },
      { status: 502 },
    );
  }
  if (!res.ok) {
    return NextResponse.json(data, { status: res.status });
  }

  const jar = await cookies();
  const basePath = (process.env.NEXT_PUBLIC_BASE_PATH || "").trim() || "/";
  jar.set(COOKIE, data.access_token as string, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    // Cookie only for the obscure admin path — not the whole site.
    path: basePath,
    maxAge: (data.expires_in as number) ?? 28800,
  });

  return NextResponse.json({
    admin: data.admin,
    expires_in: data.expires_in,
  });
}
