import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  useCallback,
  type MouseEvent,
} from "react";
import { AnimatePresence, MotionConfig, motion } from "motion/react";
import { Icon } from "./Icon";
import { ArtworkFlight, artworkRect, artworkSource, type ArtworkFlightState, type ArtworkRect } from "./ArtworkFlight";
import { Home } from "./Home";
import { AuthPage, AdminPage, EditorialPage } from "./Pages";
import { Player } from "./Player";
import { Preview } from "./Preview";
import { api, ease, mediaUrl, save, stored } from "./lib";
import type { Page, Title, User } from "./types";

const pages: Page[] = [
  "home",
  "games",
  "films",
  "saved",
  "about",
  "contact",
  "privacy",
  "login",
  "activate",
  "admin",
];
const currentPage = (): Page => {
  const path = location.pathname.replace(/^\/|\/$/g, "");
  return !path
    ? "home"
    : path === "menu" ? "games"
    : pages.includes(path as Page)
      ? (path as Page)
      : "not-found";
};
type Selection = { title: Title; sourceId: string };

export function App() {
  const [page, setPage] = useState<Page>(currentPage),
    [user, setUser] = useState<User | null>(null),
    [titles, setTitles] = useState<Title[]>([]),
    [ready, setReady] = useState(false),
    [error, setError] = useState(""),
    [menu, setMenu] = useState(false),
    [search, setSearch] = useState(false),
    [query, setQuery] = useState(""),
    [selected, setSelected] = useState<Selection | null>(null),
    [leaving, setLeaving] = useState(false),
    [flight, setFlight] = useState<ArtworkFlightState | null>(null),
    [saved, setSaved] = useState<string[]>([]),
    [notice, setNotice] = useState(""),
    [hovered, setHovered] = useState<string | null>(null),
    [previewPlaying, setPreviewPlaying] = useState(false);
  const [reduced, setReduced] = useState(
      () => stored<string>("ryhze-motion-v2", "smooth") === "reduced",
    ),
    [sound, setSound] = useState(() => stored("ryhze-sound-v2", false));
  const openingArtwork = useRef<ArtworkRect | null>(null),
    flightSequence = useRef(0);
  const app = useRef<HTMLDivElement>(null),
    dialog = useRef<HTMLDivElement>(null),
    focusReturn = useRef<HTMLElement | null>(null),
    searchInput = useRef<HTMLInputElement>(null),
    ambient = useRef<HTMLAudioElement>(null),
    keyboard = useRef(false),
    loadSequence = useRef(0);
  const notify = useCallback((text: string) => setNotice(text), []);
  useEffect(() => {
    if (notice) {
      const timeout = setTimeout(() => setNotice(""), 4500);
      return () => clearTimeout(timeout);
    }
  }, [notice]);
  const navigate = useCallback((target: Page) => {
    setFlight(null);
    setSelected(null);
    setLeaving(false);
    history.pushState(null, "", target === "home" ? "/" : "/" + target);
    setPage(target);
    setMenu(false);
    setSearch(false);
    setQuery("");
    window.scrollTo({ top: 0, behavior: "instant" });
  }, []);
  const load = useCallback(async () => {
    const sequence = ++loadSequence.current;
    setError("");
    try {
      const response = await fetch("/api/session", {
        cache: "no-store",
        signal: AbortSignal.timeout(15000),
      });
      if (response.status !== 200 && response.status !== 401)
        throw Error("Account connection unavailable.");
      const member = response.ok
        ? ((await response.json()).user as User)
        : null;
      if (sequence !== loadSequence.current) return;
      setUser(member);
      if (!member) setTitles((items) => items.filter((item) => !item.internal));
      const catalogue = await api<Title[]>(
        member ? "/api/catalog" : "/api/discover",
      );
      if (sequence === loadSequence.current) setTitles(catalogue);
    } catch (error) {
      if (sequence === loadSequence.current) setError((error as Error).message);
    } finally {
      if (sequence === loadSequence.current) setReady(true);
    }
  }, []);
  useEffect(() => {
    void load();
    const pop = () => {
      setFlight(null);
      setLeaving(false);
      setPage(currentPage());
      setSelected(null);
      setMenu(false);
      setSearch(false);
    };
    addEventListener("popstate", pop);
    return () => removeEventListener("popstate", pop);
  }, [load]);
  useEffect(() => {
    const items = user
      ? stored<unknown>("ryhze-saved:" + user.username, [])
      : [];
    setSaved(
      Array.isArray(items)
        ? items.filter((v): v is string => typeof v === "string")
        : [],
    );
  }, [user]);
  useEffect(() => {
    document.documentElement.dataset.motion = reduced ? "reduced" : "smooth";
    save("ryhze-motion-v2", reduced ? "reduced" : "smooth");
  }, [reduced]);
  useEffect(() => {
    document.title = selected
      ? selected.title.title + " — Ryhze"
      : page === "home" || page === "games" || page === "films"
        ? "Ryhze — Entertainment has no limits."
        : page.charAt(0).toUpperCase() + page.slice(1) + " — Ryhze";
  }, [page, selected]);
  useLayoutEffect(() => {
    if (!selected || reduced || !selected.title.image) return;
    const from = openingArtwork.current;
    const to = artworkRect(dialog.current?.querySelector("[data-artwork-target]") || null);
    if (from && to) setFlight({ id: ++flightSequence.current, sourceId: selected.sourceId, image: selected.title.image, from, to, returning: false });
  }, [selected, reduced]);
  const finishFlight = useCallback(() => {
    setFlight(null);
    if (flight?.returning) setSelected(null);
  }, [flight]);
  useEffect(() => {
    if (!flight) return;
    addEventListener("resize", finishFlight);
    return () => removeEventListener("resize", finishFlight);
  }, [flight, finishFlight]);
  const close = useCallback(() => {
    if (!selected || leaving) return;
    dialog.current?.querySelectorAll("video").forEach(video => video.pause());
    const from = artworkRect(document.querySelector("[data-artwork-flight]") || dialog.current?.querySelector("[data-artwork-target]") || null);
    const to = artworkRect(artworkSource(selected.sourceId));
    setLeaving(true);
    if (!reduced && selected.title.image && from && to) {
      setFlight({ id: ++flightSequence.current, sourceId: selected.sourceId, image: selected.title.image, from, to, returning: true });
    } else {
      setFlight(null);
      setSelected(null);
    }
  }, [selected, leaving, reduced]);
  useEffect(() => {
    const key = (event: KeyboardEvent) => {
      keyboard.current = true;
      if ((event.ctrlKey || event.metaKey) && event.key === "k") {
        event.preventDefault();
        setSearch((value) => !value);
      }
      if (event.key === "Escape") {
        close();
        setSearch(false);
        setMenu(false);
      }
      if (event.key === "Tab" && selected && dialog.current) {
        const nodes = [
          ...dialog.current.querySelectorAll<HTMLElement>(
            "button:not(:disabled),a[href],input,select",
          ),
        ].filter((n) => n.getClientRects().length);
        const first = nodes[0],
          last = nodes.at(-1);
        if (
          event.shiftKey &&
          (document.activeElement === first ||
            document.activeElement === dialog.current)
        ) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    const pointer = () => {
      keyboard.current = false;
    };
    addEventListener("keydown", key);
    addEventListener("pointerdown", pointer);
    return () => {
      removeEventListener("keydown", key);
      removeEventListener("pointerdown", pointer);
    };
  }, [close, selected]);
  useEffect(() => {
    const open = !!selected || leaving;
    if (app.current) app.current.inert = open;
    document.body.style.overflow = open ? "hidden" : "";
    if (selected) {
      const timeout = setTimeout(
        () => {
          if (keyboard.current)
            dialog.current
              ?.querySelector<HTMLButtonElement>(".back-button")
              ?.focus({ preventScroll: true });
          else dialog.current?.focus({ preventScroll: true });
        },
        reduced ? 0 : 650,
      );
      return () => clearTimeout(timeout);
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [selected, leaving, reduced]);
  useEffect(() => {
    if (search) searchInput.current?.focus();
  }, [search]);
  useEffect(() => {
    const node = ambient.current;
    if (!node) return;
    let frame = 0,
      cancelled = false;
    const target =
      sound && user && !selected && !leaving && !previewPlaying ? 0.14 : 0;
    if (node.paused) node.volume = 0;
    const initial = node.volume,
      started = performance.now();
    if (target > 0)
      node.play().catch(() => {
        if (!cancelled) {
          setSound(false);
          notify("Select sound again when you are ready to listen.");
        }
      });
    function tick(now: number) {
      const progress = Math.min(1, (now - started) / 650);
      node!.volume = initial + (target - initial) * progress;
      if (progress < 1) frame = requestAnimationFrame(tick);
      else if (target === 0) node!.pause();
    }
    frame = requestAnimationFrame(tick);
    return () => {
      cancelled = true;
      cancelAnimationFrame(frame);
    };
  }, [sound, user, selected, leaving, previewPlaying, notify]);
  function intercept(event: MouseEvent<HTMLDivElement>) {
    const link = (event.target as HTMLElement).closest<HTMLAnchorElement>(
      "a[data-nav]",
    );
    if (
      !link ||
      event.ctrlKey ||
      event.metaKey ||
      event.shiftKey ||
      event.altKey ||
      event.button !== 0
    )
      return;
    event.preventDefault();
    navigate(link.dataset.nav as Page);
  }
  function open(
    title: Title,
    sourceId: string,
    event?: MouseEvent<HTMLElement>,
  ) {
    focusReturn.current =
      event?.currentTarget || (document.activeElement as HTMLElement);
    setMenu(false);
    setSearch(false);
    const source = artworkSource(sourceId);
    const image = source?.querySelector("img");
    openingArtwork.current = image?.complete && image.naturalWidth ? artworkRect(source) : null;
    setSelected({ title, sourceId });
  }
  function toggleSaved(title: Title) {
    if (!user) {
      notify("Sign in to keep a list of your favourites.");
      close();
      navigate("login");
      return;
    }
    const next = saved.includes(title.id)
      ? saved.filter((id) => id !== title.id)
      : [...saved, title.id];
    if (save("ryhze-saved:" + user.username, next)) {
      setSaved(next);
      notify(
        next.includes(title.id) ? "Added to My List." : "Removed from My List.",
      );
    } else
      notify("Browser storage is unavailable. Your list could not be saved.");
  }
  async function login() {
    const result = await api<{ user: User }>("/api/session");
    if (!result.user) throw Error("Allow cookies for Ryhze to sign in.");
    await load();
    const next = new URLSearchParams(location.search).get("next")?.slice(1);
    navigate(pages.includes(next as Page) ? (next as Page) : "games");
  }
  async function logout() {
    try {
      await api("/api/logout", {});
      loadSequence.current++;
      setUser(null);
      setSaved([]);
      setSound(false);
      setTitles((items) => items.filter((item) => !item.internal));
      navigate("games");
      setTitles(await api<Title[]>("/api/discover"));
      notify("You’re signed out.");
    } catch (e) {
      notify((e as Error).message);
    }
  }
  const libraryPage = ["games", "films", "saved"].includes(page),
    kind = page === "films" ? "film" : "game";
  const visible = titles.filter((title) =>
      page === "saved" ? saved.includes(title.id) : title.kind === kind,
    ),
    hero = visible.find((title) => !title.internal) || visible[0];
  const results = titles
    .filter((title) =>
      [title.title, ...title.categories]
        .join(" ")
        .toLowerCase()
        .includes(query.toLowerCase()),
    )
    .slice(0, 8);
  return (
    <MotionConfig
      reducedMotion={reduced ? "always" : "never"}
      transition={{ duration: 0.55, ease }}
    >
      <div onClick={intercept} data-artwork-moving={!!flight}>
        <AnimatePresence>
          {!ready && page !== "home" && (
            <motion.div
              className="boot"
              initial={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.4 }}
            >
              <img src="/brand/wordmark.png" alt="Ryhze" />
              <span>Opening a world of possibilities.</span>
            </motion.div>
          )}
        </AnimatePresence>
        <div ref={app} className="app-shell">
          <a className="skip-link" href="#main">
            Skip to content
          </a>
          {page !== "home" && <header className="site-header">
            <a
              href="/"
              data-nav="home"
              className="brand"
              aria-label="Ryhze home"
            >
              <img className="wordmark" src="/brand/wordmark.png" alt="Ryhze" />
              <img className="symbol" src="/brand/symbol.png" alt="" />
            </a>
            <nav className="main-nav glass" aria-label="Browse Ryhze">
              {(["games", "films"] as const).map((mode) => (
                <a
                  key={mode}
                  href={"/" + mode}
                  data-nav={mode}
                  aria-current={page === mode ? "page" : undefined}
                >
                  {page === mode && (
                    <motion.span
                      layoutId="navigation-pill"
                      className="nav-pill"
                      transition={{ duration: reduced ? 0 : 0.65, ease }}
                    />
                  )}
                  <span>{mode === "games" ? "Games" : "Films"}</span>
                </a>
              ))}
            </nav>
            <div className="header-right">
              <a
                className="quiet-link studio-link"
                href="/about"
                data-nav="about"
              >
                Our story
              </a>
              <button
                className="icon-button glass"
                aria-label="Search Ryhze"
                aria-expanded={search}
                onClick={() => {
                  setSearch(!search);
                  setMenu(false);
                }}
              >
                <Icon name="search" />
              </button>
              <button
                className="icon-button glass"
                aria-label="Account and settings"
                aria-expanded={menu}
                onClick={() => {
                  setMenu(!menu);
                  setSearch(false);
                }}
              >
                <Icon name="menu" />
              </button>
              {!user && (
                <a
                  className="button glass signin-link"
                  href="/login"
                  data-nav="login"
                >
                  Sign in
                  <Icon name="arrow" size={16} />
                </a>
              )}
            </div>
            <AnimatePresence>
              {menu && (
                <>
                  <button
                    className="dismiss-menu"
                    aria-label="Close account menu"
                    onClick={() => setMenu(false)}
                  />
                  <motion.div
                    className="account-menu glass"
                    initial={{ opacity: 0, y: -6 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -6 }}
                  >
                    <span className="eyebrow">
                      {user ? "Welcome, " + user.username : "Your Ryhze"}
                    </span>
                    {user ? (
                      <>
                        <a href="/saved" data-nav="saved">
                          My List
                          <Icon name="plus" />
                        </a>
                        {user.role === "admin" && (
                          <a href="/admin" data-nav="admin">
                            Manage members
                            <Icon name="arrow" />
                          </a>
                        )}
                      </>
                    ) : (
                      <a href="/login" data-nav="login">
                        Sign in
                        <Icon name="arrow" />
                      </a>
                    )}
                    <a href="/about" data-nav="about">
                      Our story
                      <Icon name="arrow" />
                    </a>
                    <button
                      onClick={() => setReduced(!reduced)}
                      aria-pressed={!reduced}
                    >
                      {reduced ? "Reduced motion" : "Smooth motion"}
                      <Icon name="sun" />
                    </button>
                    {user && (
                      <button
                        aria-pressed={sound}
                        onClick={() => {
                          save("ryhze-sound-v2", !sound);
                          setSound(!sound);
                        }}
                      >
                        Ambient sound {sound ? "on" : "off"}
                        <Icon name={sound ? "sound" : "mute"} />
                      </button>
                    )}
                    <a href="/contact" data-nav="contact">
                      Get in touch
                      <Icon name="arrow" />
                    </a>
                    {user && (
                      <button onClick={logout}>
                        Sign out
                        <Icon name="logout" />
                      </button>
                    )}
                  </motion.div>
                </>
              )}
            </AnimatePresence>
            <AnimatePresence>
              {search && (
                <motion.section
                  className="search-panel glass"
                  aria-label="Search"
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                >
                  <div className="search-field">
                    <Icon name="search" />
                    <input
                      ref={searchInput}
                      type="search"
                      value={query}
                      onChange={(event) => setQuery(event.target.value)}
                      placeholder="Find your next world"
                      aria-label="Search titles"
                    />
                    <button
                      className="icon-button"
                      aria-label="Close search"
                      onClick={() => setSearch(false)}
                    >
                      <Icon name="close" />
                    </button>
                  </div>
                  <div className="search-results">
                    {(query ? results : titles.filter((t) => !t.internal)).map(
                      (title) => (
                        <button
                          key={title.id}
                          onClick={(event) =>
                            open(title, "search-" + title.id, event)
                          }
                        >
                          <span>
                            {title.title}
                            <small>
                              {title.kind === "game" ? "Game" : "Film"} ·{" "}
                              {title.status}
                            </small>
                          </span>
                          <Icon name="arrow" />
                        </button>
                      ),
                    )}
                    {query && !results.length && (
                      <p>No matches for “{query}”. Try another title.</p>
                    )}
                  </div>
                </motion.section>
              )}
            </AnimatePresence>
          </header>}
          <AnimatePresence mode="wait" initial={false}>
            <motion.div
              key={page}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: reduced ? 0 : 0.32, ease }}
            >
              {page === "home" ? <Home reduced={reduced} /> : libraryPage ? (
                <main id="main">
                  {page !== "saved" && (
                    <section className={"hero " + (!hero ? "studio-hero" : "")}>
                      <motion.div
                        data-artwork-source={hero ? "hero-" + hero.id : undefined}
                        style={{ visibility: flight?.sourceId === "hero-" + hero?.id ? "hidden" : undefined }}
                        className="hero-art"
                        aria-hidden="true"
                      >
                        {hero?.image && (
                          <img src={hero.image} alt="" fetchPriority="high" />
                        )}
                        <div className="hero-shade" />
                      </motion.div>
                      <div className="hero-copy">
                        <span className="eyebrow">
                          {hero?.internal
                            ? "Private library"
                            : hero?.label || "Ryhze Studio / Ryhze Television"}
                        </span>
                        <h1>
                          {hero?.title || (
                            <>
                              Stories,
                              <br />
                              made to stay.
                            </>
                          )}
                        </h1>
                        <p>
                          {hero?.description ||
                            "A home for the films and series we’re making. Different voices. One unmistakable Ryhze feeling."}
                        </p>
                        <div className="hero-actions">
                          {hero ? (
                            <>
                              <button
                                className="button primary"
                                onClick={(event) =>
                                  open(hero, "hero-" + hero.id, event)
                                }
                              >
                                {hero.kind === "game"
                                  ? "Explore the game"
                                  : "Explore the film"}
                                <Icon name="arrow" />
                              </button>
                              <button
                                className="button glass"
                                onClick={() => toggleSaved(hero)}
                              >
                                <Icon
                                  name={
                                    saved.includes(hero.id) ? "check" : "plus"
                                  }
                                />
                                {saved.includes(hero.id)
                                  ? "In My List"
                                  : "My List"}
                              </button>
                            </>
                          ) : (
                            <a
                              href="/about"
                              data-nav="about"
                              className="button primary"
                            >
                              Meet Ryhze
                              <Icon name="arrow" />
                            </a>
                          )}
                        </div>
                        <div className="hero-meta">
                          <span className="status-dot" />
                          {hero?.status || "Our next chapter is taking shape"}
                          {hero?.categories[0] && (
                            <>
                              <span className="separator">/</span>
                              {hero.categories[0]}
                            </>
                          )}
                        </div>
                      </div>
                      <div className="hero-caption">
                        <span>
                          {hero?.imageNote || "Entertainment has no limits."}
                        </span>
                        <span className="chapter">
                          01 <span>/</span> 01
                        </span>
                      </div>
                    </section>
                  )}
                  <section
                    className="catalog-section"
                    aria-labelledby="catalog-title"
                  >
                    <div className="section-heading">
                      <div>
                        <span className="eyebrow">
                          {page === "saved"
                            ? "Keep your favourites close"
                            : "Find your next world"}
                        </span>
                        <h2 id="catalog-title">
                          {page === "saved"
                            ? "My List."
                            : page === "films"
                              ? "Films & series."
                              : "Made to explore."}
                        </h2>
                      </div>
                      <span className="section-count">
                        {visible.length
                          ? `${String(visible.length).padStart(2, "0")} ${visible.length === 1 ? "title" : "titles"}`
                          : "A new chapter"}
                      </span>
                    </div>
                    {error && (
                      <div className="connection-error" role="alert">
                        <p>{error}</p>
                        <button className="button" onClick={load}>
                          Try again
                        </button>
                      </div>
                    )}
                    <div className="title-grid">
                      {visible.map((title) => (
                        <motion.article
                          key={title.id}
                          className="title-card"
                          whileHover={reduced ? undefined : { y: -3 }}
                        >
                          <button
                            className="artwork"
                            onPointerEnter={(event) => {
                              if (event.pointerType === "mouse")
                                setHovered(title.id);
                            }}
                            onPointerLeave={() => setHovered(null)}
                            onFocus={() => {
                              if (keyboard.current) setHovered(title.id);
                            }}
                            onBlur={() => setHovered(null)}
                            onClick={(event) =>
                              open(title, "card-" + title.id, event)
                            }
                            aria-label={"Explore " + title.title}
                          >
                            <motion.div
                              data-artwork-source={"card-" + title.id}
                              className="card-surface"
                              style={{ borderRadius: "var(--radius-surface)", visibility: flight?.sourceId === "card-" + title.id ? "hidden" : undefined }}
                            >
                              {title.image ? (
                                <img src={title.image} alt="" loading="lazy" />
                              ) : (
                                <div className="missing-art">
                                  <Icon
                                    name={
                                      title.kind === "game" ? "game" : "film"
                                    }
                                    size={48}
                                  />
                                </div>
                              )}
                              <span className="card-scrim" />
                              {title.preview && (
                                <Preview
                                  url={title.preview}
                                  active={
                                    hovered === title.id &&
                                    !selected &&
                                    !leaving &&
                                    !search &&
                                    !menu
                                  }
                                  sound={sound}
                                  reduced={reduced}
                                  onPlaying={setPreviewPlaying}
                                />
                              )}
                              <span className="art-label">
                                {title.internal ? "Internal test" : title.label}
                              </span>
                              <span className="card-title">{title.title}</span>
                              <span className="art-arrow">
                                <Icon name="arrow" />
                              </span>
                            </motion.div>
                          </button>
                          <div className="card-meta">
                            <span>
                              {title.status}
                              <small>
                                {title.categories.slice(0, 2).join(" · ") ||
                                  "Private preview"}
                              </small>
                            </span>
                            <button
                              className="icon-button"
                              aria-label={
                                (saved.includes(title.id)
                                  ? "Remove "
                                  : "Save ") + title.title
                              }
                              onClick={() => toggleSaved(title)}
                            >
                              <Icon
                                name={
                                  saved.includes(title.id) ? "check" : "plus"
                                }
                              />
                            </button>
                          </div>
                        </motion.article>
                      ))}
                    </div>
                    {!visible.length && !error && (
                      <div className="empty-library">
                        <Icon
                          name={page === "saved" ? "plus" : "film"}
                          size={32}
                        />
                        <h3>
                          {page === "saved"
                            ? "A place for your favourites."
                            : "Every story starts somewhere."}
                        </h3>
                        <p>
                          {page === "saved"
                            ? "Save a film or game and you’ll find it here."
                            : user
                              ? "New films and series will appear here when they’re ready."
                              : "Our films and series are in the making. Get to know the studio behind them."}
                        </p>
                        <a
                          className="button glass"
                          href={page === "saved" ? "/games" : "/about"}
                          data-nav={page === "saved" ? "games" : "about"}
                        >
                          {page === "saved" ? "Explore games" : "Our story"}
                          <Icon name="arrow" />
                        </a>
                      </div>
                    )}
                  </section>
                  <section className="studio-band">
                    <div>
                      <span className="eyebrow">
                        One identity. Many worlds.
                      </span>
                      <h2>
                        Films. Games.
                        <br />
                        <span>Ryhze.</span>
                      </h2>
                    </div>
                    <div>
                      <p>
                        We create stories and build worlds. A shared identity
                        connects them, while every production has room to be
                        itself.
                      </p>
                      <a href="/about" data-nav="about" className="text-link">
                        The story behind Ryhze
                        <Icon name="arrow" />
                      </a>
                    </div>
                  </section>
                </main>
              ) : page === "login" || page === "activate" ? (
                <AuthPage activation={page === "activate"} onLogin={login} />
              ) : page === "admin" ? (
                <AdminPage user={user} />
              ) : (
                <EditorialPage page={page} />
              )}
            </motion.div>
          </AnimatePresence>
          <footer className="site-footer">
            <a href="/" data-nav="home">
              <img src="/brand/wordmark.png" alt="Ryhze" />
            </a>
            <p>Entertainment has no limits.</p>
            <nav aria-label="Footer">
              <a href="/about" data-nav="about">
                Our story
              </a>
              <a href="/contact" data-nav="contact">
                Contact
              </a>
              <a href="/privacy" data-nav="privacy">
                Privacy & cookies
              </a>
            </nav>
            <small>
              © {new Date().getFullYear()} Ryhze. All rights reserved.
            </small>
          </footer>
        </div>
        {flight && <ArtworkFlight flight={flight} onComplete={finishFlight} />}
        <AnimatePresence
          onExitComplete={() => {
            setLeaving(false);
            focusReturn.current?.focus({ preventScroll: true });
          }}
        >
          {selected && (
            <motion.div
              className="modal-layer"
              key="title-modal"
            >
              <motion.button
                initial={{ opacity: 0 }}
                animate={{ opacity: leaving ? 0 : 1 }}
                exit={{ opacity: 0, transition: { duration: 0 } }}
                transition={{ duration: reduced ? 0 : 0.7, ease }}
                className="modal-backdrop"
                aria-label="Close title"
                onClick={close}
              />
              <motion.div
                ref={dialog}
                className="title-panel"
                role="dialog"
                aria-modal="true"
                aria-labelledby="detail-title"
                tabIndex={-1}
                initial={{ opacity: 0 }}
                animate={{ opacity: leaving ? 0 : 1 }}
                exit={{ opacity: 0, transition: { duration: 0 } }}
                style={{ borderRadius: "var(--radius-surface)" }}
                transition={{ duration: reduced ? 0 : 0.7, ease }}
              >
                <header className="detail-header">
                  <button className="button back-button" onClick={close}>
                    <Icon name="back" />
                    Back
                  </button>
                  <span>{selected.title.label}</span>
                  <button
                    className="icon-button"
                    aria-label={
                      (saved.includes(selected.title.id)
                        ? "Remove from"
                        : "Add to") + " My List"
                    }
                    onClick={() => toggleSaved(selected.title)}
                  >
                    <Icon
                      name={
                        saved.includes(selected.title.id) ? "check" : "plus"
                      }
                    />
                  </button>
                </header>
                <div className="detail-scroll">
                  <div className="detail-intro">
                    <span className="eyebrow">{selected.title.status}</span>
                    <h2 id="detail-title">{selected.title.title}</h2>
                    <div className="tags">
                      {selected.title.categories.map((tag) => (
                        <span key={tag}>{tag}</span>
                      ))}
                    </div>
                  </div>
                  {selected.title.kind === "film" ||
                  selected.title.streams.length ? (
                    <Player title={selected.title} reduced={reduced} />
                  ) : (
                    <figure className="world-art">
                      <div className="artwork-frame" data-artwork-target>
                      {selected.title.image && (
                        <img
                          src={selected.title.image}
                          alt={"The world of " + selected.title.title}
                        />
                      )}
                      </div>
                      <figcaption>
                        {selected.title.imageNote ||
                          "Internal reference artwork"}
                      </figcaption>
                    </figure>
                  )}
                  <div className="detail-copy">
                    <h3>
                      {selected.title.id === "larcenous-driftscape"
                        ? "One state. Every way out."
                        : "About this title"}
                    </h3>
                    <p>{selected.title.description}</p>
                    {selected.title.facts && (
                      <dl className="facts">
                        {selected.title.facts.map((fact) => (
                          <div key={fact.label}>
                            <dt>{fact.label}</dt>
                            <dd>{fact.value}</dd>
                          </div>
                        ))}
                      </dl>
                    )}
                    {mediaUrl(selected.title.download) && (
                      <a
                        href={mediaUrl(selected.title.download)!}
                        className="button primary"
                      >
                        Download game
                        <Icon name="arrow" />
                      </a>
                    )}
                    {selected.title.internal && (
                      <p className="fine">
                        Internal test content. This is not a Ryhze production or
                        a public release.
                      </p>
                    )}
                  </div>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
        <AnimatePresence>
          {notice && (
            <motion.div
              className="toast glass"
              role="status"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 12 }}
            >
              {notice}
            </motion.div>
          )}
        </AnimatePresence>
        {user && (
          <audio
            ref={ambient}
            src="/private-art/audio/menu-loop.mp3"
            preload="none"
            loop
          />
        )}
      </div>
    </MotionConfig>
  );
}
