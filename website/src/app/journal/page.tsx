import { getEntries } from "@/lib/journal";
import { JournalFilter } from "@/components/journal-filter";
export const metadata = {
  title: "Development journal",
  description:
    "Follow the creation of The Last Monsoon. World building, art direction, and development notes.",
  alternates: { canonical: "/journal" },
};
export default function Journal() {
  return (
    <main id="main" className="section journal-page">
      <p className="eyebrow">Field notes / The Last Monsoon</p>
      <h1>
        From a world
        <br />
        <em>in the making.</em>
      </h1>
      <p className="lead">The development journal.</p>
      <p className="content-note sample-notice">
        These are sample entries with illustrative dates and statuses. They do
        not report completed game work.
      </p>
      <JournalFilter entries={getEntries()} />
    </main>
  );
}
