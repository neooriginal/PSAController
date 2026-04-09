const express = require('express');
const settingsService = require('../services/settingsService');
const authService = require('../services/authService');

const router = express.Router();

router.get('/settings', async (_req, res, next) => {
  try {
    res.json(await settingsService.listSettings());
  } catch (error) {
    next(error);
  }
});

router.put('/settings', async (req, res, next) => {
  try {
    res.json(await settingsService.updateSettings(req.body || {}));
  } catch (error) {
    next(error);
  }
});

router.get('/settings/mcp-keys', async (req, res, next) => {
  try {
    res.json(await authService.listMcpKeys());
  } catch (err) {
    next(err);
  }
});

router.post('/settings/mcp-keys', async (req, res, next) => {
  try {
    const key = await authService.createMcpKey(req.body.label, req.body.scopes);
    res.json(key);
  } catch (err) {
    next(err);
  }
});

router.delete('/settings/mcp-keys/:id', async (req, res, next) => {
  try {
    await authService.revokeMcpKey(req.params.id);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
