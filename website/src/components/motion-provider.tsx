"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useSyncExternalStore,
} from "react";
import { MotionConfig } from "motion/react";

const MotionContext = createContext(false);
const query = "(prefers-reduced-motion: reduce)";
function subscribe(callback: () => void) {
  const media = window.matchMedia(query);
  media.addEventListener("change", callback);
  return () => media.removeEventListener("change", callback);
}
export function useCinematicMotion() {
  return useContext(MotionContext);
}

export function MotionProvider({ children }: { children: React.ReactNode }) {
  const reduced = useSyncExternalStore(
    subscribe,
    () => window.matchMedia(query).matches,
    () => true,
  );
  const [paused, setPaused] = useState(false);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    try {
      setPaused(localStorage.getItem("tlm-motion-paused") === "true");
    } catch {
      /* Optional preference storage. */
    }
    setReady(true);
  }, []);
  const enabled = ready && !reduced && !paused;
  return (
    <MotionContext.Provider value={enabled}>
      <MotionConfig reducedMotion={enabled ? "never" : "always"}>
        <div className="motion-root" data-motion={enabled}>
          {children}
          <button
            className="motion-control"
            disabled={reduced}
            aria-pressed={paused || reduced}
            aria-label={
              reduced
                ? "System reduced motion is enabled"
                : paused
                  ? "Enable cinematic motion"
                  : "Pause cinematic motion"
            }
            onClick={() => {
              const next = !paused;
              setPaused(next);
              try {
                localStorage.setItem("tlm-motion-paused", String(next));
              } catch {
                /* Still works without storage. */
              }
            }}
          >
            <span aria-hidden>{enabled ? "Ⅱ" : "▷"}</span>
            {reduced
              ? "Reduced motion"
              : enabled
                ? "Pause motion"
                : "Enable motion"}
          </button>
        </div>
      </MotionConfig>
    </MotionContext.Provider>
  );
}
