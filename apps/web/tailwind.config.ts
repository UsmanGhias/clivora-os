import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#0D9488",
          light: "#CCFBF1",
          dark: "#0F766E",
        },
        accent: "#F59E0B",
        brand: {
          purple: "#7C5CFF",
          "purple-dark": "#5B3FD9",
        },
        navy: {
          DEFAULT: "#0F172A",
          light: "#1E293B",
        },
        /** Client portal — slate (mirrors Flutter ClivoraColors.client*) */
        client: {
          accent: "#475569",
          "accent-light": "#F8FAFC",
          surface: "#F1F5F9",
          muted: "#94A3B8",
          header: "#334155",
        },
        background: "#FAFAF9",
        surface: "#ffffff",
        success: "#10B981",
        warning: "#F59E0B",
        error: "#DC2626",
        "text-primary": "#0F172A",
        "text-secondary": "#64748B",
        "text-muted": "#94A3B8",
        border: "#E2E8F0",
        "dark-bg": "#0B1120",
        "dark-surface": "#1E293B",
        "dark-border": "#334155",
      },
      fontFamily: {
        sans: [
          "var(--font-jakarta)",
          "Plus Jakarta Sans",
          "ui-sans-serif",
          "system-ui",
          "sans-serif",
        ],
        display: [
          "var(--font-sora)",
          "Sora",
          "var(--font-jakarta)",
          "ui-sans-serif",
          "system-ui",
          "sans-serif",
        ],
      },
      backgroundImage: {
        "brand-gradient": "linear-gradient(135deg, #0F172A 0%, #0D9488 100%)",
        "client-gradient": "linear-gradient(135deg, #1E293B 0%, #64748B 100%)",
        "logo-gradient":
          "linear-gradient(135deg, #0F172A 0%, #0D9488 100%)",
      },
    },
  },
  plugins: [],
};

export default config;
