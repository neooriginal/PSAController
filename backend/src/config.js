const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');

module.exports = {
  rootDir: ROOT_DIR,
  port: Number(process.env.PORT || 8787),
  host: process.env.HOST || '127.0.0.1',
  dbPath: process.env.DB_PATH || path.join(ROOT_DIR, 'data.sqlite3'),
  sessionCookieName: 'psa_controller_session',
  sessionTtlMs: 1000 * 60 * 60 * 24 * 7,
  csrfHeader: 'x-csrf-token',
  allowedHosts: (process.env.ALLOWED_HOSTS || '').split(',').map((value) => value.trim()).filter(Boolean),
  mcpPath: process.env.MCP_PATH || '/mcp',
  psaBridgeHome: process.env.PSA_BRIDGE_HOME || path.join(ROOT_DIR, 'psa-runtime'),
};
