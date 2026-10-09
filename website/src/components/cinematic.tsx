"use client";

import Image from "next/image";
import { useRef, useSyncExternalStore } from "react";
import { motion, useScroll, useTransform } from "motion/react";
import { useCinematicMotion } from "./motion-provider";

function subscribeViewport(callback: () => void) {
  const query = window.matchMedia("(min-width: 701px)");
  query.addEventListener("change", callback);
  return () => query.removeEventListener("change", callback);
}

export function CinematicHero({
  children,
  bottom,
}: {
  children: React.ReactNode;
  bottom: React.ReactNode;
}) {
  const ref = useRef<HTMLElement>(null);
  const enabled = useCinematicMotion();
  const wide = useSyncExternalStore(
    subscribeViewport,
    () => window.matchMedia("(min-width: 701px)").matches,
    () => false,
  );
  const { scrollYProgress } = useScroll({
    target: ref,
    offset:
      wide && enabled
        ? ["start start", "end end"]
        : ["start start", "end start"],
  });
  const imageY = useTransform(scrollYProgress, [0, 1], ["0%", "12%"]);
  const montageScale = useTransform(scrollYProgress, [0, 0.55], [1, 1.65]);
  const montageOpacity = useTransform(
    scrollYProgress,
    [0, 0.18, 0.48],
    [1, 1, 0],
  );
  const leftY = useTransform(scrollYProgress, [0, 0.5], [0, -90]);
  const rightY = useTransform(scrollYProgress, [0, 0.5], [0, 110]);
  const contentScale = useTransform(scrollYProgress, [0, 0.6], [1, 0.9]);
  const imageScale = useTransform(scrollYProgress, [0, 1], [1.08, 1.18]);
  const contentY = useTransform(scrollYProgress, [0, 1], [0, -110]);
  const opacity = useTransform(scrollYProgress, [0, 0.55, 0.9], [1, 1, 0]);
  return (
    <section
      ref={ref}
      data-cinematic={enabled}
      className="hero-sequence"
      aria-labelledby="hero-title"
    >
      <div className="hero cinematic-hero">
        <div className="hero-image-window">
          <motion.div
            className="hero-image-layer"
            style={
              enabled ? { y: imageY, scale: imageScale } : { y: "0%", scale: 1 }
            }
          >
            <Image
              className="hero-art"
              src="/media/monsoon.webp"
              alt="AI-generated concept placeholder of historical architecture beside a monsoon river"
              fill
              priority
              sizes="100vw"
            />
          </motion.div>
        </div>
        <motion.div
          className="hero-montage"
          aria-hidden="true"
          style={
            enabled
              ? { scale: montageScale, opacity: montageOpacity }
              : { scale: 1, opacity: 1 }
          }
        >
          <motion.div
            className="montage-panel montage-forest"
            style={enabled ? { y: leftY } : { y: 0 }}
          >
            <Image
              src="/media/forest.webp"
              alt=""
              fill
              sizes="(max-width:700px) 35vw, 30vw"
            />
          </motion.div>
          <div className="montage-panel montage-palace">
            <Image
              src="/media/monsoon.webp"
              alt=""
              fill
              sizes="(max-width:700px) 65vw, 60vw"
            />
          </div>
          <motion.div
            className="montage-panel montage-river"
            style={enabled ? { y: rightY } : { y: 0 }}
          >
            <Image
              src="/media/river.webp"
              alt=""
              fill
              sizes="(max-width:700px) 35vw, 30vw"
            />
          </motion.div>
        </motion.div>
        <div className="hero-shade" />
        <div className="monsoon-rain" aria-hidden="true" />
        <motion.div
          className="hero-content"
          style={
            enabled
              ? { y: contentY, opacity, scale: contentScale }
              : { y: 0, opacity: 1, scale: 1 }
          }
        >
          {children}
        </motion.div>
        <div className="hero-bottom">{bottom}</div>
      </div>
    </section>
  );
}

