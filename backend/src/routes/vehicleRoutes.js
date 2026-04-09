const express = require('express');
const { z } = require('zod');
const vehicleService = require('../services/vehicleService');
const setupService = require('../services/setupService');
const { getPsaProvider } = require('../psa');

const router = express.Router();
const provider = getPsaProvider();

router.get('/vehicles', async (_req, res, next) => {
  try {
    res.json(await vehicleService.listVehicles());
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin', async (req, res, next) => {
  try {
    const vehicle = await vehicleService.getVehicle(req.params.vin);
    if (!vehicle) {
      res.status(404).json({ error: 'Vehicle not found.' });
      return;
    }
    res.json(vehicle);
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin/trips', async (req, res, next) => {
  try {
    res.json(await vehicleService.listTrips(req.params.vin));
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin/chargings', async (req, res, next) => {
  try {
    res.json(await vehicleService.listChargingSessions(req.params.vin));
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin/chargings/:chargingSessionId/curve', async (req, res, next) => {
  try {
    res.json(await vehicleService.listBatteryCurve(req.params.vin, req.params.chargingSessionId));
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin/positions', async (req, res, next) => {
  try {
    res.json(await vehicleService.listPositions(req.params.vin));
  } catch (error) {
    next(error);
  }
});

router.get('/vehicles/:vin/stats', async (req, res, next) => {
  try {
    res.json(await vehicleService.getStats(req.params.vin));
  } catch (error) {
    next(error);
  }
});

const actionSchema = z.object({
  enable: z.boolean().optional(),
  lock: z.boolean().optional(),
  duration: z.number().optional(),
  count: z.number().optional(),
});

router.post('/vehicles/:vin/actions/:action', async (req, res, next) => {
  try {
    const payload = actionSchema.parse(req.body || {});
    const result = await provider.runAction(req.params.vin, req.params.action, payload);
    await vehicleService.seedVehicleActionSnapshot(req.params.vin, req.params.action, payload);
    res.json(result);
  } catch (error) {
    if (setupService.isReauthError(error)) {
      const state = await setupService.recoverAuthorization(
        'PSA session expired during remote action. Please redo onboarding.',
      );
      res.status(409).json({
        code: 'reauth_required',
        error: 'PSA session expired. Please complete authentication again.',
        setupState: state,
      });
      return;
    }
    next(error);
  }
});

module.exports = router;
