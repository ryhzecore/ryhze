import { motion } from "motion/react";
import { ease } from "./lib";
import "./artwork-flight.css";

export type ArtworkRect = {
  left: number;
  top: number;
  width: number;
  height: number;
  borderRadius: number;
};
export type ArtworkFlightState = {
  id: number;
  sourceId: string;
  image: string;
  from: ArtworkRect;
  to: ArtworkRect;
  returning: boolean;
};

export function artworkRect(element: Element | null): ArtworkRect | null {
  if (!element) return null;
  const rect = element.getBoundingClientRect();
  if (!rect.width || !rect.height) return null;
  return {
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    borderRadius:
      parseFloat(getComputedStyle(element).borderTopLeftRadius) || 0,
  };
}

export function artworkSource(sourceId: string) {
  return (
    Array.from(
      document.querySelectorAll<HTMLElement>("[data-artwork-source]"),
    ).find((element) => element.dataset.artworkSource === sourceId) || null
  );
}

// A separate fixed layer keeps the moving image outside the dialog's scroll clipping.
// Its opacity stays at one; the real artwork takes over only after it reaches the frame.
export function ArtworkFlight({
  flight,
  onComplete,
}: {
  flight: ArtworkFlightState;
  onComplete: () => void;
}) {
  return (
    <motion.div
      key={flight.id}
      data-artwork-flight
      className="artwork-flight"
      initial={flight.from}
      animate={flight.to}
      transition={{ duration: 0.7, ease }}
      onAnimationComplete={onComplete}
      aria-hidden="true"
    >
      <img src={flight.image} alt="" onError={onComplete} />
    </motion.div>
  );
}
