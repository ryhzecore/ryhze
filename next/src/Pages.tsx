import { useEffect, useState, type FormEvent } from "react";
import { api } from "./lib";
import { Icon } from "./Icon";
import type { Page, User } from "./types";
export function AuthPage({
  activation,
  onLogin,
}: {
  activation: boolean;
  onLogin: () => Promise<void>;
}) {
  const [token] = useState(() => location.hash.slice(1)),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [done, setDone] = useState(false);
  useEffect(() => {
    if (activation && location.hash)
      history.replaceState(null, "", location.pathname);
  }, [activation]);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setBusy(true);
    setError("");
    try {
      if (activation) {
        await api("/api/activate", { token, password: data.get("password") });
        setDone(true);
      } else {
        await api("/api/login", {
          username: data.get("username"),
          password: data.get("password"),
          remember: data.get("remember") === "on",
        });
        await onLogin();
      }
    } catch (error) {
      setError((error as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <main id="main" tabIndex={-1} className="auth-page">
      <div className="auth-intro">
        <span className="eyebrow">Your space in Ryhze</span>
        <h1>
          Make yourself
          <br />
          at home.
        </h1>
        <p>Stories to discover. Worlds to return to.</p>
        <span className="auth-orbit" aria-hidden="true" />
      </div>
      <section className="auth-panel glass">
        <span className="eyebrow">
          {activation ? "An invitation to Ryhze" : "Welcome back"}
        </span>
        <h2>
          {done
            ? "You’re all set."
            : activation
              ? "Set your password."
              : "Sign in."}
        </h2>
        {done ? (
          <>
            <p>Your password is ready. Sign in to continue.</p>
            <a className="button primary" href="/login">
              Continue to sign in
              <Icon name="arrow" />
            </a>
          </>
        ) : (
          <form onSubmit={submit}>
            {!activation && (
              <label>
                User ID
                <input
                  name="username"
                  autoComplete="username"
                  required
                  maxLength={80}
                />
              </label>
            )}
            <label>
              {activation ? "New password" : "Password"}
              <input
                type="password"
                name="password"
                autoComplete={activation ? "new-password" : "current-password"}
                required
                minLength={activation ? 12 : undefined}
                maxLength={256}
              />
            </label>
            {activation ? (
              <p className="fine">
                Use at least 12 characters. Your invitation works once.
              </p>
            ) : (
              <label className="checkbox">
                <input name="remember" type="checkbox" />
                Remember me for 30 days
              </label>
            )}
            <p className="error" role="alert">
              {error}
            </p>
            <button
              className="button primary full"
              disabled={busy || (activation && !token)}
            >
              {busy ? "One moment…" : activation ? "Set password" : "Sign in"}
              <Icon name="arrow" />
            </button>
            {activation && !token && (
              <p className="error">
                Open the full invitation link provided by your administrator.
              </p>
            )}
          </form>
        )}
        {!activation && (
          <p className="fine">
            Access is currently by invitation. For help, contact{" "}
            <a href="mailto:support@ryhze.com">support@ryhze.com</a>.
          </p>
        )}
        <p className="fine">
          We use an essential secure cookie to keep you signed in.{" "}
          <a href="/privacy">Privacy & cookies</a>
        </p>
      </section>
    </main>
  );
}
type Member = { id: string; username: string; role: string; disabled: number };
export function AdminPage({ user }: { user: User | null }) {
  const [members, setMembers] = useState<Member[]>([]),
    [error, setError] = useState(""),
    [link, setLink] = useState(""),
    [busy, setBusy] = useState(false);
  const refresh = () =>
    api<Member[]>("/api/admin/users")
      .then(setMembers)
      .catch((e) => setError(e.message));
  useEffect(() => {
    if (user?.role === "admin") void refresh();
  }, [user]);
  if (user?.role !== "admin")
    return (
      <main id="main" tabIndex={-1} className="text-page">
        <h1>Administrator access required.</h1>
        <a href="/games" className="button">
          Return to Ryhze
        </a>
      </main>
    );
  async function invite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      const result = await api<{ url: string }>("/api/admin/invite", {
        username: new FormData(event.currentTarget).get("username"),
      });
      setLink(result.url);
      await refresh();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <main id="main" tabIndex={-1} className="text-page">
      <span className="eyebrow">Your Ryhze community</span>
      <h1>Approved members.</h1>
      <p>Invite someone to Ryhze, or manage an existing member’s access.</p>
      <section className="glass form-panel">
        <h2>Invite a member</h2>
        <form onSubmit={invite}>
          <label>
            User ID
            <input
              name="username"
              required
              minLength={2}
              maxLength={80}
              pattern="[A-Za-z0-9_.@+\-]+"
            />
          </label>
          <button className="button primary" disabled={busy}>
            {busy ? "Creating…" : "Create invitation"}
            <Icon name="plus" />
          </button>
        </form>
        <p className="fine">
          An invitation lasts 24 hours. For an existing member, it lets them set
          a new password.
        </p>
        {link && (
          <div className="invitation">
            <p>Share this link privately with the intended member.</p>
            <code>{link}</code>
            <button
              className="button"
              onClick={() =>
                navigator.clipboard
                  .writeText(link)
                  .then(() => setError("Invitation copied."))
                  .catch(() =>
                    setError("Select and copy the invitation link above."),
                  )
              }
            >
              Copy invitation
            </button>
          </div>
        )}
        <p role="status">{error}</p>
      </section>
      <section className="member-list">
        {members.map((member) => (
          <div className="member" key={member.id}>
            <div>
              <strong>{member.username}</strong>
              <span>
                {member.role} · {member.disabled ? "Disabled" : "Active"}
              </span>
            </div>
            {member.username !== user?.username && !member.disabled && (
              <button
                className="button"
                onClick={async () => {
                  try {
                    await api("/api/admin/disable", { id: member.id });
                    await refresh();
                  } catch (e) {
                    setError((e as Error).message);
                  }
                }}
              >
                Disable access
              </button>
            )}
          </div>
        ))}
      </section>
    </main>
  );
}
export function EditorialPage({ page }: { page: Page }) {
  if (page === "about")
    return (
      <main id="main" tabIndex={-1} className="text-page about">
        <span className="eyebrow">Meet Ryhze</span>
        <h1>
          Stories to watch.
          <br />
          Worlds to play.
        </h1>
        <p className="lead">
          Ryhze brings films and games together through one recognizable
          identity, with room for every production to find its own voice.
        </p>
        <div className="editorial-grid">
          <section>
            <span className="eyebrow">01 / Film</span>
            <h2>Ryhze Studio</h2>
            <p>
              Stories told through moving images. A production label for Ryhze’s
              films.
            </p>
          </section>
          <section>
            <span className="eyebrow">02 / Series</span>
            <h2>Ryhze Television</h2>
            <p>
              Stories with room to unfold. A production label for Ryhze’s
              series.
            </p>
          </section>
          <section>
            <span className="eyebrow">03 / Games</span>
            <h2>Ryhze Games</h2>
            <p>
              Worlds experienced through play. A production label for Ryhze’s
              games.
            </p>
          </section>
        </div>
        <div className="brand-statement">
          <span>One identity. Many worlds.</span>
          <h2>
            Entertainment
            <br />
            has no limits.
          </h2>
          <a className="button primary" href="/games">
            Explore Ryhze
            <Icon name="arrow" />
          </a>
        </div>
      </main>
    );
  if (page === "contact")
    return (
      <main id="main" tabIndex={-1} className="text-page">
        <span className="eyebrow">Start a conversation</span>
        <h1>
          Let’s make
          <br />
          something matter.
        </h1>
        <p className="lead">
          The right conversation starts with the right people.
        </p>
        <div className="contact-list">
          {[
            ["General enquiries", "contact@ryhze.com"],
            ["Member support", "support@ryhze.com"],
            ["Games & publishing", "devs@ryhze.com"],
            ["Film & licensing", "studios@ryhze.com"],
            ["Press & brand", "press@ryhze.com"],
            ["Security", "security@ryhze.com"],
          ].map(([label, email]) => (
            <a href={"mailto:" + email} key={email}>
              <span>{label}</span>
              <strong>{email}</strong>
              <Icon name="arrow" />
            </a>
          ))}
        </div>
      </main>
    );
  if (page === "privacy")
    return (
      <main id="main" tabIndex={-1} className="text-page legal">
        <span className="eyebrow">Your privacy</span>
        <h1>Clear by design.</h1>
        <p className="lead">
          The information Ryhze uses to keep your account and experience
          working.
        </p>
        <h2>Account access</h2>
        <p>
          Membership is invitation-only. We store your user ID, a salted
          password hash, account status, and session records in Cloudflare D1.
          Administrators can issue invitations and disable accounts. Passwords
          are not stored as readable text.
        </p>
        <h2>Essential cookies</h2>
        <p>
          A Secure, HttpOnly, SameSite session cookie keeps you signed in.
          Sessions last 12 hours, or up to 30 days when you choose Remember me.
          Signing out revokes that session. These cookies are required for
          account access; blocking them prevents sign-in.
        </p>
        <h2>Your preferences</h2>
        <p>
          Saved titles, motion, and sound preferences stay in this browser.
          Saved titles are separated by user ID. Clearing site data removes
          these preferences. Ryhze does not add advertising trackers or collect
          precise location data.
        </p>
        <h2>Hosting and security</h2>
        <p>
          Cloudflare hosts the website, account data, and media. Login attempts
          are rate-limited. Expired sessions, invitation links, and rate-limit
          records are removed daily.
        </p>
        <h2>Contact</h2>
        <p>
          For access, correction, or deletion requests, email{" "}
          <a href="mailto:support@ryhze.com">support@ryhze.com</a>. Report
          security concerns to{" "}
          <a href="mailto:security@ryhze.com">security@ryhze.com</a>.
        </p>
      </main>
    );
  return (
    <main id="main" tabIndex={-1} className="text-page">
      <span className="eyebrow">404</span>
      <h1>A different route.</h1>
      <p>This page could not be found.</p>
      <a className="button primary" href="/games">
        Back to Ryhze
        <Icon name="arrow" />
      </a>
    </main>
  );
}
