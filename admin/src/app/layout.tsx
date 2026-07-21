import type { Metadata } from "next";
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
      <body className="antialiased font-sans">{children}</body>
    </html>
  );
}
