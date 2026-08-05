import { API_BASE } from "@/lib/env";

export { API_BASE };

function resolveBackendUrl(path: string): { url: string; hostHeader?: string } {
  const base = API_BASE;
  const normalized = path.startsWith("/") ? path : `/${path}`;
  const url = path.startsWith("http") ? path : `${base}${normalized}`;
  // Docker-internal hostname is rejected by TrustedHostMiddleware unless allowed.
  // Prefer Host: public domain when talking to http://api:8000.
  if (base.includes("://api:") || base.includes("://api/")) {
    return { url, hostHeader: "anylang.uz" };
  }
  return { url };
}

export async function backendFetch(
  path: string,
  init: RequestInit & { token?: string } = {},
): Promise<Response> {
  const { token, headers, ...rest } = init;
  const { url, hostHeader } = resolveBackendUrl(path);
  return fetch(url, {
    ...rest,
    headers: {
      ...(rest.body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(hostHeader ? { Host: hostHeader } : {}),
      ...headers,
    },
  });
}
