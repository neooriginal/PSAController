const config = require('../config');
const authService = require('../services/authService');

function getSessionCookie(req) {
  return req.cookies?.[config.sessionCookieName] || null;
}

async function attachSession(req, _res, next) {
  try {
    const sessionId = getSessionCookie(req);
    req.session = await authService.getSessionById(sessionId);
    req.user = req.session?.user || null;
    next();
  } catch (error) {
    next(error);
  }
}

function requireAuth(req, res, next) {
  if (!req.user) {
    res.status(401).json({ error: 'Authentication required.' });
    return;
  }
  next();
}

function requireCsrf(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    next();
    return;
  }

  if (!req.session) {
    res.status(401).json({ error: 'Authentication required.' });
    return;
  }

  const token = req.header(config.csrfHeader);
  if (!token || token !== req.session.csrfToken) {
    res.status(403).json({ error: 'Missing or invalid CSRF token.' });
    return;
  }

  next();
}

module.exports = {
  attachSession,
  requireAuth,
  requireCsrf,
};
