const { z } = require('zod');
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { StreamableHTTPServerTransport } = require('@modelcontextprotocol/sdk/server/streamableHttp.js');
const { createMcpExpressApp } = require('@modelcontextprotocol/sdk/server/express.js');
const authService = require('../services/authService');
const vehicleService = require('../services/vehicleService');
const settingsService = require('../services/settingsService');
const { getPsaProvider } = require('../psa');
const config = require('../config');

async function authenticateMcpRequest(req) {
  const authorization = req.header('authorization') || '';
  const apiKey = authorization.startsWith('Bearer ') ? authorization.slice(7) : req.header('x-api-key');
  if (!apiKey) {
    return null;
  }
  return authService.getMcpKeyByValue(apiKey);
}

function hasScope(key, scope) {
  return key?.scopes?.includes(scope);
}

function buildMcpServer(apiKeyRecord) {
  const provider = getPsaProvider();
  const server = new McpServer(
    {
      name: 'psa-controller',
      version: '0.1.0',
    },
    {
      capabilities: {
        logging: {},
        tools: {},
      },
    },
  );

  server.registerTool(
    'list_vehicles',
    {
      description: 'List available vehicles and their latest snapshots.',
      inputSchema: {},
    },
    async () => {
      const vehicles = await vehicleService.listVehicles();
      return {
        content: [{ type: 'text', text: JSON.stringify(vehicles, null, 2) }],
      };
    },
  );

  server.registerTool(
    'get_vehicle',
    {
      description: 'Get one vehicle with trips, charging history, positions, and stats.',
      inputSchema: {
        vin: z.string(),
      },
    },
    async ({ vin }) => {
      const vehicle = await vehicleService.getVehicle(vin);
      return {
        content: [{ type: 'text', text: JSON.stringify(vehicle, null, 2) }],
      };
    },
  );

  server.registerTool(
    'get_stats',
    {
      description: 'Get lightweight aggregate stats for a single vehicle.',
      inputSchema: {
        vin: z.string(),
      },
    },
    async ({ vin }) => {
      const stats = await vehicleService.getStats(vin);
      return {
        content: [{ type: 'text', text: JSON.stringify(stats, null, 2) }],
      };
    },
  );

  server.registerTool(
    'get_settings',
    {
      description: 'Read current non-secret app settings.',
      inputSchema: {},
    },
    async () => {
      const settings = await settingsService.listSettings();
      return {
        content: [{ type: 'text', text: JSON.stringify(settings, null, 2) }],
      };
    },
  );

  server.registerTool(
    'vehicle_action',
    {
      description: 'Run a remote control action when the MCP key has the vehicle:control scope.',
      inputSchema: {
        vin: z.string(),
        action: z.string(),
        payload: z.record(z.string(), z.any()).optional(),
      },
    },
    async ({ vin, action, payload }) => {
      if (!hasScope(apiKeyRecord, 'vehicle:control')) {
        throw new Error('This API key does not have vehicle:control scope.');
      }
      const result = await provider.runAction(vin, action, payload || {});
      await vehicleService.seedVehicleActionSnapshot(vin, action, payload || {});
      return {
        content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
      };
    },
  );

  return server;
}

function createMcpRouter() {
  const app = createMcpExpressApp();

  app.post(config.mcpPath, async (req, res) => {
    const apiKeyRecord = await authenticateMcpRequest(req);
    if (!apiKeyRecord) {
      res.status(401).json({
        jsonrpc: '2.0',
        error: {
          code: -32001,
          message: 'Missing or invalid API key.',
        },
        id: null,
      });
      return;
    }

    const server = buildMcpServer(apiKeyRecord);

    try {
      const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
      res.on('close', () => {
        transport.close();
        server.close();
      });
    } catch (error) {
      if (!res.headersSent) {
        res.status(500).json({
          jsonrpc: '2.0',
          error: {
            code: -32603,
            message: error.message,
          },
          id: null,
        });
      }
    }
  });

  app.get(config.mcpPath, (_req, res) => {
    res.status(405).json({
      jsonrpc: '2.0',
      error: {
        code: -32000,
        message: 'Method not allowed.',
      },
      id: null,
    });
  });

  return app;
}

module.exports = {
  createMcpRouter,
};
