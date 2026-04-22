// app/src/index.js — Minimal Express app (replace with any real project)
const express = require('express');
const { Pool }  = require('pg');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ─── DB Connection (reads secret injected by ECS) ───────────
let pool;
try {
  const secret = process.env.DB_SECRET
    ? JSON.parse(process.env.DB_SECRET)
    : {};
  pool = new Pool({
    host:     secret.host     || process.env.DB_HOST     || 'localhost',
    port:     secret.port     || process.env.DB_PORT     || 5432,
    database: secret.dbname   || process.env.DB_NAME     || 'appdb',
    user:     secret.username || process.env.DB_USER     || 'dbadmin',
    password: secret.password || process.env.DB_PASSWORD || 'changeme',
    ssl:      process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  });
} catch (err) {
  console.error('DB config error:', err.message);
}

// ─── Health check endpoint (required by ALB) ────────────────
app.get('/health', async (_req, res) => {
  try {
    if (pool) await pool.query('SELECT 1');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: 'error', detail: err.message });
  }
});

// ─── API routes ─────────────────────────────────────────────
app.get('/', (_req, res) => {
  res.json({ message: 'Welcome to 8byte DevOps demo API', env: process.env.NODE_ENV });
});

app.get('/api/users', async (_req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email FROM users LIMIT 20');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── Start ──────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
});

module.exports = app; // exported for tests
