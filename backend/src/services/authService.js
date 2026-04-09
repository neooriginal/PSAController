const config = require('../config');
const db = require('../db/sqlite');
const { hashValue, randomId, verifyHash } = require('./securityService');

const loginAttempts = new Map();

function nowIso() {
  return new Date().toISOString();
}

function computeExpiry() {
  return new Date(Date.now() + config.sessionTtlMs).toISOString();
}

function registerFailedAttempt(email) {
  const current = loginAttempts.get(email) || { count: 0, blockedUntil: 0 };
  const count = current.count + 1;
  const blockedUntil = count >= 5 ? Date.now() + 1000 * 60 * Math.min(count - 4, 15) : 0;
  loginAttempts.set(email, { count, blockedUntil });
}

function clearAttempts(email) {
  loginAttempts.delete(email);
}

function ensureLoginAllowed(email) {
  const current = loginAttempts.get(email);
  if (current && current.blockedUntil > Date.now()) {
    const seconds = Math.ceil((current.blockedUntil - Date.now()) / 1000);
    throw new Error(`Too many login attempts. Retry in ${seconds}s.`);
  }
}

async function getBootstrapState() {
  const row = await db.get('SELECT COUNT(*) as count FROM users');
  return {
    requiresBootstrap: !row || row.count === 0,
  };
}

async function createAdminUser(email, password) {
  const bootstrapState = await getBootstrapState();
  if (!bootstrapState.requiresBootstrap) {
    throw new Error('Bootstrap already completed.');
  }

  const id = randomId();
  const timestamp = nowIso();
  await db.run(
    `INSERT INTO users (id, email, password_hash, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)`,
    [id, email.toLowerCase(), hashValue(password), timestamp, timestamp],
  );
  return { id, email: email.toLowerCase() };
}

async function createSessionForUser(userId) {
  const sessionId = randomId();
  const csrfToken = randomId(16);
  await db.run(
    `INSERT INTO sessions (id, user_id, csrf_token, created_at, expires_at)
     VALUES (?, ?, ?, ?, ?)`,
    [sessionId, userId, csrfToken, nowIso(), computeExpiry()],
  );
  return { sessionId, csrfToken };
}

async function login(email, password) {
  const normalizedEmail = email.toLowerCase();
  ensureLoginAllowed(normalizedEmail);
  const user = await db.get('SELECT * FROM users WHERE email = ?', [normalizedEmail]);
  if (!user || !verifyHash(password, user.password_hash)) {
    registerFailedAttempt(normalizedEmail);
    throw new Error('Invalid email or password.');
  }

  clearAttempts(normalizedEmail);
  await db.run('UPDATE users SET last_login_at = ?, updated_at = ? WHERE id = ?', [nowIso(), nowIso(), user.id]);
  const session = await createSessionForUser(user.id);

  return {
    user: {
      id: user.id,
      email: user.email,
    },
    ...session,
  };
}

async function getSessionById(sessionId) {
  if (!sessionId) {
    return null;
  }

  const row = await db.get(
    `SELECT sessions.id, sessions.csrf_token, sessions.expires_at, users.id as user_id, users.email
     FROM sessions
     JOIN users ON users.id = sessions.user_id
     WHERE sessions.id = ?`,
    [sessionId],
  );

  if (!row) {
    return null;
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    await db.run('DELETE FROM sessions WHERE id = ?', [sessionId]);
    return null;
  }

  return {
    id: row.id,
    csrfToken: row.csrf_token,
    expiresAt: row.expires_at,
    user: {
      id: row.user_id,
      email: row.email,
    },
  };
}

async function deleteSession(sessionId) {
  const session = await getSessionById(sessionId);
  await db.run('DELETE FROM sessions WHERE id = ?', [sessionId]);
  if (session) {
  }
}

async function updatePassword(userId, nextPassword) {
  await db.run('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?', [
    hashValue(nextPassword),
    nowIso(),
    userId,
  ]);
}

async function createMcpKey(label, scopes) {
  const rawKey = `psa_${randomId(24)}`;
  const id = randomId();
  await db.run(
    `INSERT INTO mcp_keys (id, label, key_hash, scopes_json, created_at)
     VALUES (?, ?, ?, ?, ?)`,
    [id, label, hashValue(rawKey), JSON.stringify(scopes), nowIso()],
  );
  return {
    id,
    label,
    key: rawKey,
    scopes,
  };
}

async function listMcpKeys() {
  const rows = await db.all('SELECT * FROM mcp_keys ORDER BY created_at DESC');
  return rows.map((row) => ({
    id: row.id,
    label: row.label,
    scopes: JSON.parse(row.scopes_json),
    createdAt: row.created_at,
    lastUsedAt: row.last_used_at,
    revokedAt: row.revoked_at,
  }));
}

async function revokeMcpKey(id) {
  await db.run('UPDATE mcp_keys SET revoked_at = ? WHERE id = ?', [nowIso(), id]);
}

async function getMcpKeyByValue(rawKey) {
  const rows = await db.all('SELECT * FROM mcp_keys WHERE revoked_at IS NULL');
  const match = rows.find((row) => verifyHash(rawKey, row.key_hash));
  if (!match) {
    return null;
  }

  await db.run('UPDATE mcp_keys SET last_used_at = ? WHERE id = ?', [nowIso(), match.id]);
  return {
    id: match.id,
    label: match.label,
    scopes: JSON.parse(match.scopes_json),
  };
}

module.exports = {
  getBootstrapState,
  createAdminUser,
  login,
  getSessionById,
  deleteSession,
  updatePassword,
  createMcpKey,
  listMcpKeys,
  revokeMcpKey,
  getMcpKeyByValue,
};
