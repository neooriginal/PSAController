const db = require('../db/sqlite');
const fs = require('fs/promises');
const path = require('path');
const config = require('../config');
const { getPsaProvider } = require('../psa');
const { automateAuthorization } = require('./oauthAutomationService');
const { upsertVehicles, saveImportedVehicleData } = require('./vehicleService');

function isReauthError(error) {
  const message = (error?.message || '').toLowerCase();
  if (message.includes("missing parameter, 'refresh_token'")) {
    return false;
  }
  return (
    message.includes('invalid_grant') ||
    message.includes('grant is invalid') ||
    message.includes('token is invalid') ||
    message.includes('refresh token') ||
    message.includes('missing session fields')
  );
}

async function markReauthRequired(reason) {
  return updateSetupState({
    status: 'reauth_required',
    syncMessage:
      reason ||
      'PSA session expired. Reconnect with a fresh authorization link in step 2.',
  });
}

async function clearRuntimeSessionFiles() {
  const runtimeHome = config.psaBridgeHome;
  const files = [
    path.join(runtimeHome, 'session.json'),
    path.join(runtimeHome, 'config.json'),
    path.join(runtimeHome, 'otp.bin'),
    path.join(runtimeHome, 'cars.json'),
  ];
  for (const file of files) {
    try {
      await fs.unlink(file);
    } catch (_error) {
      // Ignore missing files.
    }
  }
}

async function getSetupState() {
  const row = await db.get('SELECT * FROM psa_setup_state WHERE id = 1');
  return {
    status: row?.status || 'not_started',
    brand: row?.brand || null,
    email: row?.email || null,
    countryCode: row?.country_code || null,
    redirectUrl: row?.redirect_url || null,
    lastVehicleSyncAt: row?.last_vehicle_sync_at || null,
    syncMessage: row?.sync_message || null,
    updatedAt: row?.updated_at || null,
  };
}

async function updateSetupState(fields) {
  const current = await getSetupState();
  const next = {
    status: fields.status ?? current.status,
    brand: fields.brand ?? current.brand,
    email: fields.email ?? current.email,
    countryCode: fields.countryCode ?? current.countryCode,
    redirectUrl: fields.redirectUrl ?? current.redirectUrl,
    lastVehicleSyncAt: fields.lastVehicleSyncAt ?? current.lastVehicleSyncAt,
    syncMessage: fields.syncMessage ?? current.syncMessage,
    updatedAt: new Date().toISOString(),
  };

  await db.run(
    `UPDATE psa_setup_state
     SET status = ?, brand = ?, email = ?, country_code = ?, redirect_url = ?, last_vehicle_sync_at = ?, sync_message = ?, updated_at = ?
     WHERE id = 1`,
    [next.status, next.brand, next.email, next.countryCode, next.redirectUrl, next.lastVehicleSyncAt, next.syncMessage, next.updatedAt],
  );
  return next;
}

async function saveCredentials(credentials) {
  await db.run(
    `INSERT INTO psa_credentials (id, brand, email, password, country_code, updated_at)
     VALUES (1, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       brand = excluded.brand,
       email = excluded.email,
       password = excluded.password,
       country_code = excluded.country_code,
       updated_at = excluded.updated_at`,
    [
      credentials.brand,
      credentials.email,
      credentials.password,
      credentials.countryCode,
      new Date().toISOString(),
    ],
  );
}

async function getSavedCredentials() {
  const row = await db.get('SELECT * FROM psa_credentials WHERE id = 1');
  if (!row) {
    return null;
  }
  return {
    brand: row.brand,
    email: row.email,
    password: row.password,
    countryCode: row.country_code,
  };
}

async function recoverAuthorization(reason) {
  const credentials = await getSavedCredentials();
  if (!credentials) {
    return markReauthRequired(reason);
  }

  const provider = getPsaProvider();
  try {
    const response = await provider.submitCredentials(credentials);
    return updateSetupState({
      status: 'reauth_required',
      brand: credentials.brand,
      email: credentials.email,
      countryCode: credentials.countryCode,
      redirectUrl: response.redirectUrl,
      syncMessage:
        reason ||
        'PSA session expired. A fresh authentication link is ready. Open step 2 and complete reconnect.',
    });
  } catch (_error) {
    return markReauthRequired(reason);
  }
}

