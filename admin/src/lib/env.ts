import { z } from "zod";

const schema = z.object({
  NEXT_PUBLIC_API_URL: z.string().url(),
});

export const env = schema.parse({
  NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000",
});

/** Browser-facing API origin (CSP / public). */
export const PUBLIC_API_BASE = env.NEXT_PUBLIC_API_URL.replace(/\/$/, "");

/**
 * Server-side BFF → backend.
 * Prefer docker-internal URL so lists/proxy never fail on hairpin/SSL.
 */
export const API_BASE = (
  process.env.API_INTERNAL_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  "http://127.0.0.1:8000"
).replace(/\/$/, "");
