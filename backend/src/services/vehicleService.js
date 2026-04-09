const db = require('../db/sqlite');
const { randomId } = require('./securityService');
const { listSettings } = require('./settingsService');

function parseRowJson(value, fallback = {}) {
  try {
    return JSON.parse(value);
  } catch (_error) {
    return fallback;
  }
}

async function upsertVehicles(vehicles) {
  const now = new Date().toISOString();
  for (const vehicle of vehicles) {
    const vin = vehicle.vin || vehicle.id;
    await db.run(
      `INSERT INTO vehicles (vin, label, brand, model, type, capabilities_json, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(vin) DO UPDATE SET
         label = excluded.label,
         brand = excluded.brand,
         model = excluded.model,
         type = excluded.type,
         capabilities_json = excluded.capabilities_json,
         updated_at = excluded.updated_at`,
      [
        vin,
        vehicle.label || vin,
        vehicle.brand || 'PSA',
        vehicle.model || 'Unknown',
        vehicle.type || 'electric',
        JSON.stringify(vehicle.capabilities || []),
        now,
        now,
      ],
    );

    const snapshot = vehicle.snapshot || {};
    await db.run(
      `INSERT INTO vehicle_snapshots (
        vin, battery_level, battery_soh, mileage, charge_status, preconditioning_status,
        locked, latitude, longitude, updated_at, raw_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(vin) DO UPDATE SET
        battery_level = excluded.battery_level,
        battery_soh = excluded.battery_soh,
        mileage = excluded.mileage,
        charge_status = excluded.charge_status,
        preconditioning_status = excluded.preconditioning_status,
        locked = excluded.locked,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        updated_at = excluded.updated_at,
        raw_json = excluded.raw_json`,
      [
        vin,
        snapshot.batteryLevel ?? null,
        snapshot.batterySoh ?? null,
        snapshot.mileage ?? null,
        snapshot.chargeStatus ?? null,
        snapshot.preconditioningStatus ?? null,
        snapshot.locked == null ? null : Number(snapshot.locked),
        snapshot.latitude ?? null,
        snapshot.longitude ?? null,
        now,
        JSON.stringify(snapshot),
      ],
    );
  }
}

async function listVehicles() {
  const rows = await db.all(
    `SELECT vehicles.*, vehicle_snapshots.battery_level, vehicle_snapshots.battery_soh, vehicle_snapshots.mileage,
            vehicle_snapshots.charge_status, vehicle_snapshots.preconditioning_status, vehicle_snapshots.locked,
            vehicle_snapshots.latitude, vehicle_snapshots.longitude, vehicle_snapshots.updated_at as snapshot_updated_at
     FROM vehicles
     LEFT JOIN vehicle_snapshots ON vehicle_snapshots.vin = vehicles.vin
     ORDER BY vehicles.label ASC`,
  );

  return rows.map((row) => ({
    vin: row.vin,
    label: row.label,
    brand: row.brand,
    model: row.model,
    type: row.type,
    capabilities: parseRowJson(row.capabilities_json, []),
    snapshot: {
      batteryLevel: row.battery_level,
      batterySoh: row.battery_soh,
      mileage: row.mileage,
      chargeStatus: row.charge_status,
      preconditioningStatus: row.preconditioning_status,
      locked: row.locked == null ? null : Boolean(row.locked),
      latitude: row.latitude,
      longitude: row.longitude,
      updatedAt: row.snapshot_updated_at,
    },
  }));
}

async function listTrips(vin) {
  const rows = await db.all('SELECT * FROM trips WHERE vin = ? ORDER BY started_at DESC', [vin]);
  return rows.map((row) => ({
    id: row.id,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    distanceKm: row.distance_km,
    averageConsumption: row.average_consumption,
    averageSpeed: row.average_speed,
    startBatteryLevel: row.start_battery_level,
    endBatteryLevel: row.end_battery_level,
    altitudeDiff: row.altitude_diff,
  }));
}

async function listChargingSessions(vin) {
  const rows = await db.all('SELECT * FROM charging_sessions WHERE vin = ? ORDER BY started_at DESC', [vin]);
  return rows.map((row) => ({
    id: row.id,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    startLevel: row.start_level,
    endLevel: row.end_level,
    energyKwh: row.energy_kwh,
    cost: row.cost,
    averagePowerKw: row.average_power_kw,
    chargingMode: row.charging_mode,
  }));
}

async function listPositions(vin) {
  const rows = await db.all(
    'SELECT * FROM positions WHERE vin = ? ORDER BY recorded_at DESC LIMIT 100',
    [vin],
  );
  return rows.map((row) => ({
    id: row.id,
    recordedAt: row.recorded_at,
    latitude: row.latitude,
    longitude: row.longitude,
    altitude: row.altitude,
    mileage: row.mileage,
    batteryLevel: row.battery_level,
    fuelLevel: row.fuel_level,
  }));
}

async function listBatteryCurve(vin, chargingSessionId) {
  const rows = await db.all(
    `SELECT * FROM battery_curves WHERE vin = ? AND charging_session_id = ? ORDER BY recorded_at ASC`,
    [vin, chargingSessionId],
  );
  return rows.map((row) => ({
    id: row.id,
    recordedAt: row.recorded_at,
    batteryLevel: row.battery_level,
    powerKw: row.power_kw,
    autonomyKm: row.autonomy_km,
  }));
}

