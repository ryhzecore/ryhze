import { download } from "./downloads.mjs";
import auth, { session } from "./auth.mjs";
import originals from "./catalog.json" with { type: "json" };
import internal from "./internal-catalog.json" with { type: "json" };
const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "private, no-store",
    },
  });
const redirect = (to) =>
  new Response(null, { status: 303, headers: { Location: to } });
const appPaths = new Set([
  "/",
  "/games",
  "/films",
  "/saved",
  "/about",
  "/contact",
  "/privacy",
  "/login",
  "/activate",
  "/admin",
  "/menu/",
  "/lobby.html",
  "/index.html",
  "/player.html",
  "/game.html",
]);
async function handle(request, env) {
  const url = new URL(request.url),
    path = url.pathname;
  if (url.hostname === "www.ryhze.com")
    return redirect("https://ryhze.com" + path + url.search);
  if (url.hostname === "video.ryhze.com")
    return json({ error: "Use the Ryhze player." }, 410);
  if (path === "/home") return redirect("/");
  if (path.startsWith("/downloads/")) return download(request, env);
  if (path === "/api/discover")
    return request.method === "GET"
      ? json(originals)
      : json({ error: "Method not allowed" }, 405);
  if (path === "/api/catalog") {
    if (request.method !== "GET")
      return json({ error: "Method not allowed" }, 405);
    if (!(await session(request, env)))
      return json({ error: "Sign in required." }, 401);
    return json([...originals, ...internal]);
  }
  if (path.startsWith("/api/") || path.startsWith("/media/"))
    return auth.fetch(request, env);
  if (!["GET", "HEAD"].includes(request.method))
    return json({ error: "Method not allowed" }, 405);
  if (
    path === "/admin" ||
    path === "/saved" ||
    path.startsWith("/private-art/")
  ) {
    const user = await session(request, env);
    if (!user) return redirect("/login?next=" + encodeURIComponent(path));
    if (path === "/admin" && user.role !== "admin")
      return json({ error: "Administrator access required." }, 403);
  }
  if (
    [
      "/menu/",
      "/lobby.html",
      "/index.html",
      "/player.html",
      "/game.html",
    ].includes(path)
  )
    return redirect("/games");
  if (appPaths.has(path)) {
    url.pathname = "/index.html";
    return env.ASSETS.fetch(new Request(url, request));
  }
  if (/^\/(assets|brand|art|private-art)\//.test(path))
    return env.ASSETS.fetch(request);
  url.pathname = "/index.html";
  const page = await env.ASSETS.fetch(new Request(url, request));
  return new Response(page.body, { status: 404, headers: page.headers });
}
export default {
  async fetch(request, env) {
    let response;
    try {
      response = await handle(request, env);
    } catch (error) {
      console.error("Ryhze request failed", error.name);
      response = json(
        { error: "Connection interrupted. Please try again." },
        503,
      );
    }
    const result = new Response(response.body, response);
    result.headers.set(
      "Content-Security-Policy",
      "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; media-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; object-src 'none'; form-action 'self'",
    );
    result.headers.set("X-Content-Type-Options", "nosniff");
    result.headers.set("X-Frame-Options", "DENY");
    result.headers.set("Referrer-Policy", "same-origin");
    result.headers.set(
      "Permissions-Policy",
      "camera=(),microphone=(),geolocation=()",
    );
    result.headers.set("Strict-Transport-Security", "max-age=31536000");
    result.headers.set(
      "Cache-Control",
      /^\/(assets|brand|art)\//.test(new URL(request.url).pathname) && result.ok
        ? "public, max-age=3600"
        : "private, no-store",
    );
    return result;
  },
  scheduled: auth.scheduled,
};
