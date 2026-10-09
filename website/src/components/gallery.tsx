"use client";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { useCinematicMotion } from "./motion-provider";
const media = [
  {
    src: "/media/monsoon.webp",
    title: "The rain remembers",
    type: "Artwork",
    alt: "AI concept study of a rain-soaked palace and fort beside a misty Indian river",
  },
  {
    src: "/media/forest.webp",
    title: "Under an endless canopy",
    type: "Artwork",
    alt: "AI concept study of an ancient banyan forest with sunbeams through monsoon mist",
  },
  {
    src: "/media/river.webp",
    title: "Where the river leads",
    type: "Screenshot slot",
    alt: "AI concept study of a moored wooden boat beside riverside stone steps at dawn",
  },
];
export function Gallery() {
  const [selected, setSelected] = useState(0);
  const dialog = useRef<HTMLDialogElement>(null);
  const enabled = useCinematicMotion();
  const [open, setOpen] = useState(false);
  const swipe = useRef<number | null>(null);
  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);
  const change = (direction: number) =>
    setSelected(
      (current) => (current + direction + media.length) % media.length,
    );
  return (
    <>
      <div className="media-grid">
        {media.map((item, i) => (
          <button
            key={item.src}
            className="media-item"
            onClick={() => {
              setSelected(i);
              setOpen(true);
              dialog.current?.showModal();
            }}
            aria-label={`View ${item.title}, placeholder ${item.type.toLowerCase()}`}
          >
            <Image
              src={item.src}
              alt={item.alt}
              fill
              sizes="(max-width: 700px) 100vw, 50vw"
            />
            <span className="image-label">Placeholder · {item.type}</span>
            <span className="media-caption">
              {item.title}
              <span aria-hidden>↗</span>
            </span>
          </button>
        ))}
      </div>
      <dialog
        ref={dialog}
        className="lightbox"
        aria-labelledby="lightbox-title"
        aria-describedby="lightbox-note"
        onClose={() => setOpen(false)}
        onKeyDown={(event) => {
          if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
            event.preventDefault();
            change(event.key === "ArrowRight" ? 1 : -1);
          }
        }}
        onClick={(e) => {
          if (e.target === e.currentTarget) dialog.current?.close();
        }}
      >
        <motion.div
          className="lightbox-content"
          initial={false}
          animate={
            open && enabled
              ? { opacity: [0, 1], scale: [0.97, 1], y: [18, 0] }
              : { opacity: 1, scale: 1, y: 0 }
          }
          transition={{
            duration: enabled ? 0.45 : 0,
            ease: [0.22, 1, 0.36, 1],
          }}
        >
          <button
            className="lightbox-close"
            aria-label="Close image viewer"
            onClick={() => dialog.current?.close()}
          >
            Close ×
          </button>
          <div
            className="lightbox-image"
            onPointerDown={(event) => {
              swipe.current = event.clientX;
            }}
            onPointerUp={(event) => {
              if (
                swipe.current !== null &&
                Math.abs(event.clientX - swipe.current) > 55
              )
                change(event.clientX < swipe.current ? 1 : -1);
              swipe.current = null;
            }}
            onPointerCancel={() => {
              swipe.current = null;
            }}
          >
            <AnimatePresence initial={false}>
              <motion.div
                key={media[selected].src}
                className="gallery-slide"
                initial={enabled ? { opacity: 0, scale: 1.035 } : false}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0 }}
                transition={{
                  duration: enabled ? 0.45 : 0,
                  ease: [0.22, 1, 0.36, 1],
                }}
              >
                <Image
                  src={media[selected].src}
                  alt={media[selected].alt}
                  fill
                  sizes="90vw"
                  draggable={false}
                />
              </motion.div>
            </AnimatePresence>
          </div>
          <h3 id="lightbox-title">{media[selected].title}</h3>
          <p id="lightbox-note">
            AI-generated environment concept placeholder. Not captured in-game.
          </p>
          <div className="lightbox-controls">
            <button onClick={() => change(-1)} aria-label="Previous image">
              ← Previous
            </button>
            <span aria-live="polite">
              {selected + 1} / {media.length}
            </span>
            <button onClick={() => change(1)} aria-label="Next image">
              Next →
            </button>
          </div>
        </motion.div>
      </dialog>
    </>
  );
}
