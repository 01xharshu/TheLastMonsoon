"use client";
import { motion } from "motion/react";
import { useCinematicMotion } from "./motion-provider";
export function Reveal({
  children,
  className = "",
  delay = 0,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}) {
  const enabled = useCinematicMotion();
  return (
    <motion.div
      className={className}
      initial={false}
      whileInView={
        enabled ? { y: [35, 0], opacity: [0.25, 1] } : { y: 0, opacity: 1 }
      }
      viewport={{ once: true, amount: 0.18 }}
      transition={{
        duration: enabled ? 0.9 : 0,
        delay: enabled ? delay : 0,
        ease: [0.22, 1, 0.36, 1],
      }}
    >
      {children}
    </motion.div>
  );
}
