import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { getEntries } from "@/lib/journal";
import { formatDate } from "@/lib/date";
export const dynamicParams = false;
export function generateStaticParams() {
  return getEntries().map(({ slug }) => ({ slug }));
}
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const entry = getEntries().find((e) => e.slug === slug);
  if (!entry) return {};
  return {
    title: entry.title,
    description: entry.description,
    alternates: { canonical: `/journal/${slug}` },
    openGraph: {
      type: "article",
      title: entry.title,
      description: entry.description,
      publishedTime: `${entry.date}T00:00:00Z`,
    },
  };
}
export default async function Article({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const entry = getEntries().find((e) => e.slug === slug);
  if (!entry) notFound();
  return (
    <main id="main" className="article-page section">
      <Link href="/journal" className="text-link">
        ← All journal entries
      </Link>
      <article>
        <header className="article-heading">
          <p className="eyebrow">
            {entry.category} / {entry.status}
          </p>
          <h1>{entry.title}</h1>
          <p className="lead">{entry.description}</p>
          <time dateTime={entry.date}>{formatDate(entry.date)}</time>
        </header>
        {entry.placeholder && (
          <aside className="sample-notice content-note">
            Sample entry — illustrative content, date, and status. Not an actual
            development announcement.
          </aside>
        )}
        <figure className="article-figure">
          <div>
            <Image
              src={entry.image}
              alt={`${entry.title} — ${entry.placeholder ? "placeholder illustration" : "development image"}`}
              fill
              sizes="(max-width: 900px) 100vw, 900px"
            />
          </div>
          <figcaption>
            {entry.placeholder
              ? "AI-generated concept placeholder. Not an in-game screenshot."
              : "Development media."}
          </figcaption>
        </figure>
        <div className="prose">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>
            {entry.body}
          </ReactMarkdown>
        </div>
      </article>
      <Link href="/journal" className="text-link">
        ← Return to the journal
      </Link>
    </main>
  );
}
