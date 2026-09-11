import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import fs from "node:fs";
import { createHash } from "node:crypto";
import worker from "../server/index.mjs";
import { passwordHash } from "../server/auth.mjs";
const digest = (value) => createHash("sha256").update(value).digest("hex");
function environment() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(
    fs.readFileSync(
      new URL("../../cloud/migrations/0001_auth.sql", import.meta.url),
      "utf8",
    ),
  );
  sqlite.exec(fs.readFileSync(new URL("../../cloud/migrations/0002_game_catalog.sql", import.meta.url), "utf8"));
  const wrap = (sql, args = []) => ({
    bind(...values) {
      return wrap(sql, values);
    },
    async first() {
      return sqlite.prepare(sql).get(...args) || null;
    },
    async all() {
      return { results: sqlite.prepare(sql).all(...args) };
    },
    async run() {
      const result = sqlite.prepare(sql).run(...args);
      return { meta: { changes: result.changes } };
    },
  });
  return {
    sqlite,
    DB: {
      prepare: wrap,
      async batch(statements) {
        sqlite.exec("BEGIN");
        try {
          const results = [];
          for (const query of statements) results.push(await query.run());
          sqlite.exec("COMMIT");
          return results;
        } catch (error) {
          sqlite.exec("ROLLBACK");
          throw error;
        }
      },
    },
    ASSETS: { fetch: () => new Response("private page") },
    MEDIA: { head: async () => null, get: async () => null },
  };
}
const request = (path, body, cookie = "", origin = "https://ryhze.com") =>
  new Request("https://ryhze.com" + path, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      "Content-Type": "application/json",
      Origin: origin,
      Cookie: cookie,
      "CF-Connecting-IP": "127.0.0.1",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

test("public discovery excludes internal reference content and private catalogue rejects forged sessions", async () => {
  const env = environment();
  const response = await worker.fetch(request("/api/discover"), env);
  assert.equal(response.status, 200);
  const titles = await response.json();
  assert.ok(titles.length);
  assert.ok(titles.every((title) => !title.internal));
  assert.equal(
    (
      await worker.fetch(
        request("/api/catalog", undefined, "ryhze_access=granted"),
        env,
      )
    ).status,
    401,
  );
  assert.equal(
    (await worker.fetch(request("/api/discover", {}), env)).status,
    405,
  );
});
test("unknown repository paths are not served and old video endpoint is retired", async () => {
  const env = environment();
  for (const path of [
    "/server/catalog.json",
    "/.env",
    "/library-data.js",
    "/package.json",
  ])
    assert.equal((await worker.fetch(request(path), env)).status, 404);
  assert.equal(
    (
      await worker.fetch(
        new Request("https://video.ryhze.com/Films/test.mp4"),
        env,
      )
    ).status,
    410,
  );
});
test("forged browser cookies do not grant access to any private page or media", async () => {
  const env = environment();
  for (const path of ["/saved", "/admin", "/private-art/Games/test.png"]) {
    const response = await worker.fetch(
      request(path, undefined, "ryhze_access=granted; ryhze-user=Andru"),
      env,
    );
    assert.equal(response.status, 303, path);
    assert.match(response.headers.get("Location"), /^\/login/);
  }
  assert.equal(
    (await worker.fetch(request("/media/Films/test.mp4"), env)).status,
    401,
  );
});
test("password sessions are secure, expire and revoke on logout", async () => {
  const env = environment(),
    encoded = await passwordHash("A long unique test password");
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("test", "Tester", encoded, "viewer", 0, 1);
  assert.equal(
    (
      await worker.fetch(
        request("/api/login", { username: "Tester", password: "incorrect" }),
        env,
      )
    ).status,
    401,
  );
  const response = await worker.fetch(
    request("/api/login", {
      username: "Tester",
      password: "A long unique test password",
      remember: true,
    }),
    env,
  );
  assert.equal(response.status, 200);
  const set = response.headers.get("Set-Cookie");
  for (const flag of [
    "__Host-ryhze_session=",
    "HttpOnly",
    "Secure",
    "SameSite=Lax",
    "Max-Age=2592000",
  ])
    assert.ok(set.includes(flag));
  const cookie = set.split(";")[0];
  assert.equal(
    (await worker.fetch(request("/saved", undefined, cookie), env)).status,
    200,
  );
  assert.equal(
    (await worker.fetch(request("/api/admin/users", undefined, cookie), env))
      .status,
    403,
  );
  await worker.fetch(request("/api/logout", {}, cookie), env);
  assert.equal(
    (await worker.fetch(request("/api/session", undefined, cookie), env))
      .status,
    401,
  );
});
test("cross-site writes, account enumeration and public registration are rejected", async () => {
  const env = environment();
  assert.equal(
    (
      await worker.fetch(
        request("/api/login", {}, "", "https://attacker.example"),
        env,
      )
    ).status,
    403,
  );
  assert.equal(
    (await worker.fetch(request("/api/register", {}), env)).status,
    404,
  );
  const response = await worker.fetch(
    request("/api/login", { username: "does-not-exist", password: "anything" }),
    env,
  );
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error, "Incorrect user ID or password.");
});
test("invitations are single-use and require a strong password", async () => {
  const env = environment(),
    value = "a".repeat(64);
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("invite", "Member", null, "viewer", 0, 1);
  env.sqlite
    .prepare("INSERT INTO invites VALUES (?,?,?,?)")
    .run(digest(value), "invite", Math.floor(Date.now() / 1000) + 1000, 0);
  assert.equal(
    (
      await worker.fetch(
        request("/api/activate", { token: value, password: "short" }),
        env,
      )
    ).status,
    400,
  );
  assert.equal(
    (
      await worker.fetch(
        request("/api/activate", {
          token: value,
          password: "New long private password",
        }),
        env,
      )
    ).status,
    200,
  );
  assert.equal(
    (
      await worker.fetch(
        request("/api/activate", {
          token: value,
          password: "Replacement password",
        }),
        env,
      )
    ).status,
    400,
  );
});
test("rate limits block repeated guesses before password hashing", async () => {
  const env = environment();
  env.sqlite
    .prepare("INSERT INTO rate_limits VALUES (?,?,?)")
    .run("user:" + digest("tester"), 10, Math.floor(Date.now() / 1000) + 1000);
  assert.equal(
    (
      await worker.fetch(
        request("/api/login", { username: "Tester", password: "guess" }),
        env,
      )
    ).status,
    429,
  );
});
test("media supports authenticated range and HEAD without public caching", async () => {
  const env = environment();
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("u", "Member", null, "viewer", 0, 1);
  const value = "c".repeat(64);
  env.sqlite
    .prepare("INSERT INTO sessions VALUES (?,?,?)")
    .run(digest(value), "u", Math.floor(Date.now() / 1000) + 1000);
  env.MEDIA = {
    head: async () => ({
      size: 100,
      httpEtag: '"test"',
      writeHttpMetadata: (h) => h.set("Content-Type", "video/mp4"),
    }),
    get: async () => ({ body: "abcdefghij" }),
  };
  const req = new Request("https://ryhze.com/media/Films/sample.mp4", {
    headers: { Cookie: "__Host-ryhze_session=" + value, Range: "bytes=10-19" },
  });
  const response = await worker.fetch(req, env);
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Range"), "bytes 10-19/100");
  assert.equal(response.headers.get("Cache-Control"), "private, no-store");
  const bad = await worker.fetch(
    new Request(req, {
      headers: {
        Cookie: "__Host-ryhze_session=" + value,
        Range: "bytes=1000-",
      },
    }),
    env,
  );
  assert.equal(bad.status, 416);
});
test("public pages use security headers and prohibit inline scripts", async () => {
  const response = await worker.fetch(request("/login"), environment());
  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("Content-Security-Policy"),
    /script-src 'self';/,
  );
  assert.equal(response.headers.get("X-Frame-Options"), "DENY");
  assert.match(response.headers.get("Cache-Control"), /no-store/);
});

