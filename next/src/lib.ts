export async function api<T>(path: string, body?: unknown): Promise<T> {
  const response = await fetch(path, {
    method: body === undefined ? "GET" : "POST",
    credentials: "same-origin",
    cache: "no-store",
    signal: AbortSignal.timeout(15000),
    headers:
      body === undefined ? undefined : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await response
    .json()
    .catch(() => ({ error: "Unable to connect. Please try again." }));
  if (!response.ok) throw new Error(data.error || "Please try again.");
  return data as T;
}
export function stored<T>(key: string, fallback: T): T {
  try {
    const value = localStorage.getItem(key);
    return value === null ? fallback : JSON.parse(value);
  } catch {
    return fallback;
  }
}
export function save(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}
export function mediaUrl(value: string | undefined) {
  try {
    const url = new URL(value || "", location.origin);
    return url.origin === location.origin &&
      /^\/media\/(Films|Games)\//.test(url.pathname)
      ? url.href
      : null;
  } catch {
    return null;
  }
}
export const ease = [0.22, 0.68, 0.18, 1] as const;
