const express = require('express');
const { z } = require('zod');
const User = require('../models/User');
const { verifyToken } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');

const router = express.Router();

const profileSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
});

const recoverySchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
});

function profileResponse(user) {
  return {
    id: user.id,
    firebaseUid: user.firebaseUid,
    name: user.name,
    email: user.email,
    role: user.role,
    createdAt: user.createdAt,
  };
}

async function upsertProfile(firebaseUid, update, insert) {
  try {
    const result = await User.findOneAndUpdate(
      { firebaseUid },
      {
        ...(update ? { $set: update } : {}),
        $setOnInsert: {
          firebaseUid,
          ...insert,
        },
      },
      {
        upsert: true,
        new: true,
        runValidators: true,
        setDefaultsOnInsert: true,
        includeResultMetadata: true,
      }
    );

    return {
      user: result.value,
      created: !result.lastErrorObject.updatedExisting,
    };
  } catch (error) {
    if (error.code !== 11000) {
      throw error;
    }

    const user = await User.findOne({ firebaseUid });
    if (!user) {
      throw error;
    }
    return { user, created: false };
  }
}

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
      user: profileResponse(user),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/me/recover
 * Create a missing patient profile for the verified Firebase identity.
 */
router.post('/me/recover', verifyToken, validateBody(recoverySchema), async (req, res, next) => {
  try {
    const { uid, email, name: tokenName } = req.user;
    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'InvalidProfile',
        message: 'A Firebase email is required to create a patient profile.',
      });
    }

    const name =
      req.body.name?.trim() ||
      (tokenName && tokenName !== 'User' ? tokenName : '') ||
      email.split('@')[0];

    const { user, created } = await upsertProfile(uid, null, {
      name,
      email,
      role: 'patient',
    });

    res.status(created ? 201 : 200).json({
      success: true,
      message: created ? 'Patient profile created' : 'Profile already exists',
      user: profileResponse(user),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/me
 * Create or sync own user profile on first login / registration
 * Profile synchronization cannot assign or change user roles.
 */
router.post('/me', verifyToken, validateBody(profileSchema), async (req, res, next) => {
  try {
    const { uid, email } = req.user;
    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'InvalidProfile',
        message: 'A Firebase email is required to synchronize a profile.',
      });
    }

    const { user, created } = await upsertProfile(
      uid,
      {
        name: req.body.name,
        email,
      },
      { role: 'patient' }
    );

    res.status(created ? 201 : 200).json({
      success: true,
      message: created ? 'Profile created in MongoDB' : 'Profile updated',
      user: profileResponse(user),
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
