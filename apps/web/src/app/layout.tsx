import type { Metadata } from "next";
import { site } from "@/lib/site";
import { GoogleAnalytics } from "@/components/common/GoogleAnalytics";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(
    (() => {
      try {
        return new URL(site.url).toString();
      } catch {
        return "http://localhost:3000";
      }
    })(),
  ),
  title: {
    default: `${site.name} | ${site.tagline}`,
    template: `%s | ${site.name}`,
  },
  description: site.shortDescription,
  openGraph: {
    title: `${site.name} | ${site.tagline}`,
    description: site.shortDescription,
    url: site.url,
    siteName: site.name,
    type: "website",
    images: [{ url: "/brand/clivora-og-share-1200x630.png", width: 1200, height: 630, alt: site.name }],
  },
  icons: {
    icon: [{ url: "/favicon.ico" }, { url: "/favicon.svg", type: "image/svg+xml" }],
    apple: "/apple-touch-icon.png",
  },
  robots: {
    index: false,
    follow: false,
    nocache: true,
    googleBot: {
      index: false,
      follow: false,
      noimageindex: true,
      "max-video-preview": -1,
      "max-image-preview": "none",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <GoogleAnalytics />
      </head>
      <body className="min-h-screen overflow-x-hidden font-sans">{children}</body>
    </html>
  );
}
