import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";

export async function POST() {
  const jar = await cookies();
  const basePath = (process.env.NEXT_PUBLIC_BASE_PATH || "").trim() || "/";
  jar.set(COOKIE, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: basePath,
    maxAge: 0,
  });
  return NextResponse.json({ ok: true });
}
