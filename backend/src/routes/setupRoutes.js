const express = require('express');
const setupService = require('../services/setupService');

const router = express.Router();

router.get('/setup/state', async (_req, res, next) => {
  try {
    res.json(await setupService.getSetupState());
  } catch (error) {
    next(error);
  }
});

router.post('/setup/session', async (req, res, next) => {
  try {
    const { brand, email, password, countryCode } = req.body || {};
    if (!brand || !email || !password || !countryCode) {
      res.status(400).json({ error: 'brand, email, password, and countryCode are required.' });
      return;
    }
    res.json(await setupService.submitCredentials({
      brand,
      email,
      password,
      countryCode,
    }));
  } catch (error) {
    next(error);
  }
});

router.post('/setup/connect', async (req, res, next) => {
  try {
    res.json(await setupService.connect(req.body || {}));
  } catch (error) {
    next(error);
  }
});

router.post('/setup/connect/auto', async (req, res, next) => {
  try {
    res.json(await setupService.autoConnect());
  } catch (error) {
    next(error);
  }
});

router.post('/setup/otp/request', async (req, res, next) => {
  try {
    res.json(await setupService.requestOtp());
  } catch (error) {
    next(error);
  }
});

router.post('/setup/otp/confirm', async (req, res, next) => {
  try {
    const { smsCode, pin } = req.body || {};
    if (!smsCode || !pin) {
      res.status(400).json({ error: 'smsCode and pin are required.' });
      return;
    }
    res.json(await setupService.confirmOtp({ smsCode, pin }));
  } catch (error) {
    next(error);
  }
});

router.post('/setup/sync', async (req, res, next) => {
  try {
    res.json({ vehicles: await setupService.syncVehicles() });
  } catch (error) {
    next(error);
  }
});

router.post('/setup/import/:vin', async (req, res, next) => {
  try {
    await setupService.importVehicleData(req.params.vin, req.body || {});
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

router.post('/setup/reset', async (_req, res, next) => {
  try {
    res.json(await setupService.resetOnboarding());
  } catch (error) {
    next(error);
  }
});

module.exports = router;
