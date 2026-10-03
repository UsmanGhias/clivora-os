"use client";

import Image from "next/image";
import { cn } from "@/lib/utils";

interface LogoProps {
  size?: "sm" | "md" | "lg" | "xl";
  showText?: boolean;
  /** Text color for dark headers vs light surfaces */
  variant?: "onDark" | "onLight";
  className?: string;
}

const sizes = {
  sm: { mark: 32, wordmark: { width: 128, height: 32 } },
  md: { mark: 40, wordmark: { width: 160, height: 40 } },
  lg: { mark: 56, wordmark: { width: 224, height: 56 } },
  xl: { mark: 72, wordmark: { width: 288, height: 72 } },
};

/** Canonical CLIVORA mark + wordmark, use everywhere (app, Connect, Pro, admin). */
export function Logo({
  size = "md",
  showText = true,
  variant = "onDark",
  className,
}: LogoProps) {
  const s = sizes[size];
  const wordmarkSrc =
    variant === "onDark" ? "/brand/clivora-logo-on-dark.png" : "/brand/clivora-logo-on-light.png";

  return (
    <div className={cn("flex items-center", className)}>
      {showText ? (
        <Image
          src={wordmarkSrc}
          alt="Clivora"
          width={s.wordmark.width}
          height={s.wordmark.height}
          className="h-auto w-auto"
          priority
        />
      ) : (
        <div
          className="relative shrink-0 overflow-hidden rounded-xl shadow-md shadow-black/20"
          style={{ width: s.mark, height: s.mark }}
        >
          <Image
            src="/brand/clivora-navbar-mark.png"
            alt="Clivora"
            width={s.mark}
            height={s.mark}
            className="h-full w-full object-contain"
            priority
          />
        </div>
      )}
    </div>
  );
}
