import type { NextConfig } from "next";

const apiUrl = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://127.0.0.1:8000";
const isProd = process.env.NODE_ENV === "production";

const connectSrc = isProd
  ? `'self' ${apiUrl}`
  : `'self' ${apiUrl} http://127.0.0.1:* http://localhost:* ws://127.0.0.1:* ws://localhost:*`;

const scriptSrc = isProd ? "'self' 'unsafe-inline'" : "'self' 'unsafe-inline' 'unsafe-eval'";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  output: "standalone",
  async headers() {
    const securityHeaders = [
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "X-Frame-Options", value: "DENY" },
      { key: "Referrer-Policy", value: "no-referrer" },
      {
        key: "Permissions-Policy",
        value: "camera=(), microphone=(), geolocation=()",
      },
      {
        key: "Content-Security-Policy",
        value: [
          "default-src 'self'",
          `script-src ${scriptSrc}`,
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data: blob: https:",
          `connect-src ${connectSrc}`,
          "frame-ancestors 'none'",
          "base-uri 'self'",
          "form-action 'self'",
        ].join("; "),
      },
    ];

    if (isProd) {
      securityHeaders.push({
        key: "Strict-Transport-Security",
        value: "max-age=31536000; includeSubDomains",
      });
    }

    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
