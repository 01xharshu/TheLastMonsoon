"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useRef, useState } from "react";
import { useMotionValueEvent, useScroll } from "motion/react";
const links = [
  ["The story", "/#story"],
  ["The world", "/#world"],
  ["Journal", "/journal"],
  ["Media", "/#media"],
];
export function Navigation() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const toggle = useRef<HTMLButtonElement>(null);
  const [scrolled, setScrolled] = useState(false);
  const { scrollY } = useScroll();
  useMotionValueEvent(scrollY, "change", (y) => setScrolled(y > 85));
  return (
    <header
      className={`site-header${scrolled ? " is-scrolled" : ""}`}
      onKeyDown={(event) => {
        if (event.key === "Escape" && open) {
          setOpen(false);
          toggle.current?.focus();
        }
      }}
    >
      <Link href="/" className="wordmark" aria-label="The Last Monsoon home">
        THE LAST<span>MONSOON</span>
      </Link>
      <button
        ref={toggle}
        className="menu-toggle"
        aria-expanded={open}
        aria-controls="main-navigation"
        onClick={() => setOpen(!open)}
      >
        {open ? "Close" : "Menu"} <span aria-hidden>≡</span>
      </button>
      <nav
        id="main-navigation"
        aria-label="Main navigation"
        className={open ? "navigation is-open" : "navigation"}
      >
        {links.map(([label, href]) => (
          <Link
            key={href}
            href={href}
            aria-current={
              href === "/journal" && pathname.startsWith("/journal")
                ? "page"
                : undefined
            }
            onClick={() => setOpen(false)}
          >
            {label}
          </Link>
        ))}
        <a className="nav-cta" href="/#follow" onClick={() => setOpen(false)}>
          Follow the journey <span aria-hidden>↗</span>
        </a>
      </nav>
    </header>
  );
}
