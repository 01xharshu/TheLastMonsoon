import type { Metadata } from "next";
import { MotionProvider } from "@/components/motion-provider";
import { Navigation } from "@/components/navigation";
import { Footer } from "@/components/ui";
import { siteUrl, description } from "@/lib/site";
import "@fontsource/cormorant-garamond/latin-500.css";
import "@fontsource/cormorant-garamond/latin-500-italic.css";
import "@fontsource/cormorant-garamond/latin-600.css";
import "./globals.css";
export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "The Last Monsoon — Official Game Website",
    template: "%s | The Last Monsoon",
  },
  description,
  openGraph: {
    type: "website",
    locale: "en_US",
    siteName: "The Last Monsoon",
    title: "The Last Monsoon",
    description,
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "The Last Monsoon — 1850s India. A world in the making.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "The Last Monsoon",
    description,
    images: ["/opengraph-image"],
  },
  robots: { index: true, follow: true },
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body id="top">
        <a className="skip-link" href="#main">
          Skip to content
        </a>
        <MotionProvider>
          <Navigation />
          {children}
          <Footer />
        </MotionProvider>
      </body>
    </html>
  );
}
