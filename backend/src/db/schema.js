const db = require('./sqlite');

async function initializeSchema() {
  await db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_login_at TEXT
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      csrf_token TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS psa_setup_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      status TEXT NOT NULL,
      brand TEXT,
      email TEXT,
      country_code TEXT,
      redirect_url TEXT,
      last_vehicle_sync_at TEXT,
      sync_message TEXT,
      updated_at TEXT NOT NULL
    )
  `);

  try {
    await db.run('ALTER TABLE psa_setup_state ADD COLUMN last_vehicle_sync_at TEXT');
  } catch (_error) {
    // Ignore duplicate-column migration attempts on existing databases.
  }

  await db.run(`
    CREATE TABLE IF NOT EXISTS psa_credentials (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      brand TEXT NOT NULL,
      email TEXT NOT NULL,
      password TEXT NOT NULL,
      country_code TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS vehicles (
      vin TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      brand TEXT NOT NULL,
      model TEXT NOT NULL,
      type TEXT NOT NULL,
      capabilities_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS vehicle_snapshots (
      vin TEXT PRIMARY KEY,
      battery_level REAL,
      battery_soh REAL,
      mileage REAL,
      charge_status TEXT,
      preconditioning_status TEXT,
      locked INTEGER,
      latitude REAL,
      longitude REAL,
      updated_at TEXT NOT NULL,
      raw_json TEXT NOT NULL,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS trips (
      id TEXT PRIMARY KEY,
      vin TEXT NOT NULL,
      started_at TEXT NOT NULL,
      ended_at TEXT NOT NULL,
      distance_km REAL NOT NULL,
      average_consumption REAL,
      average_speed REAL,
      start_battery_level REAL,
      end_battery_level REAL,
      altitude_diff REAL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS charging_sessions (
      id TEXT PRIMARY KEY,
      vin TEXT NOT NULL,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      start_level REAL NOT NULL,
      end_level REAL,
      energy_kwh REAL,
      cost REAL,
      average_power_kw REAL,
      charging_mode TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS positions (
      id TEXT PRIMARY KEY,
      vin TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      altitude REAL,
      mileage REAL,
      battery_level REAL,
      fuel_level REAL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS battery_curves (
      id TEXT PRIMARY KEY,
      charging_session_id TEXT NOT NULL,
      vin TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      battery_level REAL NOT NULL,
      power_kw REAL,
      autonomy_km REAL,
      FOREIGN KEY (charging_session_id) REFERENCES charging_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS battery_soh (
      id TEXT PRIMARY KEY,
      vin TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      soh REAL NOT NULL,
      FOREIGN KEY (vin) REFERENCES vehicles(vin) ON DELETE CASCADE
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS mcp_keys (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      key_hash TEXT NOT NULL,
      scopes_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      last_used_at TEXT,
      revoked_at TEXT
    )
  `);

  await db.run(`
    CREATE TABLE IF NOT EXISTS audit_events (
      id TEXT PRIMARY KEY,
      actor_type TEXT NOT NULL,
      actor_id TEXT,
      event_type TEXT NOT NULL,
      target TEXT,
      metadata_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  `);

  await db.run(`
    INSERT OR IGNORE INTO psa_setup_state (id, status, updated_at)
    VALUES (1, 'not_started', datetime('now'))
  `);

  const settings = [
    ['minimum_trip_length_km', '10'],
    ['export_format', 'csv'],
  ];

  for (const [key, value] of settings) {
    await db.run(
      'INSERT OR IGNORE INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
      [key, value, new Date().toISOString()],
    );
  }
}

module.exports = {
  initializeSchema,
};
