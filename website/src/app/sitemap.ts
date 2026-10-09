import type { MetadataRoute } from "next";
import { siteUrl } from "@/lib/site";
import { getEntries } from "@/lib/journal";
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: siteUrl },
    { url: `${siteUrl}/journal` },
    ...getEntries().map((entry) => ({
      url: `${siteUrl}/journal/${entry.slug}`,
      lastModified: new Date(entry.date),
    })),
  ];
}
