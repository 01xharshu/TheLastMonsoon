import Link from "next/link";
export default function NotFound() {
  return (
    <main id="main" className="section journal-page">
      <p className="eyebrow">404 / Off the path</p>
      <h1>This path ends here.</h1>
      <p>The page you’re looking for could not be found.</p>
      <Link className="button" href="/">
        Return home →
      </Link>
    </main>
  );
}
