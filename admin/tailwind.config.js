/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#1a1a1a",
          accent: "#c8f542",
          muted: "#6b7280",
        },
      },
    },
  },
  plugins: [],
};
