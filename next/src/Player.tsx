import { useEffect, useRef, useState } from "react";
import { motion } from "motion/react";
import { Icon } from "./Icon";
import { mediaUrl } from "./lib";
import type { Title } from "./types";
export function Player({ title, reduced }: { title: Title; reduced: boolean }) {
  const video = useRef<HTMLVideoElement>(null),
    [active, setActive] = useState(false),
    [loading, setLoading] = useState(false),
    [error, setError] = useState(""),
    [paused, setPaused] = useState(true),
    [muted, setMuted] = useState(false),
    [time, setTime] = useState(0),
    [duration, setDuration] = useState(0),
    [season, setSeason] = useState(0),
    [episode, setEpisode] = useState(0);
  const attempt = useRef(0);
  const streams = title.seasons?.length
    ? title.seasons[season]?.episodes[episode]?.streams || []
    : title.streams;
  const available = streams.some((stream) => mediaUrl(stream.url));
  useEffect(
    () => () => {
      attempt.current++;
      video.current?.pause();
    },
    [],
  );
  function stop() {
    attempt.current++;
    video.current?.pause();
    setActive(false);
    setLoading(false);
    setTime(0);
  }
  async function start() {
    if (loading) return;
    const id = ++attempt.current;
    setLoading(true);
    setError("");
    const node = video.current!;
    let success = false;
    for (const stream of streams) {
      const url = mediaUrl(stream.url);
      if (!url) continue;
      node.src = url;
      try {
        await node.play();
        if (id !== attempt.current) return;
        success = true;
        break;
      } catch {
        if (id !== attempt.current) return;
      }
    }
    setLoading(false);
    setActive(success);
    if (!success)
      setError("This video could not be loaded. Try again in a moment.");
  }
  const fmt = (v: number) =>
    Number.isFinite(v)
      ? `${Math.floor(v / 60)}:${String(Math.floor(v % 60)).padStart(2, "0")}`
      : "0:00";
  return (
    <div className="player">
      {!!title.seasons?.length && (
        <div className="episode-picker">
          <label>
            Season
            <select
              value={season}
              onChange={(e) => {
                stop();
                setSeason(Number(e.target.value));
                setEpisode(0);
              }}
            >
              {title.seasons.map((s, i) => (
                <option value={i} key={i}>
                  {s.title}
                </option>
              ))}
            </select>
          </label>
          <label>
            Episode
            <select
              value={episode}
              onChange={(e) => {
                stop();
                setEpisode(Number(e.target.value));
              }}
            >
              {title.seasons[season]?.episodes.map((s, i) => (
                <option value={i} key={i}>
                  {s.title}
                </option>
              ))}
            </select>
          </label>
        </div>
      )}
      <div
        className="screen"
        style={{
          backgroundImage: title.image ? `url("${title.image}")` : undefined,
        }}
      >
        <motion.video
          ref={video}
          playsInline
          preload="metadata"
          animate={{ opacity: active ? 1 : 0 }}
          transition={{ duration: reduced ? 0 : 0.35 }}
          aria-label={title.title}
          onPlay={() => setPaused(false)}
          onPause={() => setPaused(true)}
          onLoadedMetadata={() => setDuration(video.current?.duration || 0)}
          onTimeUpdate={() => setTime(video.current?.currentTime || 0)}
          onEnded={() => {
            stop();
            setPaused(true);
          }}
          onError={() => {
            if (!loading && active) {
              stop();
              setError("Playback was interrupted. Select Play to retry.");
            }
          }}
        />
        {!active && (
          <div className="screen-message">
            <span className="eyebrow">
              {available
                ? "Ready when you are"
                : title.internal
                  ? "Internal library"
                  : "In development"}
            </span>
            <h3>{available ? "Settle into the story." : "More to come."}</h3>
            <p>
              {available
                ? ""
                : "No playable video has been added to this title yet."}
            </p>
            {available && (
              <button
                className="button primary"
                onClick={start}
                disabled={loading}
              >
                <Icon name="play" />
                {loading ? "Loading…" : error ? "Try again" : "Play"}
              </button>
            )}
            <p role="status" className="error">
              {error}
            </p>
          </div>
        )}
      </div>
      {active && (
        <div className="playback-bar">
          <button
            className="icon-button"
            aria-label={paused ? "Play" : "Pause"}
            onClick={() => {
              const node = video.current!;
              if (node.paused)
                node.play().catch(() => setError("Playback could not resume."));
              else node.pause();
            }}
          >
            <Icon name={paused ? "play" : "pause"} />
          </button>
          <label className="seek">
            <span className="sr-only">Playback position</span>
            <input
              type="range"
              min={0}
              max={Number.isFinite(duration) ? duration : 0}
              step={0.1}
              value={time}
              onChange={(e) => {
                if (video.current)
                  video.current.currentTime = Number(e.target.value);
                setTime(Number(e.target.value));
              }}
            />
          </label>
          <span className="time">
            {fmt(time)} / {fmt(duration)}
          </span>
          <button
            className="icon-button"
            aria-label={muted ? "Unmute" : "Mute"}
            onClick={() => {
              if (video.current) video.current.muted = !muted;
              setMuted(!muted);
            }}
          >
            <Icon name={muted ? "mute" : "sound"} />
          </button>
          <button
            className="icon-button"
            aria-label="Full screen"
            onClick={() => {
              if (document.fullscreenElement)
                document.exitFullscreen().catch(() => {});
              else
                video.current
                  ?.closest(".title-panel")
                  ?.requestFullscreen()
                  .catch(() =>
                    setError("Full screen is unavailable in this browser."),
                  );
            }}
          >
            <Icon name="expand" />
          </button>
        </div>
      )}
      {active && error && (
        <p className="error" role="status">
          {error}
        </p>
      )}
    </div>
  );
}
