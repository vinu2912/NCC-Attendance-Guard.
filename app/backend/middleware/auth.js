const jwt = require('jsonwebtoken');

/**
 * Verifies the JWT issued by POST /api/auth/login.
 * Expects the header:  Authorization: Bearer <token>
 * On success the decoded payload ({ id, staffId, email }) is available as req.user.
 */
function verifyToken(req, res, next) {
  if (!process.env.JWT_SECRET) {
    console.error('JWT_SECRET is not set — refusing to authenticate requests');
    return res.status(500).json({ message: 'Server auth is not configured' });
  }

  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Missing or invalid Authorization header' });
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (err) {
    const message = err.name === 'TokenExpiredError' ? 'Session expired, please log in again' : 'Invalid token';
    return res.status(401).json({ message });
  }
}

/**
 * Admin routes: always need a valid token, except the seed endpoints.
 * Those stay open only when ALLOW_SEED=true, which you need on first setup
 * because no staff accounts exist yet. Set it back to false afterwards.
 */
function protectAdmin(req, res, next) {
  const isSeed = req.method === 'POST' && /^\/seed(-full)?\/?$/.test(req.path);
  if (isSeed && process.env.ALLOW_SEED === 'true') {
    return next();
  }
  return verifyToken(req, res, next);
}

module.exports = { verifyToken, protectAdmin };
