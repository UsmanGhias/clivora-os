"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useState, type ReactNode } from "react";
import { AuthAnimProvider } from "./AuthAnimContext";
import { AuthCharacters } from "./AuthCharacters";
import "./auth-animated.css";

const THEME_KEY = "clivora.auth-animated.theme";
const DESKTOP_MQ = "(min-width: 1024px)";

function BrandMark({ className }: { className?: string }) {
  return (
    <span className={className ?? "aa-brand-mark"}>
      <Image src="/brand/clivora-mark.png" alt="" width={28} height={28} className="h-7 w-7" />
    </span>
  );
}

function ThemeToggleButton({
  theme,
  onToggle,
  className,
}: {
  theme: "light" | "dark";
  onToggle: () => void;
  className?: string;
}) {
  return (
    <button
      type="button"
      className={className ?? "aa-theme-toggle"}
      onClick={onToggle}
      aria-label={theme === "dark" ? "Switch to light theme" : "Switch to dark theme"}
      title="Toggle theme"
    >
      {theme === "dark" ? (
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
        </svg>
      )}
    </button>
  );
}

export function AuthAnimatedShell({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [isDesktop, setIsDesktop] = useState(false);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(THEME_KEY);
      if (saved === "dark" || saved === "light") {
        setTheme(saved);
      }
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    const mq = window.matchMedia(DESKTOP_MQ);
    const sync = () => setIsDesktop(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  function toggleTheme() {
    setTheme((prev) => {
      const next = prev === "dark" ? "light" : "dark";
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch {
        /* ignore */
      }
      return next;
    });
  }

  return (
    <AuthAnimProvider>
      <div className={`auth-animated${theme === "dark" ? " theme-dark" : ""}`}>
        <main className="aa-page">
          {/* Animated stage: desktop only */}
          <section className="aa-stage" aria-hidden={!isDesktop}>
            <div className="aa-stage-top">
              <Link href="/" className="aa-brand">
                <BrandMark />
                <span className="aa-brand-text">
                  <span className="aa-brand-name">CLIVORA</span>
                  <span className="aa-brand-sub">Freelancer OS</span>
                </span>
              </Link>
            </div>

            <div className="aa-stage-inner">{isDesktop ? <AuthCharacters /> : null}</div>

            <nav className="aa-footer-links aa-footer-links-desktop">
              <Link href="/privacy">Privacy Policy</Link>
              <Link href="/terms">Terms of Service</Link>
              <Link href="/edition">Contact</Link>
            </nav>
          </section>

          <section className="aa-panel">
            <header className="aa-mobile-chrome">
              <Link href="/" className="aa-brand aa-mobile-brand-link">
                <BrandMark />
                <span className="aa-brand-text">
                  <span className="aa-brand-name">CLIVORA</span>
                  <span className="aa-brand-sub">Freelancer OS</span>
                </span>
              </Link>
              <Link href="/" className="aa-mobile-home">
                ← Back to home
              </Link>
            </header>

            <Link href="/" className="aa-back-home aa-back-home-desktop">
              ← Home
            </Link>
            <ThemeToggleButton
              theme={theme}
              onToggle={toggleTheme}
              className="aa-theme-toggle aa-theme-toggle-panel"
            />

            <div className="aa-panel-inner">
              {children}
              <nav className="aa-footer-links aa-footer-links-mobile">
                <Link href="/privacy">Privacy</Link>
                <Link href="/terms">Terms</Link>
                <Link href="/edition">Contact</Link>
              </nav>
            </div>
          </section>
        </main>
      </div>
    </AuthAnimProvider>
  );
}
