import { backendFetch } from "@/lib/server-api";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

const COOKIE = "admin_token";

export async function GET() {
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) {
    return NextResponse.json(
      { message: "Unauthorized", error_code: "UNAUTHORIZED" },
      { status: 401 },
    );
  }

  const res = await backendFetch("/api/v1/admin/me", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
