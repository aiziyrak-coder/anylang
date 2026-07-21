import Link from "next/link";
import { t } from "@/lib/i18n";

export default function HomePage() {
  return (
    <main className="min-h-screen">
      <div className="relative overflow-hidden">
        <div
          className="pointer-events-none absolute inset-0 opacity-80"
          style={{
            background:
              "radial-gradient(ellipse 80% 50% at 50% -20%, rgba(200,245,66,0.35), transparent), linear-gradient(180deg, #f7f7f5 0%, #eceae4 100%)",
          }}
        />
        <div className="relative mx-auto flex min-h-screen max-w-3xl flex-col justify-center px-6 py-16">
          <p className="text-sm font-medium tracking-[0.2em] text-zinc-500 uppercase">
            {t("nav.operations")}
          </p>
          <h1 className="mt-3 text-5xl font-semibold tracking-tight text-zinc-900 sm:text-6xl">
            {t("app.name")}
          </h1>
          <p className="mt-4 max-w-xl text-lg text-zinc-600">
            {t("app.subtitle")}. FastAPI{" "}
            <code className="rounded bg-black/5 px-1.5 py-0.5 text-sm">/api/v1/admin</code>{" "}
            bilan bog‘langan.
          </p>
          <div className="mt-10 flex flex-wrap gap-3">
            <Link
              href="/login"
              className="inline-flex items-center justify-center rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition hover:opacity-90"
            >
              {t("home.cta")}
            </Link>
            {process.env.NEXT_PUBLIC_API_URL ? (
              <a
                href={`${process.env.NEXT_PUBLIC_API_URL.replace(/\/$/, "")}/docs`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center justify-center rounded-lg border border-zinc-200 bg-white px-5 py-2.5 text-sm font-medium text-zinc-900 transition hover:bg-black/[0.03]"
              >
                {t("home.apiDocs")}
              </a>
            ) : null}
          </div>
        </div>
      </div>
    </main>
  );
}
