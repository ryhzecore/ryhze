import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const publicTitles = JSON.parse(
  readFileSync(new URL("../server/catalog.json", import.meta.url)),
);
const internalTitles = JSON.parse(
  readFileSync(new URL("../server/internal-catalog.json", import.meta.url)),
);
test("release catalogue contains no QA fixture or internal public title", () => {
  assert.ok(publicTitles.every((t) => !t.internal));
  assert.ok(internalTitles.every((t) => t.internal));
  assert.ok(
    [...publicTitles, ...internalTitles].every((t) => !t.id.startsWith("qa-")),
  );
  assert.equal(
    new Set([...publicTitles, ...internalTitles].map((t) => t.id)).size,
    publicTitles.length + internalTitles.length,
  );
  for (const title of [...publicTitles, ...internalTitles]) {
    for (const stream of title.streams)
      assert.match(stream.url, /^\/media\/(Films|Games)\//);
    if (title.internal && title.image)
      assert.match(title.image, /^\/private-art\//);
  }
});

test("GTA VI and Valorant are removed from the shared catalogue", () => {
  for (const id of ["internal-valorant", "internal-grand-theft-auto-vi"]) {
    assert.ok(![...publicTitles, ...internalTitles].some(title => title.id === id));
  }
});
