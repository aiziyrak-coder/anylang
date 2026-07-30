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
    <html lang="uz">
      <body className="antialiased font-sans">
        <Providers>
          <Suspense fallback={null}>{children}</Suspense>
        </Providers>
      </body>
    </html>
  );
}
