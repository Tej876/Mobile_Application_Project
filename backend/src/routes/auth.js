const express = require('express');
const { z } = require('zod');
const User = require('../models/User');
const { verifyToken } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');

const router = express.Router();

const profileSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email address'),
  role: z.enum(['patient', 'admin']).optional(),
  adminSecret: z.string().optional(),
});

/**
 * GET /api/users/me
 * Load own authenticated user profile from MongoDB
 */
router.get('/me', verifyToken, async (req, res, next) => {
  try {
    const user = await User.findOne({ firebaseUid: req.user.uid });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        message: 'No account found in MongoDB database for this user. Please register first.',
      });
    }

    res.json({
      success: true,
      user: {
        id: user.id,
        firebaseUid: user.firebaseUid,
        name: user.name,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/me
 * Create or sync own user profile on first login / registration
 * Enforces Security Requirement: Patient registration ALWAYS creates 'patient'.
 * 'admin' role requires explicit verification via ADMIN_BOOTSTRAP_SECRET.
 */
router.post('/me', verifyToken, validateBody(profileSchema), async (req, res, next) => {
  try {
    const { name, email, role, adminSecret } = req.body;
    const firebaseUid = req.user.uid;

    let existingUser = await User.findOne({ firebaseUid });

    // Determine authorized role
    let assignedRole = 'patient';
    const serverBootstrapSecret = process.env.ADMIN_BOOTSTRAP_SECRET || 'queueless_admin_bootstrap_secret_2026';

    const secretMatches = Boolean(adminSecret && adminSecret === serverBootstrapSecret);

    if (role === 'admin') {
      if (secretMatches) {
        assignedRole = 'admin';
        console.log(`🛡️ [Auth] Admin role granted to ${email} via valid bootstrap secret`);
      } else if (existingUser && existingUser.role === 'admin') {
        assignedRole = 'admin'; // retain existing verified admin
      } else {
        // Enforce security requirement: Reject unauthorized role elevation and force patient
        console.warn(`⚠️ [Auth] Security: Unauthorized attempt to register as admin by ${email}. Forcing 'patient'.`);
        assignedRole = 'patient';
      }
    } else {
      // Role is 'patient' or unspecified
      assignedRole = 'patient';
    }

    if (existingUser) {
      existingUser.name = name;
      existingUser.email = email;
      existingUser.role = assignedRole;
      await existingUser.save();

      return res.json({
        success: true,
        message: 'Profile updated',
        user: existingUser,
      });
    }

    const newUser = await User.create({
      firebaseUid,
      name,
      email,
      role: assignedRole,
      createdAt: new Date(),
    });

    res.status(201).json({
      success: true,
      message: 'Profile created in MongoDB',
      user: newUser,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/users/me
 * Delete own user profile from MongoDB
 */
router.delete('/me', verifyToken, async (req, res, next) => {
  try {
    await User.deleteOne({ firebaseUid: req.user.uid });
    res.json({ success: true, message: 'User profile deleted from MongoDB' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
