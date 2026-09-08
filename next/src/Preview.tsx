import { useEffect, useRef, useState } from "react";
import { motion } from "motion/react";
import { mediaUrl } from "./lib";

export function Preview({
  url,
  active,
  sound,
  reduced,
  onPlaying,
}: {
  url: string;
  active: boolean;
  sound: boolean;
  reduced: boolean;
  onPlaying: (playing: boolean) => void;
}) {
  const video = useRef<HTMLVideoElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const node = video.current;
    if (!node) return;
    let cancelled = false,
      frame = 0;
    const fade = (target: number) => {
      const from = node.volume,
        started = performance.now();
      const tick = (now: number) => {
        const progress = Math.min(1, (now - started) / 650);
        node.volume = from + (target - from) * progress;
        if (progress < 1) frame = requestAnimationFrame(tick);
        else if (!active) {
          node.pause();
          onPlaying(false);
        }
      };
      frame = requestAnimationFrame(tick);
    };
    const timer = setTimeout(
      async () => {
        if (!active) return;
        node.muted = !sound;
        node.volume = 0;
        try {
          await node.play();
        } catch {
          node.muted = true;
          try {
            await node.play();
          } catch {
            return;
          }
        }
        if (cancelled) return;
        setVisible(true);
        onPlaying(true);
        fade(sound ? 0.3 : 0);
      },
      active ? 1100 : 0,
    );
    if (!active) {
      setVisible(false);
      fade(0);
    }
    return () => {
      cancelled = true;
      clearTimeout(timer);
      cancelAnimationFrame(frame);
    };
  }, [active, sound, onPlaying]);
  useEffect(() => () => onPlaying(false), [onPlaying]);
  return (
    <motion.video
      ref={video}
      className="card-preview"
      src={mediaUrl(url) || undefined}
      muted
      playsInline
      loop
      preload="none"
      aria-hidden="true"
      animate={{ opacity: visible ? 1 : 0 }}
      transition={{ duration: reduced ? 0 : 0.65 }}
    />
  );
}
