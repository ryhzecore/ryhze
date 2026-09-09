export type User = { username: string; role: "viewer" | "admin" };
export type Stream = { url: string; type?: string };
export type Episode = { title: string; streams: Stream[] };
export type Title = {
  id: string;
  title: string;
  kind: "game" | "film";
  label: string;
  status: string;
  description: string;
  image: string;
  imageNote?: string;
  categories: string[];
  streams: Stream[];
  preview?: string;
  seasons?: { title: string; episodes: Episode[] }[];
  download?: string;
  internal?: boolean;
  facts?: { label: string; value: string }[];
};
export type Page =
  | "home"
  | "games"
  | "films"
  | "saved"
  | "about"
  | "contact"
  | "privacy"
  | "login"
  | "activate"
  | "admin"
  | "not-found";