test("expired and disabled sessions lose page and media access immediately", async () => {
  const env = environment(),
    value = "e".repeat(64),
    cookie = "__Host-ryhze_session=" + value;
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("u", "Member", null, "viewer", 0, 1);
  env.sqlite
    .prepare("INSERT INTO sessions VALUES (?,?,?)")
    .run(digest(value), "u", 1);
  assert.equal(
    (await worker.fetch(request("/api/session", undefined, cookie), env))
      .status,
    401,
  );
  env.sqlite
    .prepare("UPDATE sessions SET expires_at=?")
    .run(Math.floor(Date.now() / 1000) + 1000);
  assert.equal(
    (await worker.fetch(request("/saved", undefined, cookie), env)).status,
    200,
  );
  env.sqlite.prepare("UPDATE users SET disabled=1").run();
  assert.equal(
    (await worker.fetch(request("/saved", undefined, cookie), env)).status,
    303,
  );
  assert.equal(
    (
      await worker.fetch(
        request("/media/Films/sample.mp4", undefined, cookie),
        env,
      )
    ).status,
    401,
  );
});

test("expired invitations and malformed request bodies fail safely", async () => {
  const env = environment(),
    value = "f".repeat(64);
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("u", "Member", null, "viewer", 0, 1);
  env.sqlite
    .prepare("INSERT INTO invites VALUES (?,?,?,?)")
    .run(digest(value), "u", 1, 0);
  assert.equal(
    (
      await worker.fetch(
        request("/api/activate", {
          token: value,
          password: "A long unused password",
        }),
        env,
      )
    ).status,
    400,
  );
  for (const body of [null, [], "unexpected"])
    assert.equal(
      (await worker.fetch(request("/api/login", body), env)).status,
      400,
    );
});

