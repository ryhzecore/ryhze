type Name =
  | "search"
  | "arrow"
  | "back"
  | "close"
  | "play"
  | "pause"
  | "plus"
  | "check"
  | "sound"
  | "mute"
  | "expand"
  | "menu"
  | "sun"
  | "film"
  | "game"
  | "logout";
const paths: Record<Name, string> = {
  search: "m21 21-5-5 M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0",
  arrow: "M4 12h16m-6-6 6 6-6 6",
  back: "M20 12H4m6-6-6 6 6 6",
  close: "m6 6 12 12M6 18 18 6",
  play: "m8 5 11 7-11 7Z",
  pause: "M8 5v14M16 5v14",
  plus: "M12 5v14M5 12h14",
  check: "m5 12 4 4L19 6",
  sound: "m11 5-6 4H2v6h3l6 4ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14",
  mute: "m11 5-6 4H2v6h3l6 4Zm5 4 6 6m0-6-6 6",
  expand: "M4 9V4h5m6 0h5v5M4 15v5h5m6 0h5v-5",
  menu: "M4 8h16M4 16h16",
  sun: "M12 3v2m0 14v2M3 12h2m14 0h2M6 6l1 1m10 10 1 1M6 18l1-1M17 7l1-1M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  film: "M3 4h18v16H3ZM7 4v16M17 4v16M3 9h4M3 15h4M17 9h4M17 15h4",
  game: "M7 7h10c4 0 6 11 3 12-2 1-4-3-5-3H9c-1 0-3 4-5 3-3-1-1-12 3-12ZM6 10v5m-2-2h4m7-2h.1m3 3h.1",
  logout: "M9 4H4v16h5m4-8h8m-4-4 4 4-4 4",
};
export function Icon({ name, size = 20 }: { name: Name; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[name]} />
    </svg>
  );
}
