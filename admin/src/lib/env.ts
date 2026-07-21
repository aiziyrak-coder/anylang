import { z } from "zod";

const schema = z.object({
  NEXT_PUBLIC_API_URL: z.string().url(),
});

export const env = schema.parse({
  NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000",
});

export const API_BASE = env.NEXT_PUBLIC_API_URL.replace(/\/$/, "");
