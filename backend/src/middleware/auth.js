const { admin } = require('../config/firebase');
const User = require('../models/User');

/**
 * Middleware: Verifies Firebase ID token from Authorization header
 * Attaches decoded token and verified MongoDB User to req.user
 */
async function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or malformed Authorization header. Expected Bearer <token>',
      });
    }

    const token = authHeader.split('Bearer ')[1].trim();
    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Empty Bearer token provided',
      });
    }

    let decodedToken;

    // Test mode / Dev mock support
    if (process.env.NODE_ENV === 'test' && token.startsWith('mock-')) {
      const isMockAdmin = token.includes('admin');
      const cleanUid = token.replace('mock-admin-', '').replace('mock-', '');
      decodedToken = {
        uid: cleanUid,
        email: isMockAdmin ? 'admin@queueless.test' : 'patient@queueless.test',
        name: isMockAdmin ? 'Test Admin' : 'Test Patient',
      };
    } else {
      try {
        decodedToken = await admin.auth().verifyIdToken(token);
      } catch (authErr) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: `Invalid or expired Firebase ID token: ${authErr.message}`,
        });
      }
    }

    // Lookup verified role and profile from MongoDB
    const dbUser = await User.findOne({ firebaseUid: decodedToken.uid });

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email || dbUser?.email || '',
      name: decodedToken.name || dbUser?.name || 'User',
      role: dbUser ? dbUser.role : 'patient',
      dbUser,
    };

    next();
  } catch (error) {
    console.error('Error in verifyToken middleware:', error);
    return res.status(500).json({
      error: 'InternalServerError',
      message: 'Failed to authenticate token',
    });
  }
}

/**
 * Middleware: Requires the authenticated user to have 'admin' role in MongoDB
 */
function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Authentication required' });
  }

  if (req.user.role !== 'admin') {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Admin privileges required to access this resource',
    });
  }

  next();
}

module.exports = { verifyToken, requireAdmin };
