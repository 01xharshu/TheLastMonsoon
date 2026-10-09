import {
  CinematicHero,
  WorldChapter,
  StoryStatement,
} from "@/components/cinematic";
import Link from "next/link";
import { Reveal } from "@/components/reveal";
import { JournalCard, SectionTitle } from "@/components/ui";
import { Gallery } from "@/components/gallery";
import { getEntries } from "@/lib/journal";
export const metadata = { alternates: { canonical: "/" } };
export default function Home() {
  const entries = getEntries();
  return (
    <main id="main">
      <CinematicHero
        bottom={
          <>
            <a href="#story">
              <span className="scroll-line" />
              Scroll to explore
            </a>
            <span>AI concept study · Not gameplay</span>
            <span className="hero-coordinate">INDIA / 1850s</span>
          </>
        }
      >
        <p className="eyebrow">
          A historical action-adventure · In development
        </p>
        <h1 id="hero-title">
          <span>THE LAST</span>MONSOON
        </h1>
        <p className="hero-tagline">
          Beneath the rain.
          <br /> Beyond the empire.
        </p>
        <p className="hero-description">
          Enter a world inspired by 1850s colonial India.
          <br />
          Follow the making of The Last Monsoon.
        </p>
        <div className="hero-actions">
          <a className="button" href="#world">
            Discover the world <span aria-hidden>↗</span>
          </a>
          <Link className="text-link" href="/journal">
            Inside the development <span aria-hidden>→</span>
          </Link>
        </div>
      </CinematicHero>
      <div className="chapter-strip">
        <span>A land of stories</span>
        <span className="diamond" aria-hidden>
          ◆
        </span>
        <span>An era of change</span>
        <span className="diamond" aria-hidden>
          ◆
        </span>
        <span>A journey in the making</span>
      </div>
      <StoryStatement />
      <section id="story" className="section story-section">
        <Reveal>
          <p className="eyebrow">01 / The story</p>
          <h2>
            Some stories are written.
            <br />
            <em>Others are lived.</em>
          </h2>
        </Reveal>
        <Reveal className="story-copy" delay={0.16}>
          <p className="lead">
            1850s. Colonial India.
            <br />
            The monsoon is gathering.
          </p>
          <p>
            The Last Monsoon is a historical action-adventure set against a
            landscape of dense forests, riverways, and historical architecture.
          </p>
          <p>
            A world shaped by its people and its past. A setting where the
            weight of an era meets the intimacy of a personal journey.
          </p>
          <p className="content-note">
            Introductory atmosphere copy. Full story and gameplay details will
            be shared as development progresses.
          </p>
          <a className="text-link" href="/journal">
            Follow the story’s creation <span aria-hidden>→</span>
          </a>
        </Reveal>
      </section>
      <section id="world" className="world-section">
        <div className="section">
          <Reveal>
            <SectionTitle
              eyebrow="02 / The world"
              title="A land that stays with you."
            >
              <p>
                From the stillness beneath the canopy to the hush before a
                storm.
                <br />
                Explore the visual direction of a world taking shape.
              </p>
            </SectionTitle>
          </Reveal>
          <div className="world-grid cinematic-chapters">
            {[
              {
                number: "I",
                title: "Echoes of an empire",
                text: "Weathered architecture. Silent courtyards. History carried in stone.",
                image: "monsoon",
              },
              {
                number: "II",
                title: "Into the green",
                text: "Dense canopies and hidden paths, beneath a sky heavy with rain.",
                image: "forest",
              },
              {
                number: "III",
                title: "Along the river",
                text: "Open waters, distant banks, and a landscape in constant motion.",
                image: "river",
              },
            ].map((item, index) => (
              <WorldChapter key={item.number} {...item} index={index} />
            ))}
          </div>
        </div>
      </section>
      <section className="quote-section">
        <span className="ornament" aria-hidden>
          ✦
        </span>
        <p>
          “The rain passes.
          <br />
          <em>The land remembers.</em>”
        </p>
        <span className="eyebrow">An atmosphere line for The Last Monsoon</span>
      </section>
      <section className="section" id="journal">
        <div className="section-top">
          <SectionTitle
            eyebrow="03 / Development journal"
            title="From behind the scenes."
          >
            <p>Notes from a world in the making.</p>
          </SectionTitle>
          <Link className="text-link" href="/journal">
            All journal entries <span aria-hidden>↗</span>
          </Link>
        </div>
        <p className="content-note sample-notice">
          The entries below are clearly labeled samples, ready to be replaced
          with actual development updates.
        </p>
        <div className="journal-grid">
          {entries.slice(0, 3).map((entry) => (
            <Reveal key={entry.slug} delay={entries.indexOf(entry) * 0.1}>
              <JournalCard entry={entry} />
            </Reveal>
          ))}
        </div>
      </section>
      <section className="section media-section" id="media">
        <div className="section-top">
          <SectionTitle eyebrow="04 / Media" title="Glimpses of the monsoon.">
            <p>A collection of moods, landscapes, and visual ideas.</p>
          </SectionTitle>
          <span className="content-note">
            AI concept collection / 03 images
          </span>
        </div>
        <Gallery />
      </section>
      <section id="follow" className="follow-section">
        <p className="eyebrow">Stay with the story</p>
        <h2>
          The journey
          <br />
          <em>is just beginning.</em>
        </h2>
        <p>
          Follow the development journal for future news,
          <br />
          world explorations, and glimpses behind the scenes.
        </p>
        <Link className="button" href="/journal">
          Explore the journal <span aria-hidden>↗</span>
        </Link>
        <small>
          In development. Release date and platforms have not been announced.
        </small>
      </section>
    </main>
  );
}
