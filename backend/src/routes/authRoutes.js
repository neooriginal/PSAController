const express = require('express');
const config = require('../config');
const authService = require('../services/authService');

const router = express.Router();

function ensureCsrf(req, res) {
  if (!req.session) {
    res.status(401).json({ error: 'Authentication required.' });
    return false;
  }
  if ((req.header(config.csrfHeader) || '') != req.session.csrfToken) {
    res.status(403).json({ error: 'Missing or invalid CSRF token.' });
    return false;
  }
  return true;
}

function setSessionCookie(res, sessionId) {
  res.cookie(config.sessionCookieName, sessionId, {
    httpOnly: true,
    sameSite: 'lax',
    secure: false,
    maxAge: config.sessionTtlMs,
    path: '/',
  });
}

router.get('/bootstrap-state', async (_req, res, next) => {
  try {
    res.json(await authService.getBootstrapState());
  } catch (error) {
    next(error);
  }
});

router.post('/bootstrap/admin', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password || password.length < 8) {
      res.status(400).json({ error: 'Email and an 8+ character password are required.' });
      return;
    }
    const user = await authService.createAdminUser(email, password);
    const session = await authService.login(email, password);
    setSessionCookie(res, session.sessionId);
    res.status(201).json({
      user,
      csrfToken: session.csrfToken,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/auth/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const session = await authService.login(email, password);
    setSessionCookie(res, session.sessionId);
    res.json({
      user: session.user,
      csrfToken: session.csrfToken,
    });
  } catch (error) {
    error.statusCode = 400;
    next(error);
  }
});

router.post('/auth/logout', async (req, res, next) => {
  try {
    if (!ensureCsrf(req, res)) {
      return;
    }
    const sessionId = req.cookies?.[config.sessionCookieName];
    if (sessionId) {
      await authService.deleteSession(sessionId);
    }
    res.clearCookie(config.sessionCookieName, { path: '/' });
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

router.get('/auth/session', async (req, res) => {
  if (!req.session) {
    res.status(401).json({ authenticated: false });
    return;
  }

  res.json({
    authenticated: true,
    user: req.user,
    csrfToken: req.session.csrfToken,
  });
});

router.post('/auth/password', async (req, res, next) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'Authentication required.' });
      return;
    }
    if (!ensureCsrf(req, res)) {
      return;
    }
    const { password } = req.body || {};
    if (!password || password.length < 8) {
      res.status(400).json({ error: 'Password must be at least 8 characters.' });
      return;
    }
    await authService.updatePassword(req.user.id, password);
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

module.exports = router;
