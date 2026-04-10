const express = require('express');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const config = require('./config');
const { initializeSchema } = require('./db/schema');
const { attachSession, requireAuth, requireCsrf } = require('./middleware/auth');
const authRoutes = require('./routes/authRoutes');
const setupRoutes = require('./routes/setupRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const settingsRoutes = require('./routes/settingsRoutes');
const { createMcpRouter } = require('./mcp/server');
const setupService = require('./services/setupService');

const AUTO_SYNC_ALLOWED_STATES = new Set(['ready_to_sync', 'synced']);

function startAutoSyncLoop() {
  const intervalMs = config.autoSyncIntervalMs;
  if (!Number.isFinite(intervalMs) || intervalMs <= 0) {
    console.log('Automatic vehicle sync is disabled (PSA_AUTO_SYNC_INTERVAL_MS <= 0).');
    return () => {};
  }

  let running = false;
  const runTick = async () => {
    if (running) {
      return;
    }
    running = true;
    try {
      const state = await setupService.getSetupState();
      if (!AUTO_SYNC_ALLOWED_STATES.has(state.status)) {
        console.log(`Automatic vehicle sync skipped (setup status: ${state.status}).`);
        return;
      }
      const vehicles = await setupService.syncVehicles();
      const nextState = await setupService.getSetupState();
      console.log(
        `Automatic vehicle sync completed (${vehicles.length} vehicle(s), setup status: ${nextState.status}).`,
      );
    } catch (error) {
      console.error(`Automatic vehicle sync failed: ${error.message}`);
    } finally {
      running = false;
    }
  };

  const timer = setInterval(() => {
    void runTick();
  }, intervalMs);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  const warmupMs = Math.max(0, config.autoSyncWarmupMs);
  setTimeout(() => {
    void runTick();
  }, warmupMs);

  console.log(`Automatic vehicle sync enabled every ${Math.round(intervalMs / 60000)} minute(s).`);
  return () => clearInterval(timer);
}

function createApp() {
  const app = express();
  app.use(helmet({
    contentSecurityPolicy: false,
  }));
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin) {
      res.header('Access-Control-Allow-Origin', origin);
      res.header('Vary', 'Origin');
      res.header('Access-Control-Allow-Credentials', 'true');
      res.header('Access-Control-Allow-Headers', 'Content-Type, Accept, x-csrf-token, Authorization, x-api-key');
      res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    }
    if (req.method === 'OPTIONS') {
      res.status(204).end();
      return;
    }
    next();
  });
  app.use(express.json({ limit: '2mb' }));
  app.use(cookieParser());
  app.use(attachSession);

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, service: 'psa-controller-backend' });
  });

  app.use('/api', authRoutes);
  app.use('/api', requireAuth, requireCsrf, settingsRoutes);
  app.use('/api', requireAuth, requireCsrf, setupRoutes);
  app.use('/api', requireAuth, requireCsrf, vehicleRoutes);
  app.use(createMcpRouter());

  app.use((error, _req, res, _next) => {
    res.status(error.statusCode || 500).json({
      error: error.message || 'Internal server error.',
    });
  });

  return app;
}

async function startServer() {
  await initializeSchema();
  const app = createApp();
  const server = app.listen(config.port, config.host, () => {
    console.log(`PSA Controller backend listening on http://${config.host}:${config.port}`);
  });
  const stopAutoSync = startAutoSyncLoop();
  server.on('close', () => {
    stopAutoSync();
  });
  return server;
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {
  createApp,
  startServer,
};
