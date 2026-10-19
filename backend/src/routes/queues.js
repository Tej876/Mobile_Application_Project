const express = require('express');
const { z } = require('zod');
const QueueToken = require('../models/QueueToken');
const Department = require('../models/Department');
const { verifyToken } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { calculatePositionAndWait, recalculateDepartmentTokens, logActivity } = require('../services/queueService');
const socketService = require('../services/socketService');

const router = express.Router();

const joinQueueSchema = z.object({
  departmentId: z.string().min(1, 'departmentId is required'),
  patientName: z.string().min(1, 'patientName is required').max(100),
});

/**
 * GET /api/queues/active
 * Fetch patient's currently active token (status: 'waiting' or 'called') across departments
 */
router.get('/active', verifyToken, async (req, res, next) => {
  try {
    const patientId = req.user.uid;

    const activeToken = await QueueToken.findOne({
      patientId,
      status: { $in: ['waiting', 'called'] },
    }).populate('departmentId', 'name avgConsultationMins');

    if (!activeToken) {
      return res.json({
        success: true,
        hasActiveToken: false,
        token: null,
      });
    }

    const department = activeToken.departmentId;
    const { position, estWaitMins } = await calculatePositionAndWait(activeToken, department);

    res.json({
      success: true,
      hasActiveToken: true,
      token: {
        id: activeToken.id,
        _id: activeToken._id,
        departmentId: department?.id || activeToken.departmentId,
        departmentName: department?.name || 'Department',
        tokenNumber: activeToken.tokenNumber,
        patientId: activeToken.patientId,
        patientName: activeToken.patientName,
        status: activeToken.status,
        joinedAt: activeToken.joinedAt,
        calledAt: activeToken.calledAt,
        servedAt: activeToken.servedAt,
        cancelledAt: activeToken.cancelledAt,
        notifiedAt: activeToken.notifiedAt,
        position,
        estWaitMins,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/queues
 * Patient joins a department queue
 * Enforces: One active booking per patient rule & database partial unique constraint
 */
router.post('/', verifyToken, validateBody(joinQueueSchema), async (req, res, next) => {
  try {
    const { departmentId, patientName } = req.body;
    const patientId = req.user.uid;

    const department = await Department.findOne({ _id: departmentId, isActive: true });
    if (!department) {
      return res.status(404).json({ error: 'NotFound', message: 'Selected department does not exist or is inactive' });
    }

    // Check if patient already has an active booking across any department
    const existingActive = await QueueToken.findOne({
      patientId,
      status: { $in: ['waiting', 'called'] },
    }).populate('departmentId', 'name avgConsultationMins');

    if (existingActive) {
      const { position, estWaitMins } = await calculatePositionAndWait(existingActive, existingActive.departmentId);
      return res.status(409).json({
        error: 'Conflict',
        message: 'Patient already has an active queue booking. Only one active booking is permitted.',
        activeToken: {
          id: existingActive.id,
          tokenNumber: existingActive.tokenNumber,
          departmentId: existingActive.departmentId?.id || existingActive.departmentId,
          departmentName: existingActive.departmentId?.name || 'Department',
          status: existingActive.status,
          position,
          estWaitMins,
        },
      });
    }

    // Determine next sequential token number for display
    const waitingCount = await QueueToken.countDocuments({
      departmentId,
      status: 'waiting',
    });
    const nextTokenNumber = waitingCount + 1;

    // Create the token in MongoDB
    const newToken = await QueueToken.create({
      departmentId,
      patientId,
      patientName,
      tokenNumber: nextTokenNumber,
      status: 'waiting',
      joinedAt: new Date(),
    });

    // Re-run deterministic ordering renumbering to prevent race conditions
    await recalculateDepartmentTokens(departmentId);

    // Re-fetch the saved token to get its confirmed state
    const confirmedToken = await QueueToken.findById(newToken._id);
    const { position, estWaitMins } = await calculatePositionAndWait(confirmedToken, department);

    // Audit log
    await logActivity({
      departmentId,
      tokenId: confirmedToken._id,
      tokenNumber: confirmedToken.tokenNumber,
      patientName,
      actorId: patientId,
      action: 'token_created',
      details: { position, estWaitMins },
    });

    // Real-time broadcast
    socketService.emitTokenCreated(confirmedToken.toJSON());

    res.status(201).json({
      success: true,
      message: 'Joined queue successfully',
      token: {
        id: confirmedToken.id,
        _id: confirmedToken._id,
        departmentId: confirmedToken.departmentId,
        departmentName: department.name,
        tokenNumber: confirmedToken.tokenNumber,
        patientId: confirmedToken.patientId,
        patientName: confirmedToken.patientName,
        status: confirmedToken.status,
        joinedAt: confirmedToken.joinedAt,
        position,
        estWaitMins,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/queues/:id/cancel
 * Token owner cancels their waiting token
 */
router.patch('/:id/cancel', verifyToken, async (req, res, next) => {
  try {
    const tokenId = req.params.id;
    const patientId = req.user.uid;

    const token = await QueueToken.findById(tokenId);
    if (!token) {
      return res.status(404).json({ error: 'NotFound', message: 'Queue token not found' });
    }

    // Ownership verification
    if (token.patientId !== patientId && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You are not authorized to cancel this token. Only the token owner can cancel.',
      });
    }

    if (token.status !== 'waiting') {
      return res.status(400).json({
        error: 'BadRequest',
        message: `Token cannot be cancelled because its current status is '${token.status}'`,
      });
    }

    // Cancel token
    token.status = 'cancelled';
    token.cancelledAt = new Date();
    await token.save();

    // Renumber remaining waiting tokens so the next patient in line is #1
    await recalculateDepartmentTokens(token.departmentId);

    // Audit log
    await logActivity({
      departmentId: token.departmentId,
      tokenId: token._id,
      tokenNumber: token.tokenNumber,
      patientName: token.patientName,
      actorId: patientId,
      action: 'token_cancelled',
    });

    // Real-time broadcast
    socketService.emitTokenCancelled(token.toJSON());

    res.json({
      success: true,
      message: 'Token cancelled successfully',
      token,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/queues/:id/notified
 * Track notification dispatch timestamp
 */
router.patch('/:id/notified', verifyToken, async (req, res, next) => {
  try {
    const token = await QueueToken.findById(req.params.id);
    if (!token) {
      return res.status(404).json({ error: 'NotFound', message: 'Token not found' });
    }

    token.notifiedAt = new Date();
    await token.save();

    res.json({ success: true, notifiedAt: token.notifiedAt });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/queues/history
 * Fetch authenticated patient's past token history
 */
router.get('/history', verifyToken, async (req, res, next) => {
  try {
    const tokens = await QueueToken.find({ patientId: req.user.uid })
      .populate('departmentId', 'name')
      .sort({ joinedAt: -1 })
      .limit(20);

    res.json({
      success: true,
      tokens,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
