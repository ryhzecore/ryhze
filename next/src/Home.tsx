import { useRef, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { Icon } from "./Icon";
import releases from "../server/releases.json";
import "./home.css";

export function Home({ reduced }: { reduced: boolean }) {
  const [choosing, setChoosing] = useState(location.hash === "#install");
  const pickerTitle = useRef<HTMLHeadingElement>(null);
  function focusPlatforms() {
    pickerTitle.current?.scrollIntoView({
      behavior: reduced ? "instant" : "smooth",
      block: "start",
    });
    pickerTitle.current?.focus({ preventScroll: true });
  }
  function choosePlatform() {
    setChoosing(true);
    if (choosing) focusPlatforms();
  }
  return (
    <>
      <header className="home-header">
        <a
          href="/"
          data-nav="home"
          aria-label="Ryhze home"
          className="home-brand"
        >
          <img src="/brand/wordmark.png" alt="Ryhze" />
        </a>
        <nav aria-label="Ryhze introduction">
          <a className="home-story-link" href="#discover">
            Discover Ryhze
          </a>
          <button className="button glass" onClick={choosePlatform}>
            Install Ryhze
          </button>
          <a className="button primary" href="/games" data-nav="games">
            Open web app <Icon name="arrow" size={16} />
          </a>
        </nav>
      </header>
      <main id="main" className="brand-home">
        <section className="home-hero" aria-labelledby="home-title">
          <div className="home-hero-copy">
            <span className="eyebrow">One identity. Many worlds.</span>
            <h1 id="home-title">
              Entertainment
              <br />
              has no <span>limits.</span>
            </h1>
            <p>
              Stories to get lost in. Worlds to make your own. Ryhze brings
              films, series and games into one experience, wherever you choose
              to explore.
            </p>
            <div className="home-actions">
              <button className="button primary" onClick={choosePlatform}>
                Get Ryhze <DownloadIcon />
              </button>
              <a className="button glass" href="/games" data-nav="games">
                Continue in browser <Icon name="arrow" />
              </a>
            </div>
            <span className="home-platform-note">
              Windows & Android · Or explore on the web
            </span>
          </div>
          <div className="home-identity" aria-hidden="true">
            <div className="identity-orbit orbit-outer" />
            <div className="identity-orbit orbit-inner" />
            <div className="identity-core">
              <img src="/brand/symbol.png" alt="" />
            </div>
            <span className="identity-caption">RYHZE / NO LIMITS</span>
          </div>
          <div className="home-hero-footer">
            <span>A world beyond the ordinary.</span>
            <a href="#discover">
              Discover Ryhze <span aria-hidden="true">↓</span>
            </a>
          </div>
        </section>

        <section
          id="discover"
          className="home-discover"
          aria-labelledby="discover-title"
        >
          <div className="home-section-heading">
            <span className="eyebrow">This is Ryhze</span>
            <h2 id="discover-title">
              Different ways in.
              <br />
              <span>One unmistakable feeling.</span>
            </h2>
            <p>
              We create stories and build worlds. Across our studio, television
              and games, curiosity connects everything we make.
            </p>
          </div>
          <div className="home-worlds">
            <a className="home-world" href="/films" data-nav="films">
              <span className="home-world-number">01 / RYHZE STUDIO</span>
              <Icon name="film" size={32} />
              <h3>Stories that stay.</h3>
              <p>
                Meet the film side of Ryhze and discover the stories taking
                shape behind the screen.
              </p>
              <span className="home-world-link">
                Explore films <Icon name="arrow" />
              </span>
            </a>
            <a className="home-world" href="/films" data-nav="films">
              <span className="home-world-number">02 / RYHZE TELEVISION</span>
              <Icon name="play" size={32} />
              <h3>Another chapter.</h3>
              <p>
                A place for series and longer stories. Different voices, with
                room to keep unfolding.
              </p>
              <span className="home-world-link">
                Explore series <Icon name="arrow" />
              </span>
            </a>
            <a className="home-world" href="/games" data-nav="games">
              <span className="home-world-number">03 / RYHZE GAMES</span>
              <Icon name="game" size={32} />
              <h3>Find your own way.</h3>
              <p>
                Explore our game worlds, follow their development and discover
                what comes next.
              </p>
              <span className="home-world-link">
                Explore games <Icon name="arrow" />
              </span>
            </a>
          </div>
          <a href="/about" data-nav="about" className="text-link">
            More about Ryhze <Icon name="arrow" />
          </a>
        </section>

        <section
          className="home-install"
          id="install"
          aria-labelledby="install-title"
        >
          <div className="home-install-intro">
            <span className="eyebrow">Your screen. Your choice.</span>
            <h2 id="install-title">
              Make room
              <br />
              for <span>Ryhze.</span>
            </h2>
            <p>
              Keep Ryhze close with the Windows or Android app. Prefer to travel
              light? Open the web app and explore without installing anything.
            </p>
            <div className="home-actions">
              <button
                className="button primary"
                aria-expanded={choosing}
                aria-controls="platform-picker"
                onClick={() => setChoosing(!choosing)}
              >
                {choosing ? "Hide platforms" : "Install Ryhze"}
                <DownloadIcon />
              </button>
              <a className="text-link" href="/games" data-nav="games">
                Open web app <Icon name="arrow" />
              </a>
            </div>
            <p className="home-access-note">
              Free to download. Member features require an invitation and an
              approved Ryhze account.
            </p>
          </div>
          <div className="home-app-benefits">
            <span className="eyebrow">A familiar experience</span>
            <div>
              <Icon name="search" />
              <p>
                <strong>Find your next world</strong>Browse films and games in
                one place.
              </p>
            </div>
            <div>
              <Icon name="plus" />
              <p>
                <strong>Keep favourites close</strong>Save your list on the
                device you use.
              </p>
            </div>
            <div>
              <Icon name="check" />
              <p>
                <strong>Your Ryhze account</strong>Use your existing approved
                sign-in.
              </p>
            </div>
          </div>
          <AnimatePresence initial={false}>
            {choosing && (
              <motion.div
                id="platform-picker"
                className="platform-picker"
                onAnimationComplete={() => {
                  if (choosing) focusPlatforms();
                }}
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: reduced ? 0 : 0.5 }}
              >
                <h3 ref={pickerTitle} tabIndex={-1}>
                  Choose your platform
                </h3>
                <div className="platform-grid">
                  {releases.map((release) => (
                    <article className="platform-card" key={release.platform}>
                      <PlatformIcon platform={release.platform} />
                      <h4>
                        {release.platform === "windows" ? "Windows" : "Android"}
                      </h4>
                      <p>
                        {release.platform === "windows"
                          ? "For your desktop. A 64-bit Windows installer."
                          : "For your phone or tablet. Install directly with the APK."}
                      </p>
                      <span className="platform-meta">
                        Version {release.version} ·{" "}
                        {(release.bytes / 1000000).toFixed(1)} MB ·{" "}
                        {release.platform === "windows" ? ".exe" : ".apk"}
                      </span>
                      <a
                        className="button primary"
                        href={`/downloads/${release.platform}`}
                        download={release.filename}
                      >
                        Download{" "}
                        {release.platform === "windows"
                          ? "for Windows"
                          : "Android APK"}
                        <DownloadIcon />
                      </a>
                      <p className="platform-help">
                        {release.platform === "windows"
                          ? "The installer is not code-signed. Windows may display an unrecognized-publisher notice."
                          : "Android may ask you to allow this browser to install apps. This download is an APK, not a Play Store link."}
                      </p>
                      <details>
                        <summary>File integrity (SHA-256)</summary>
                        <code>{release.sha256}</code>
                      </details>
                    </article>
                  ))}
                </div>
                <p className="other-platforms">
                  Using iPhone, iPad or Mac?{" "}
                  <a href="/games" data-nav="games">
                    Explore Ryhze in your browser{" "}
                    <span aria-hidden="true">↗</span>
                  </a>
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        </section>
        <section className="home-closing">
          <span className="eyebrow">Every world starts with curiosity.</span>
          <h2>See where yours takes you.</h2>
          <a className="button glass" href="/games" data-nav="games">
            Step into Ryhze <Icon name="arrow" />
          </a>
        </section>
      </main>
    </>
  );
}

function DownloadIcon() {
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5" />
    </svg>
  );
}
function PlatformIcon({ platform }: { platform: string }) {
  return (
    <svg
      width="32"
      height="32"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {platform === "windows" ? (
        <path d="M3 5l8-1v7H3ZM14 3.6l7-.9V11h-7ZM3 14h8v7l-8-1Zm11 0h7v8.3l-7-.9Z" />
      ) : (
        <>
          <rect x="6" y="2" width="12" height="20" rx="3" />
          <path d="M10 5h4m-3 14h2" />
        </>
      )}
    </svg>
  );
}
