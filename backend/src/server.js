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
  return app.listen(config.port, config.host, () => {
    console.log(`PSA Controller backend listening on http://${config.host}:${config.port}`);
  });
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
