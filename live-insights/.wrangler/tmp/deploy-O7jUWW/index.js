var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
var allowedOrigins = /* @__PURE__ */ new Set([
  "https://ryhzecore.github.io",
  "https://ryhze.com",
  "https://www.ryhze.com",
  "null"
]);
function cors(request) {
  const origin = request.headers.get("Origin") || "";
  return {
    "Access-Control-Allow-Origin": allowedOrigins.has(origin) ? origin : "https://ryhzecore.github.io",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
    "Content-Type": "application/json; charset=utf-8"
  };
}
__name(cors, "cors");
var json = /* @__PURE__ */ __name((request, body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors(request) }), "json");
var clean = /* @__PURE__ */ __name((value) => String(value || "").trim().slice(0, 120), "clean");
var index_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: cors(request) });
    const url = new URL(request.url);
    const cutoff = Date.now() - 3e4;
    await env.DB.prepare("DELETE FROM sessions WHERE updated_at < ?").bind(cutoff).run();
    if (url.pathname === "/sessions" && request.method === "GET") {
      const { results } = await env.DB.prepare("SELECT client_id, user_id, title, updated_at FROM sessions WHERE updated_at >= ? ORDER BY updated_at DESC").bind(cutoff).all();
      return json(request, { sessions: results });
    }
    if (url.pathname === "/session" && request.method === "POST") {
      let body;
      try {
        body = await request.json();
      } catch {
        return json(request, { error: "Invalid request." }, 400);
      }
      const clientId = clean(body.clientId), userId = clean(body.userId), title = clean(body.title);
      if (!clientId || !userId) return json(request, { error: "Missing session data." }, 400);
      if (body.playing === false) {
        await env.DB.prepare("DELETE FROM sessions WHERE client_id = ?").bind(clientId).run();
      } else {
        if (!title) return json(request, { error: "Missing title." }, 400);
        await env.DB.prepare("INSERT INTO sessions (client_id, user_id, title, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT(client_id) DO UPDATE SET user_id = excluded.user_id, title = excluded.title, updated_at = excluded.updated_at").bind(clientId, userId, title, Date.now()).run();
      }
      return json(request, { ok: true });
    }
    return json(request, { error: "Not found." }, 404);
  }
};
export {
  index_default as default
};
//# sourceMappingURL=index.js.map
