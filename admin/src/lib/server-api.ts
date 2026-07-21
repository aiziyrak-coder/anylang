import { API_BASE } from "@/lib/env";

export { API_BASE };

export async function backendFetch(
  path: string,
  init: RequestInit & { token?: string } = {},
): Promise<Response> {
  const { token, headers, ...rest } = init;
  const url = path.startsWith("http") ? path : `${API_BASE}${path.startsWith("/") ? path : `/${path}`}`;
  return fetch(url, {
    ...rest,
    headers: {
      ...(rest.body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
  });
}
