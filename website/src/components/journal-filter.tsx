"use client";
import { useState } from "react";
import { JournalCard } from "./ui";
import type { Entry } from "@/lib/journal";
export function JournalFilter({ entries }: { entries: Entry[] }) {
  const [category, setCategory] = useState("All updates");
  const categories = [
    "All updates",
    ...new Set(entries.map((e) => e.category)),
  ];
  return (
    <>
      <div
        className="filters"
        role="group"
        aria-label="Filter updates by category"
      >
        {categories.map((c) => (
          <button
            key={c}
            aria-pressed={c === category}
            onClick={() => setCategory(c)}
          >
            {c}
          </button>
        ))}
      </div>
      <p className="sr-only" role="status">
        {
          entries.filter(
            (e) => category === "All updates" || e.category === category,
          ).length
        }{" "}
        updates shown
      </p>
      <div className="journal-grid">
        {entries
          .filter((e) => category === "All updates" || e.category === category)
          .map((entry) => (
            <JournalCard key={entry.slug} entry={entry} />
          ))}
      </div>
    </>
  );
}
