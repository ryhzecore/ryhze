import { Component, type ReactNode } from "react";

export class ErrorBoundary extends Component<
  { children: ReactNode },
  { failed: boolean }
> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    if (this.state.failed)
      return (
        <main className="text-page">
          <img src="/brand/wordmark.png" alt="Ryhze" width="140" />
          <h1>Let’s try that again.</h1>
          <p>This page couldn’t finish opening. Reload to reconnect.</p>
          <button className="button primary" onClick={() => location.reload()}>
            Reload Ryhze
          </button>
        </main>
      );
    return this.props.children;
  }
}
