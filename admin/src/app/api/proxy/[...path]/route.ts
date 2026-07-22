import { backendFetch } from "@/lib/server-api";
import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

const COOKIE = "admin_token";
const ALLOWED_PREFIX = "/api/v1/admin";

function assertAdminPath(targetPath: string): boolean {
  return targetPath === ALLOWED_PREFIX || targetPath.startsWith(`${ALLOWED_PREFIX}/`);
}

function assertSameOrigin(request: NextRequest): boolean {
  if (request.method === "GET" || request.method === "HEAD") return true;
  const origin = request.headers.get("origin");
  if (!origin) {
    // Same-origin fetches from some browsers omit Origin on same-site navigations;
    // require Sec-Fetch-Site when present.
    const site = request.headers.get("sec-fetch-site");
    return site === null || site === "same-origin" || site === "same-site";
  }
  try {
    return new URL(origin).origin === request.nextUrl.origin;
  } catch {
    return false;
  }
}

async function handle(request: NextRequest, params: Promise<{ path: string[] }>) {
  const { path } = await params;
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) {
    return NextResponse.json(
      { message: "Unauthorized", error_code: "UNAUTHORIZED" },
      { status: 401 },
    );
  }

  if (!assertSameOrigin(request)) {
    return NextResponse.json(
      { message: "Invalid origin", error_code: "CSRF_REJECTED" },
      { status: 403 },
    );
  }

  const targetPath = `/${path.join("/")}`;
  if (!assertAdminPath(targetPath)) {
    return NextResponse.json(
      { message: "Proxy path not allowed", error_code: "FORBIDDEN" },
      { status: 403 },
    );
  }

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
