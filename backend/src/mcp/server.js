const { z } = require('zod');
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { StreamableHTTPServerTransport } = require('@modelcontextprotocol/sdk/server/streamableHttp.js');
const { createMcpExpressApp } = require('@modelcontextprotocol/sdk/server/express.js');
const { isInitializeRequest } = require('@modelcontextprotocol/sdk/types.js');
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

function sameApiKey(a, b) {
  return a?.id && b?.id && a.id === b.id;
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
  const sessions = new Map();

  async function resolveSessionContext(req) {
    const sessionId = req.header('mcp-session-id');
    const session = sessionId ? sessions.get(sessionId) : null;
    const apiKeyRecord = await authenticateMcpRequest(req);

    if (session && apiKeyRecord && !sameApiKey(apiKeyRecord, session.apiKeyRecord)) {
      return {
        error: {
          code: 403,
          message: 'MCP session belongs to a different API key.',
          jsonRpcCode: -32003,
        },
      };
    }

    return {
      sessionId,
      session,
      apiKeyRecord: apiKeyRecord || session?.apiKeyRecord || null,
    };
  }

  app.all(config.mcpPath, async (req, res) => {
    const context = await resolveSessionContext(req);
    if (context.error) {
      res.status(context.error.code).json({
        jsonrpc: '2.0',
        error: {
          code: context.error.jsonRpcCode,
          message: context.error.message,
        },
        id: null,
      });
      return;
    }

    if (!context.apiKeyRecord) {
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

    try {
      let transport = context.session?.transport;

      if (!transport) {
        const isInitPost = req.method === 'POST' && isInitializeRequest(req.body);
        if (!isInitPost) {
          res.status(400).json({
            jsonrpc: '2.0',
            error: {
              code: -32000,
              message: 'Bad Request: No valid MCP session. Start with an initialize POST request.',
            },
            id: null,
          });
          return;
        }

        transport = new StreamableHTTPServerTransport({
          sessionIdGenerator: undefined,
          onsessioninitialized: (sessionId) => {
            sessions.set(sessionId, {
              transport,
              apiKeyRecord: context.apiKeyRecord,
            });
          },
        });

        transport.onclose = () => {
          const sid = transport.sessionId;
          if (sid) {
            sessions.delete(sid);
          }
        };

        const server = buildMcpServer(context.apiKeyRecord);
        await server.connect(transport);
      }

      await transport.handleRequest(req, res, req.body);
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

  return app;
}

module.exports = {
  createMcpRouter,
};
