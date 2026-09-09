import test from "node:test";
import assert from "node:assert/strict";
import worker from "../server/index.mjs";
import releases from "../server/releases.json" with { type: "json" };

function environment(release = releases[0]) {
  const reads = [];
  return {
    reads,
    ASSETS: { fetch: () => new Response("Ryhze homepage") },
    MEDIA: {
      async head(key) {
        reads.push(key);
        return { size: release.bytes };
      },
      async get(key, options) {
        reads.push({ key, options });
        return { body: new Uint8Array([77, 90]) };
      },
    },
  };
}
const request = (path, options) =>
  new Request("https://ryhze.com" + path, options);

test("home is public and legacy home alias redirects to the brand entry", async () => {
  assert.equal((await worker.fetch(request("/"), environment())).status, 200);
  assert.equal(
    (await worker.fetch(request("/home"), environment())).headers.get(
      "Location",
    ),
    "/",
  );
});
test("Windows and Android downloads are public, exact artifacts with attachment metadata", async () => {
  for (const release of releases) {
    const env = environment(release);
    const response = await worker.fetch(
      request(`/downloads/${release.platform}`, { method: "HEAD" }),
      env,
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("Content-Length"), String(release.bytes));
    assert.equal(
      response.headers.get("Content-Disposition"),
      `attachment; filename="${release.filename}"`,
    );
    assert.equal(response.headers.get("X-Checksum-SHA256"), release.sha256);
    assert.deepEqual(env.reads, [
      `releases/${release.version}/${release.filename}`,
    ]);
    assert.equal(await response.text(), "");
  }
});
test("download routes cannot expose other bucket files or accept uploads", async () => {
  const env = environment();
  for (const path of [
    "/downloads/Films/private.mp4",
    "/downloads/windows/extra",
    "/downloads/%2e%2e%2f.private",
    "/downloads/android.apk",
  ]) {
    assert.equal((await worker.fetch(request(path), env)).status, 404);
  }
  assert.equal(
    (await worker.fetch(request("/downloads/windows", { method: "POST" }), env))
      .status,
    405,
  );
  assert.deepEqual(env.reads, []);
});
test("downloads resume with byte ranges and reject malformed or impossible ranges", async () => {
  const env = environment();
  const response = await worker.fetch(
    request("/downloads/windows", { headers: { Range: "bytes=0-1" } }),
    env,
  );
  assert.equal(response.status, 206);
  assert.equal(
    response.headers.get("Content-Range"),
    `bytes 0-1/${releases[0].bytes}`,
  );
  assert.equal(response.headers.get("Content-Length"), "2");
  assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [77, 90]);
  assert.deepEqual(env.reads[1].options, { range: { offset: 0, length: 2 } });
  for (const range of [
    "bytes=-0",
    "bytes=4-2",
    "bytes=",
    "bytes=0-1,4-5",
    "bytes=999999999-",
  ]) {
    assert.equal(
      (
        await worker.fetch(
          request("/downloads/windows", { headers: { Range: range } }),
          env,
        )
      ).status,
      416,
    );
  }
  const suffixEnv = environment();
  assert.equal(
    (
      await worker.fetch(
        request("/downloads/windows", { headers: { Range: "bytes=-2" } }),
        suffixEnv,
      )
    ).status,
    206,
  );
  assert.deepEqual(suffixEnv.reads[1].options, {
    range: { offset: releases[0].bytes - 2, length: 2 },
  });
});
test("missing or incomplete release objects fail instead of delivering a broken installer", async () => {
  for (const head of [null, { size: 1 }]) {
    const env = environment();
    env.MEDIA.head = async () => head;
    assert.equal(
      (await worker.fetch(request("/downloads/windows"), env)).status,
      503,
    );
  }
});
