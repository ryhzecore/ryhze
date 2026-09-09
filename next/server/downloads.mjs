import releases from "./releases.json" with { type: "json" };

// Public distribution is limited to these exact release artifacts. Media stays private.
export async function download(request, env) {
  const platform = new URL(request.url).pathname.slice("/downloads/".length);
  const release = releases.find((item) => item.platform === platform);
  if (!release) return new Response("Download not found.", { status: 404 });
  if (!["GET", "HEAD"].includes(request.method))
    return new Response("Method not allowed.", {
      status: 405,
      headers: { Allow: "GET, HEAD" },
    });
  const key = `releases/${release.version}/${release.filename}`;
  const head = await env.MEDIA.head(key);
  if (!head || head.size !== release.bytes)
    return new Response(
      "This download is temporarily unavailable. Please try again shortly.",
      { status: 503 },
    );
  const headers = new Headers({
    "Content-Type":
      release.platform === "android"
        ? "application/vnd.android.package-archive"
        : "application/octet-stream",
    "Content-Disposition": `attachment; filename="${release.filename}"`,
    "Accept-Ranges": "bytes",
    ETag: `"${release.sha256}"`,
    "X-Checksum-SHA256": release.sha256,
    "Cache-Control": "private, no-store",
  });
  if (request.headers.get("If-None-Match") === headers.get("ETag"))
    return new Response(null, { status: 304, headers });
  let start = 0,
    end = head.size - 1,
    partial = false;
  const range = request.headers.get("Range");
  if (
    request.method === "GET" &&
    range &&
    (!request.headers.has("If-Range") ||
      request.headers.get("If-Range") === headers.get("ETag"))
  ) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    const invalid = () =>
      new Response(null, {
        status: 416,
        headers: { "Content-Range": `bytes */${head.size}` },
      });
    if (!match || (!match[1] && !match[2])) return invalid();
    if (!match[1]) {
      const suffix = Number(match[2]);
      if (!Number.isSafeInteger(suffix) || suffix <= 0) return invalid();
      start = Math.max(0, head.size - suffix);
    } else {
      start = Number(match[1]);
      if (match[2]) end = Math.min(end, Number(match[2]));
    }
    if (
      !Number.isSafeInteger(start) ||
      !Number.isSafeInteger(end) ||
      start > end ||
      start >= head.size
    )
      return invalid();
    partial = true;
    headers.set("Content-Range", `bytes ${start}-${end}/${head.size}`);
  }
  headers.set("Content-Length", String(end - start + 1));
  if (request.method === "HEAD") return new Response(null, { headers });
  const object = await env.MEDIA.get(
    key,
    partial ? { range: { offset: start, length: end - start + 1 } } : {},
  );
  if (!object)
    return new Response("Download unavailable. Please try again shortly.", {
      status: 503,
    });
  return new Response(object.body, { status: partial ? 206 : 200, headers });
}
