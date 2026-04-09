const db = require('../db/sqlite');

async function listSettings() {
  const rows = await db.all('SELECT key, value, updated_at FROM app_settings ORDER BY key ASC');
  return rows.reduce((accumulator, row) => {
    accumulator[row.key] = row.value;
    return accumulator;
  }, {});
}

async function updateSettings(nextSettings) {
  const now = new Date().toISOString();
  for (const [key, value] of Object.entries(nextSettings)) {
    await db.run(
      `INSERT INTO app_settings (key, value, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
      [key, String(value), now],
    );
  }
  return listSettings();
}

module.exports = {
  listSettings,
  updateSettings,
};
