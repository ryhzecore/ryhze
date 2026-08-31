CREATE TABLE IF NOT EXISTS sessions (
  client_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_updated_at ON sessions(updated_at);
