import { backendFetch } from "@/lib/server-api";
import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

const COOKIE = "admin_token";

async function handle(request: NextRequest, params: Promise<{ path: string[] }>) {
  const { path } = await params;
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) {
    return NextResponse.json(
      { message: "Unauthorized", error_code: "UNAUTHORIZED" },
      { status: 401 },
    );
  }

  const targetPath = `/${path.join("/")}`;
  const search = request.nextUrl.search;
  const body =
    request.method !== "GET" && request.method !== "HEAD"
      ? await request.arrayBuffer()
      : undefined;

  const res = await backendFetch(`${targetPath}${search}`, {
    method: request.method,
    body: body ? Buffer.from(body) : undefined,
    token,
    headers: {
      Accept: request.headers.get("accept") ?? "application/json",
      ...(body ? { "Content-Type": request.headers.get("content-type") ?? "application/json" } : {}),
    },
  });

  const contentType = res.headers.get("content-type") ?? "application/json";
  const payload = await res.arrayBuffer();

  return new NextResponse(payload, {
    status: res.status,
    headers: {
      "Content-Type": contentType,
      ...(res.headers.get("content-disposition")
        ? { "Content-Disposition": res.headers.get("content-disposition")! }
        : {}),
    },
  });
}

export async function GET(request: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  return handle(request, ctx.params);
}

export async function POST(request: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  return handle(request, ctx.params);
}

export async function PATCH(request: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  return handle(request, ctx.params);
}

export async function DELETE(request: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  return handle(request, ctx.params);
}