async function submitCredentials(credentials) {
  await saveCredentials(credentials);
  const provider = getPsaProvider();
  let nextState;

  try {
    const response = await provider.submitCredentials(credentials);
    nextState = await updateSetupState({
      status: response.status,
      brand: credentials.brand,
      email: credentials.email,
      countryCode: credentials.countryCode,
      redirectUrl: response.redirectUrl,
      syncMessage: response.message,
    });
  } catch (error) {
    nextState = await updateSetupState({
      status: 'degraded',
      brand: credentials.brand,
      email: credentials.email,
      countryCode: credentials.countryCode,
      redirectUrl: null,
      syncMessage: `PSA credential step failed: ${error.message}`,
    });
  }

  return nextState;
}

async function connect(payload) {
  const provider = getPsaProvider();
  const current = await getSetupState();
  let nextState;

  try {
    const result = await provider.connect(payload);
    nextState = await updateSetupState({
      status: result.status,
      syncMessage: result.message,
      redirectUrl: result.redirectUrl || null,
    });
  } catch (error) {
    if (isReauthError(error)) {
      nextState = await recoverAuthorization(
        'PSA session context is missing or expired. Open the refreshed auth link and paste the new code.',
      );
    } else {
      nextState = await updateSetupState({
        status: current.status,
        syncMessage: `PSA authentication failed: ${error.message}`,
        redirectUrl: null,
      });
    }
  }

  return nextState;
}

async function autoConnect() {
  const current = await getSetupState();
  const credentials = await getSavedCredentials();
  if (!credentials?.email || !credentials?.password) {
    return updateSetupState({
      status: current.status,
      syncMessage:
        'Automatic login needs saved credentials. Submit onboarding credentials first or use manual code paste.',
    });
  }
  if (!current.redirectUrl) {
    return updateSetupState({
      status: current.status,
      syncMessage:
        'Missing PSA redirect URL for automatic login. Restart step 1 to generate a fresh link, or paste code manually.',
    });
  }

  let captured;
  try {
    captured = await automateAuthorization({
      redirectUrl: current.redirectUrl,
      email: credentials.email,
      password: credentials.password,
    });
  } catch (error) {
    return updateSetupState({
      status: current.status,
      syncMessage: `Automatic browser login failed: ${error.message}`,
    });
  }

  return connect({ code: captured.code });
}

async function requestOtp() {
  const provider = getPsaProvider();
  const current = await getSetupState();
  let nextState;

  if (!['connected', 'otp_requested', 'ready_to_sync', 'synced'].includes(current.status)) {
    return updateSetupState({
      status: current.status,
      syncMessage:
        'Complete PSA authentication first. Finish step 2 and submit a fresh authorization code before requesting SMS verification.',
    });
  }

  try {
    const result = await provider.requestOtp();
    nextState = await updateSetupState({
      status: result.status,
      syncMessage: result.message,
    });
  } catch (error) {
    nextState = await updateSetupState({
      status: current.status === 'not_started' ? 'connected' : current.status,
      syncMessage: `SMS verification failed: ${error.message}`,
    });
  }

  return nextState;
}

async function confirmOtp(payload) {
  const provider = getPsaProvider();
  const current = await getSetupState();
  let nextState;

  if (!['otp_requested', 'ready_to_sync', 'synced'].includes(current.status)) {
    return updateSetupState({
      status: current.status,
      syncMessage:
        'Request the SMS verification code first, then confirm it with your vehicle PIN.',
    });
  }

  try {
    const result = await provider.confirmOtp(payload);
    nextState = await updateSetupState({
      status: result.status,
      syncMessage: result.message,
    });
  } catch (error) {
    nextState = await updateSetupState({
      status: current.status === 'not_started' ? 'otp_requested' : current.status,
      syncMessage: `OTP confirmation failed: ${error.message}`,
    });
  }

  return nextState;
}

