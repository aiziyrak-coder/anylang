import type { Metadata } from "next";
import { Providers } from "@/components/providers";
import { Suspense } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "AnyLang Admin — Boshqaruv paneli",
  description: "AnyLang operatsion konsoli — foydalanuvchilar, raqamlar, obunalar va moderatsiya",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="uz" suppressHydrationWarning>
      <body className="antialiased font-sans bg-[var(--background)] text-[var(--foreground)]">
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('anylang_admin_theme');var d=t==='dark'||(t!=='light'&&window.matchMedia('(prefers-color-scheme: dark)').matches);if(d)document.documentElement.classList.add('dark');}catch(e){}})();`,
          }}
        />
        <Providers>
          <Suspense fallback={null}>{children}</Suspense>
        </Providers>
      </body>
    </html>
  );
}
