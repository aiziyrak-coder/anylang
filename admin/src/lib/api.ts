/**
 * Typed client for AnyLang admin API via same-origin BFF proxy.
 * JWT is stored in HttpOnly cookie — never in localStorage.
 */

import { withBase } from "@/lib/base-path";

export class ApiError extends Error {
  constructor(
    public status: number,
    public errorCode: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function proxyUrl(path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `/api/proxy${normalized}`;
}

async function parseError(res: Response): Promise<ApiError> {
  let message = res.statusText;
  let errorCode = "HTTP_ERROR";
  try {
    const body = (await res.json()) as { message?: string; error_code?: string };
    message = body.message ?? message;
    errorCode = body.error_code ?? errorCode;
  } catch {
    /* ignore */
  }
  return new ApiError(res.status, errorCode, message);
}

export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(proxyUrl(path), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init.headers,
    },
  });

  if (!res.ok) {
    if (res.status === 401 && typeof window !== "undefined") {
      window.location.href = withBase("/login");
    }
    throw await parseError(res);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export async function apiFetchBlob(path: string): Promise<{ blob: Blob; filename: string }> {
  const res = await fetch(proxyUrl(path));
  if (!res.ok) {
    if (res.status === 401 && typeof window !== "undefined") {
      window.location.href = withBase("/login");
    }
    throw await parseError(res);
  }
  const disposition = res.headers.get("content-disposition") ?? "";
  const match = disposition.match(/filename="([^"]+)"/);
  const filename = match?.[1] ?? "download.bin";
  return { blob: await res.blob(), filename };
}

/** @deprecated Use BFF proxy; kept for home page external link only */
export { API_BASE } from "@/lib/env";