async function syncVehicles() {
  const provider = getPsaProvider();
  const current = await getSetupState();
  let vehicles = [];
  let message = 'No vehicles were returned.';
  let lastVehicleSyncAt = current.lastVehicleSyncAt;

  if (!['ready_to_sync', 'synced'].includes(current.status)) {
    await updateSetupState({
      status: current.status,
      syncMessage:
        'Authentication handoff incomplete. Please complete step 2 and submit a fresh authorization code before syncing cars.',
    });
    return [];
  }

  try {
    vehicles = await provider.syncVehicles();
    lastVehicleSyncAt = new Date().toISOString();
    await upsertVehicles(
      vehicles.map((vehicle) => ({
        vin: vehicle.vin,
        label: vehicle.label || vehicle.vin,
        brand: vehicle.brand || 'PSA',
        model: vehicle.model || 'Unknown',
        type: vehicle.type || 'electric',
        capabilities: vehicle.capabilities || [],
        snapshot: {
          batteryLevel: vehicle.status?.energy?.[0]?.level ?? vehicle.snapshot?.batteryLevel ?? null,
          batterySoh: vehicle.snapshot?.batterySoh ?? null,
          mileage: vehicle.status?.timed_odometer?.mileage ?? vehicle.snapshot?.mileage ?? null,
          chargeStatus: vehicle.snapshot?.chargeStatus ?? null,
          preconditioningStatus: vehicle.snapshot?.preconditioningStatus ?? null,
          locked: vehicle.snapshot?.locked ?? null,
          latitude: vehicle.last_position?.geometry?.coordinates?.[1] ?? vehicle.snapshot?.latitude ?? null,
          longitude: vehicle.last_position?.geometry?.coordinates?.[0] ?? vehicle.snapshot?.longitude ?? null,
        },
      })),
    );
    for (const vehicle of vehicles) {
      await saveImportedVehicleData(vehicle.vin, {
        trips: vehicle.trips || [],
        chargings: vehicle.chargings || [],
        positions: vehicle.positions || [],
      });
    }
    message = `${vehicles.length} vehicle(s) synced.`;
  } catch (error) {
    if (isReauthError(error)) {
      await recoverAuthorization(
        'PSA session expired during vehicle sync. A fresh authorization link is ready in step 2.',
      );
      return [];
    }
    message = `Sync failed. Backend remains available in degraded mode: ${error.message}`;
    await updateSetupState({
      status: current.status,
      lastVehicleSyncAt,
      syncMessage: message,
    });
    return [];
  }

  await updateSetupState({
    status: vehicles.length > 0 ? 'synced' : current.status,
    lastVehicleSyncAt,
    syncMessage: message,
  });
  return vehicles;
}

async function importVehicleData(vin, payload) {
  await saveImportedVehicleData(vin, payload);
}

async function resetOnboarding() {
  await db.run('DELETE FROM psa_credentials');
  await db.run('DELETE FROM battery_curves');
  await db.run('DELETE FROM charging_sessions');
  await db.run('DELETE FROM positions');
  await db.run('DELETE FROM trips');
  await db.run('DELETE FROM vehicle_snapshots');
  await db.run('DELETE FROM vehicles');

  await updateSetupState({
    status: 'not_started',
    brand: null,
    email: null,
    countryCode: null,
    redirectUrl: null,
    lastVehicleSyncAt: null,
    syncMessage: 'Onboarding reset. Please connect your PSA account again.',
  });

  await clearRuntimeSessionFiles();
  return getSetupState();
}

module.exports = {
  getSetupState,
  submitCredentials,
  connect,
  autoConnect,
  requestOtp,
  confirmOtp,
  syncVehicles,
  importVehicleData,
  resetOnboarding,
  recoverAuthorization,
  markReauthRequired,
  isReauthError,
};