test("administration cannot elevate invitations or disable the current administrator", async () => {
  const env = environment(),
    value = "b".repeat(64),
    cookie = "__Host-ryhze_session=" + value;
  env.sqlite
    .prepare("INSERT INTO users VALUES (?,?,?,?,?,?)")
    .run("admin", "Admin", null, "admin", 0, 1);
  env.sqlite
    .prepare("INSERT INTO sessions VALUES (?,?,?)")
    .run(digest(value), "admin", Math.floor(Date.now() / 1000) + 1000);
  assert.equal(
    (
      await worker.fetch(
        request("/api/admin/disable", { id: "admin" }, cookie),
        env,
      )
    ).status,
    400,
  );
  const invited = await worker.fetch(
    request(
      "/api/admin/invite",
      { username: "Invited", role: "admin" },
      cookie,
    ),
    env,
  );
  assert.equal(invited.status, 200);
  const member = env.sqlite
    .prepare("SELECT * FROM users WHERE username=?")
    .get("Invited");
  assert.equal(member.role, "viewer");
  await worker.fetch(
    request("/api/admin/disable", { id: member.id }, cookie),
    env,
  );
  assert.equal(
    (
      await worker.fetch(
        request("/api/admin/invite", { username: "Invited" }, cookie),
        env,
      )
    ).status,
    409,
  );
});
test("only Andru and Leo can edit games and access private RACE releases", async () => {
  const env = environment();
  const document = {id:'test-game',title:'Test game',categories:['Driving'],revision:0};
  for (const [i, name, role] of [[1,'Andru','admin'],[2,'Leo','admin'],[3,'Other','admin'],[4,'Member','viewer']]) {
    const token = String(i).repeat(64), cookie='__Host-ryhze_session='+token;
    env.sqlite.prepare('INSERT INTO users VALUES (?,?,?,?,?,?)').run(name,name,null,role,0,1);
    env.sqlite.prepare('INSERT INTO sessions VALUES (?,?,?)').run(digest(token),name,Math.floor(Date.now()/1000)+1000);
    const allowed = i <= 2;
    assert.equal((await worker.fetch(request('/api/admin/games',undefined,cookie),env)).status,allowed?200:403);
    const race = await worker.fetch(request('/api/admin/race/manifest',undefined,cookie),env);
    assert.equal(race.status,allowed?200:403);
    if(allowed) assert.equal((await race.json()).available,false);
    if(!allowed) assert.equal((await worker.fetch(request('/api/admin/games',document,cookie),env)).status,403);
  }
  const cookie='__Host-ryhze_session='+'1'.repeat(64);
  assert.equal((await worker.fetch(request('/api/admin/games',document,cookie),env)).status,200);
  assert.equal((await worker.fetch(request('/api/admin/games',document,cookie),env)).status,409);
  let titles=await (await worker.fetch(request('/api/discover'),env)).json();
  assert.equal(titles.find(t=>t.id===document.id).revision,1);
  assert.equal((await worker.fetch(request('/api/admin/games',{...document,revision:1,hidden:true},cookie),env)).status,200);
  titles=await (await worker.fetch(request('/api/discover'),env)).json();
  assert.ok(!titles.some(t=>t.id===document.id));
  assert.equal((await worker.fetch(request('/api/admin/games',{...document,id:'bad-image',image:'https://attacker.example/a'},cookie),env)).status,400);
  assert.equal((await worker.fetch(request('/api/admin/games',document,cookie,'https://attacker.example'),env)).status,403);
  assert.equal((await worker.fetch(request('/api/admin/race/manifest'),env)).status,403);
  assert.equal((await worker.fetch(request('/api/admin/race/releases/1.0.0/RACE-1.0.0-Windows-Setup.exe'),env)).status,403);
});
test('RACE rejects an unsigned release and internal overrides stay private', async () => {
  const env=environment(), token='9'.repeat(64), cookie='__Host-ryhze_session='+token;
  env.sqlite.prepare('INSERT INTO users VALUES (?,?,?,?,?,?)').run('andru','Andru',null,'admin',0,1);
  env.sqlite.prepare('INSERT INTO sessions VALUES (?,?,?)').run(digest(token),'andru',Math.floor(Date.now()/1000)+1000);
  env.MEDIA.get=async()=>({text:async()=>JSON.stringify({keyId:'ryhze-updates-2026',payload:Buffer.from('{}').toString('base64'),signature:Buffer.alloc(64).toString('base64')})});
  assert.equal((await worker.fetch(request('/api/admin/race/manifest',undefined,cookie),env)).status,503);
  env.sqlite.prepare('INSERT INTO game_catalog VALUES (?,?,?,?,?,?)').run('private-game',JSON.stringify({id:'private-game',kind:'game',title:'Private game',internal:true}),1,0,'andru',1);
  const publicTitles=await(await worker.fetch(request('/api/discover'),env)).json();
  assert.ok(!publicTitles.some(t=>t.id==='private-game'));
  const privateTitles=await(await worker.fetch(request('/api/catalog',undefined,cookie),env)).json();
  assert.ok(privateTitles.some(t=>t.id==='private-game'));
});