async function getStats(vin) {
  const [tripAgg, chargingAgg, lastCharging, settings] = await Promise.all([
    db.get(
      `SELECT COUNT(*) as trip_count, COALESCE(SUM(distance_km), 0) as total_distance,
              COALESCE(AVG(distance_km), 0) as average_trip_length,
              COALESCE(AVG(average_consumption), 0) as average_consumption
       FROM trips WHERE vin = ?`,
      [vin],
    ),
    db.get(
      `SELECT COALESCE(SUM(energy_kwh), 0) as total_energy_charged
       FROM charging_sessions WHERE vin = ?`,
      [vin],
    ),
    db.get(
      `SELECT start_level, end_level, energy_kwh
       FROM charging_sessions WHERE vin = ? AND end_level IS NOT NULL AND energy_kwh IS NOT NULL
       ORDER BY started_at DESC LIMIT 1`,
      [vin],
    ),
    listSettings(),
  ]);

  const lastChargeEfficiency = lastCharging && lastCharging.end_level && lastCharging.start_level
    ? (lastCharging.end_level - lastCharging.start_level) / Math.max(lastCharging.energy_kwh || 1, 1)
    : null;

  return {
    totalDistanceKm: Number(tripAgg?.total_distance || 0),
    averageConsumption: Number(tripAgg?.average_consumption || 0),
    totalEnergyChargedKwh: Number(chargingAgg?.total_energy_charged || 0),
    averageTripLengthKm: Number(tripAgg?.average_trip_length || 0),
    tripCount: Number(tripAgg?.trip_count || 0),
    lastChargeEfficiency,
  };
}

async function getVehicle(vin) {
  const vehicle = (await listVehicles()).find((item) => item.vin === vin);
  if (!vehicle) {
    return null;
  }

  const [trips, chargings, positions, stats] = await Promise.all([
    listTrips(vin),
    listChargingSessions(vin),
    listPositions(vin),
    getStats(vin),
  ]);

  return {
    ...vehicle,
    trips,
    chargings,
    positions,
    stats,
  };
}

async function seedVehicleActionSnapshot(vin, action, payload = {}) {
  const snapshot = await db.get('SELECT * FROM vehicle_snapshots WHERE vin = ?', [vin]);
  if (!snapshot) {
    return;
  }

  const next = parseRowJson(snapshot.raw_json, {});
  if (action === 'preconditioning') {
    next.preconditioningStatus = payload.enable ? 'active' : 'idle';
  }
  if (action === 'charge_now') {
    next.chargeStatus = payload.enable ? 'charging' : 'scheduled';
  }
  if (action === 'lock_doors') {
    next.locked = Boolean(payload.lock);
  }

  await db.run(
    `UPDATE vehicle_snapshots
     SET charge_status = ?, preconditioning_status = ?, locked = ?, updated_at = ?, raw_json = ?
     WHERE vin = ?`,
    [
      next.chargeStatus ?? snapshot.charge_status,
      next.preconditioningStatus ?? snapshot.preconditioning_status,
      next.locked == null ? snapshot.locked : Number(next.locked),
      new Date().toISOString(),
      JSON.stringify(next),
      vin,
    ],
  );
}

async function saveImportedVehicleData(vin, data) {
  const now = new Date().toISOString();
  if (Array.isArray(data.trips)) {
    for (const trip of data.trips) {
      await db.run(
        `INSERT OR REPLACE INTO trips (
          id, vin, started_at, ended_at, distance_km, average_consumption, average_speed,
          start_battery_level, end_battery_level, altitude_diff, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          trip.id || randomId(),
          vin,
          trip.startedAt,
          trip.endedAt,
          trip.distanceKm,
          trip.averageConsumption ?? null,
          trip.averageSpeed ?? null,
          trip.startBatteryLevel ?? null,
          trip.endBatteryLevel ?? null,
          trip.altitudeDiff ?? null,
          now,
        ],
      );
    }
  }

  if (Array.isArray(data.chargings)) {
    for (const charging of data.chargings) {
      const chargingId = charging.id || randomId();
      await db.run(
        `INSERT OR REPLACE INTO charging_sessions (
          id, vin, started_at, ended_at, start_level, end_level, energy_kwh, cost,
          average_power_kw, charging_mode, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          chargingId,
          vin,
          charging.startedAt,
          charging.endedAt ?? null,
          charging.startLevel,
          charging.endLevel ?? null,
          charging.energyKwh ?? null,
          charging.cost ?? null,
          charging.averagePowerKw ?? null,
          charging.chargingMode ?? null,
          now,
        ],
      );

      if (Array.isArray(charging.curve)) {
        for (const point of charging.curve) {
          await db.run(
            `INSERT OR REPLACE INTO battery_curves (
              id, charging_session_id, vin, recorded_at, battery_level, power_kw, autonomy_km
            ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
              point.id || randomId(),
              chargingId,
              vin,
              point.recordedAt,
              point.batteryLevel,
              point.powerKw ?? null,
              point.autonomyKm ?? null,
            ],
          );
        }
      }
    }
  }

  if (Array.isArray(data.positions)) {
    for (const position of data.positions) {
      await db.run(
        `INSERT OR REPLACE INTO positions (
          id, vin, recorded_at, latitude, longitude, altitude, mileage,
          battery_level, fuel_level, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          position.id || randomId(),
          vin,
          position.recordedAt,
          position.latitude ?? null,
          position.longitude ?? null,
          position.altitude ?? null,
          position.mileage ?? null,
          position.batteryLevel ?? null,
          position.fuelLevel ?? null,
          now,
        ],
      );
    }
  }
}

module.exports = {
  upsertVehicles,
  listVehicles,
  getVehicle,
  listTrips,
  listChargingSessions,
  listPositions,
  listBatteryCurve,
  getStats,
  seedVehicleActionSnapshot,
  saveImportedVehicleData,
};