export function WorldChapter({
  number,
  title,
  text,
  image,
  index,
}: {
  number: string;
  title: string;
  text: string;
  image: string;
  index: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const enabled = useCinematicMotion();
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "end start"],
  });
  const scale = useTransform(scrollYProgress, [0, 0.8, 1], [1.18, 1.02, 1.02]);
  const y = useTransform(scrollYProgress, [0, 1], ["-5%", "5%"]);
  const textY = useTransform(
    scrollYProgress,
    [0, 0.28, 0.7, 1],
    [70, 0, 0, -45],
  );
  const opacity = useTransform(
    scrollYProgress,
    [0, 0.17, 0.72, 1],
    [0.25, 1, 1, 0.25],
  );
  const line = useTransform(scrollYProgress, [0.15, 0.82], [0, 1]);
  const insetY = useTransform(
    scrollYProgress,
    [0, 0.3, 0.85, 1],
    [110, 25, -65, -110],
  );
  const insetRotate = useTransform(
    scrollYProgress,
    [0, 1],
    [index % 2 ? -4 : 4, 0],
  );
  const insetClip = useTransform(
    scrollYProgress,
    [0.05, 0.35],
    ["inset(0% 0% 100% 0%)", "inset(0% 0% 0% 0%)"],
  );
  return (
    <div
      ref={ref}
      className="world-chapter"
      data-cinematic={enabled}
      data-side={index % 2 ? "right" : "left"}
    >
      <div className="world-card">
        <motion.div
          className="chapter-image-layer"
          style={enabled ? { scale, y } : { scale: 1, y: "0%" }}
        >
          <Image
            src={`/media/${image}.webp`}
            alt={`${title} — AI-generated environment concept placeholder`}
            fill
            sizes="100vw"
          />
        </motion.div>
        <div className="world-card-shade" />
        <span className="world-number">CHAPTER {number}</span>
        <motion.div
          className="world-caption"
          style={enabled ? { y: textY, opacity } : { y: 0, opacity: 1 }}
        >
          <p className="eyebrow">World study</p>
          <h3>{title}</h3>
          <p>{text}</p>
          <small>AI-generated concept placeholder · Not gameplay</small>
        </motion.div>
        <motion.div
          className="chapter-inset"
          aria-hidden="true"
          style={
            enabled
              ? { y: insetY, rotate: insetRotate, clipPath: insetClip }
              : { y: 0, rotate: 0, clipPath: "inset(0%)" }
          }
        >
          <Image
            src={`/media/${image}.webp`}
            alt=""
            fill
            sizes="(max-width:700px) 38vw, 27vw"
          />
          <span>FIELD STUDY / 0{index + 1}</span>
        </motion.div>
        <div className="chapter-progress" aria-hidden="true">
          <motion.span style={enabled ? { scaleX: line } : { scaleX: 1 }} />
        </div>
      </div>
    </div>
  );
}

const statement =
  "A land shaped by the rain. A world carrying the weight of an era. A journey waiting to be lived.";
function StoryWord({
  word,
  index,
  total,
  progress,
  enabled,
}: {
  word: string;
  index: number;
  total: number;
  progress: import("motion/react").MotionValue<number>;
  enabled: boolean;
}) {
  const start = index / (total + 5);
  const opacity = useTransform(progress, [start, start + 0.12], [0.22, 1]);
  return (
    <motion.span style={enabled ? { opacity } : { opacity: 1 }}>
      {word}{" "}
    </motion.span>
  );
}
export function StoryStatement() {
  const ref = useRef<HTMLElement>(null);
  const enabled = useCinematicMotion();
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start 0.85", "end 0.35"],
  });
  const words = statement.split(" ");
  return (
    <section
      ref={ref}
      className="story-statement"
      aria-labelledby="statement-heading"
    >
      <p className="eyebrow">1850s / Colonial India</p>
      <h2 id="statement-heading" aria-label={statement}>
        <span aria-hidden="true">
          {words.map((word, index) => (
            <StoryWord
              key={index}
              word={word}
              index={index}
              total={words.length}
              progress={scrollYProgress}
              enabled={enabled}
            />
          ))}
        </span>
      </h2>
      <p className="statement-note">
        The Last Monsoon · A historical action-adventure in development
      </p>
    </section>
  );
}
