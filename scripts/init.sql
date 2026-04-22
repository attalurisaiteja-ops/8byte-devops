-- scripts/init.sql — Run once when Postgres container starts (local dev)
CREATE TABLE IF NOT EXISTS users (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(150) UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO users (name, email) VALUES
  ('Alice Dev',  'alice@example.com'),
  ('Bob Ops',    'bob@example.com'),
  ('Carol Sec',  'carol@example.com')
ON CONFLICT DO NOTHING;
