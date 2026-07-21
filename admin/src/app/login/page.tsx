"use client";

import { ApiError } from "@/lib/api";
import { refreshAdminProfile, setAdminProfile, setSessionExpiry } from "@/lib/auth";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";

type LoginResponse = {
  admin: {
    id: number;
    email: string;
    full_name: string;
    role: string;
  };
  expires_in: number;
};

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = (await res.json()) as LoginResponse & { error_code?: string; message?: string };
      if (!res.ok) {
        throw new ApiError(res.status, data.error_code ?? "HTTP_ERROR", data.message ?? t("login.failed"));
      }
      setAdminProfile(data.admin);
      setSessionExpiry(data.expires_in);
      await refreshAdminProfile();
      router.replace("/dashboard");
    } catch (err) {
      if (err instanceof ApiError) {
        setError(
          err.errorCode === "TOO_MANY_ATTEMPTS"
            ? err.message
            : err.message || t("login.failed"),
        );
      } else {
        setError(t("login.failed"));
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-zinc-500">
            {t("app.name")}
          </p>
          <h1 className="mt-2 text-2xl font-semibold text-zinc-900">{t("login.title")}</h1>
          <p className="mt-2 text-sm text-zinc-600">{t("login.subtitle")}</p>
        </div>

        <form
          onSubmit={handleSubmit}
          className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          {error ? (
            <div
              role="alert"
              className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
            >
              {error}
            </div>
          ) : null}

          <div className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-zinc-700">
                {t("login.email")}
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className="mt-1 block w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm text-zinc-900 shadow-sm outline-none transition focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
                placeholder="admin@anylang.com"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-zinc-700">
                {t("login.password")}
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                minLength={8}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                className="mt-1 block w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm text-zinc-900 shadow-sm outline-none transition focus:border-zinc-900 focus:ring-1 focus:ring-zinc-900"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className={cn(
              "mt-6 w-full rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-zinc-800",
              loading && "cursor-not-allowed opacity-70",
            )}
          >
            {loading ? t("login.submitting") : t("login.submit")}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-zinc-500">{t("login.hint")}</p>
      </div>
    </main>
  );
}
