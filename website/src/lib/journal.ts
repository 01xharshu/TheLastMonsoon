import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
export type Entry = {
  slug: string;
  title: string;
  date: string;
  description: string;
  category: string;
  image: string;
  status: "Concept" | "In development" | "Update";
  placeholder: boolean;
  body: string;
};
const directory = path.join(process.cwd(), "content/journal");
export function getEntries(): Entry[] {
  return fs
    .readdirSync(directory)
    .filter((file) => file.endsWith(".md"))
    .map((file) => {
      const { data, content } = matter(
        fs.readFileSync(path.join(directory, file), "utf8"),
      );
      for (const field of [
        "title",
        "date",
        "description",
        "category",
        "image",
        "status",
      ])
        if (typeof data[field] !== "string" || !data[field])
          throw new Error(`${file}: missing ${field}`);
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(data.date) ||
        Number.isNaN(Date.parse(data.date)) ||
        new Date(data.date).toISOString().slice(0, 10) !== data.date
      )
        throw new Error(`${file}: invalid date`);
      if (!["Concept", "In development", "Update"].includes(data.status))
        throw new Error(`${file}: invalid status`);
      if (typeof data.placeholder !== "boolean")
        throw new Error(`${file}: placeholder must be boolean`);
      if (
        !data.image.startsWith("/media/") ||
        !fs.existsSync(path.join(process.cwd(), "public", data.image))
      )
        throw new Error(`${file}: image must exist in public/media`);
      return {
        ...data,
        slug: file.replace(/\.md$/, ""),
        body: content,
      } as Entry;
    })
    .sort((a, b) => b.date.localeCompare(a.date));
}
