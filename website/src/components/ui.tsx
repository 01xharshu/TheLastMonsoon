import Link from "next/link";
import Image from "next/image";
import type { Entry } from "@/lib/journal";
import { formatDate } from "@/lib/date";
export function SectionTitle({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="section-heading">
      <p className="eyebrow">{eyebrow}</p>
      <h2>{title}</h2>
      {children}
    </div>
  );
}
export function JournalCard({ entry }: { entry: Entry }) {
  return (
    <article className="journal-card">
      <Link
        href={`/journal/${entry.slug}`}
        className="image-link"
        tabIndex={-1}
        aria-hidden="true"
      >
        <Image
          src={entry.image}
          alt=""
          fill
          sizes="(max-width: 700px) 100vw, 33vw"
        />
        <span className="image-label">
          {entry.placeholder ? "Placeholder illustration" : "Development media"}
        </span>
      </Link>
      <div className="journal-meta">
        <time dateTime={entry.date}>{formatDate(entry.date)}</time>
        <span>{entry.category}</span>
      </div>
      <h3>
        <Link href={`/journal/${entry.slug}`}>{entry.title}</Link>
      </h3>
      <p>{entry.description}</p>
      <div className="card-end">
        <span className="status">
          {entry.placeholder ? "Sample · " : ""}
          {entry.status}
        </span>
        <Link
          href={`/journal/${entry.slug}`}
          aria-label={`Read ${entry.title}`}
        >
          Read entry <span aria-hidden>↗</span>
        </Link>
      </div>
    </article>
  );
}
export function Footer() {
  return (
    <footer>
      <Link className="wordmark" href="/">
        THE LAST<span>MONSOON</span>
      </Link>
      <p>
        A world in the making.
        <br />A story waiting to be told.
      </p>
      <div>
        <a href="/#story">About the game</a>
        <Link href="/journal">Development journal</Link>
        <a href="/#media">Media</a>
      </div>
      <small>
        © {new Date().getFullYear()} The Last Monsoon. In development.
        <br />
        All current images are AI-generated concept placeholders, not game
        captures.
      </small>
      <a href="#top" className="back-top">
        Back to top ↑
      </a>
    </footer>
  );
}
