const express = require('express');
const QueueToken = require('../models/QueueToken');
const ActivityLog = require('../models/ActivityLog');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { recalculateDepartmentTokens, logActivity } = require('../services/queueService');
const socketService = require('../services/socketService');

const router = express.Router();

// Enforce both verifyToken and requireAdmin on all /api/admin routes
router.use(verifyToken, requireAdmin);

/**
 * GET /api/admin/queues/:deptId
 * Fetch full active queue for a department (called first, then waiting ordered by tokenNumber)
 */
router.get('/queues/:deptId', async (req, res, next) => {
  try {
    const { deptId } = req.params;

    const activeTokens = await QueueToken.find({
      departmentId: deptId,
      status: { $in: ['waiting', 'called'] },
    }).sort({
      // Called tokens first, then waiting tokens by tokenNumber
      status: -1, // 'waiting' vs 'called' - we will custom sort in JavaScript
      tokenNumber: 1,
    });

    // Deterministic sorting: called patients first, then lowest token number
    activeTokens.sort((a, b) => {
      if (a.status === 'called' && b.status !== 'called') return -1;
      if (b.status === 'called' && a.status !== 'called') return 1;
      return a.tokenNumber - b.tokenNumber;
    });

    res.json({
      success: true,
      queue: activeTokens,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/admin/queues/:deptId/call-next
 * Admin calls the next waiting patient in line
 */
router.patch('/queues/:deptId/call-next', async (req, res, next) => {
  try {
    const { deptId } = req.params;

    // Find the next waiting token (lowest tokenNumber)
    const nextWaiting = await QueueToken.findOne({
      departmentId: deptId,
      status: 'waiting',
    }).sort({ tokenNumber: 1, joinedAt: 1, _id: 1 });

    if (!nextWaiting) {
      return res.status(404).json({
        error: 'NotFound',
        message: 'No waiting patients in queue for this department',
      });
    }

    nextWaiting.status = 'called';
    nextWaiting.calledAt = new Date();
    await nextWaiting.save();

    // Renumber remaining waiting patients so the next person in line becomes #1
    await recalculateDepartmentTokens(deptId);

    // Audit log
    await logActivity({
      departmentId: deptId,
      tokenId: nextWaiting._id,
      tokenNumber: nextWaiting.tokenNumber,
      patientName: nextWaiting.patientName,
      actorId: req.user.uid,
      action: 'token_called',
    });

    // Real-time broadcast
    socketService.emitTokenCalled(nextWaiting.toJSON());

    res.json({
      success: true,
      message: `Called patient ${nextWaiting.patientName} (#${nextWaiting.tokenNumber})`,
      token: nextWaiting,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/admin/queues/:id/call
 * Admin calls a specific patient token
 */
router.patch('/queues/:id/call', async (req, res, next) => {
  try {
    const token = await QueueToken.findById(req.params.id);
    if (!token) {
      return res.status(404).json({ error: 'NotFound', message: 'Queue token not found' });
    }

    token.status = 'called';
    token.calledAt = new Date();
    await token.save();

    await recalculateDepartmentTokens(token.departmentId);

    await logActivity({
      departmentId: token.departmentId,
      tokenId: token._id,
      tokenNumber: token.tokenNumber,
      patientName: token.patientName,
      actorId: req.user.uid,
      action: 'token_called',
    });

    socketService.emitTokenCalled(token.toJSON());

    res.json({
      success: true,
      message: 'Patient called successfully',
      token,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/admin/queues/:id/complete
 * Mark consultation as complete ('served')
 */
router.patch('/queues/:id/complete', async (req, res, next) => {
  try {
    const token = await QueueToken.findById(req.params.id);
    if (!token) {
      return res.status(404).json({ error: 'NotFound', message: 'Queue token not found' });
    }

    token.status = 'served';
    token.servedAt = new Date();
    await token.save();

    await recalculateDepartmentTokens(token.departmentId);

    await logActivity({
      departmentId: token.departmentId,
      tokenId: token._id,
      tokenNumber: token.tokenNumber,
      patientName: token.patientName,
      actorId: req.user.uid,
      action: 'token_served',
    });

    socketService.emitTokenCompleted(token.toJSON());

    res.json({
      success: true,
      message: 'Consultation marked as served',
      token,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/admin/queues/:id/no-show
 * Mark patient absent ('no_show')
 */
router.patch('/queues/:id/no-show', async (req, res, next) => {
  try {
    const token = await QueueToken.findById(req.params.id);
    if (!token) {
      return res.status(404).json({ error: 'NotFound', message: 'Queue token not found' });
    }

    token.status = 'no_show';
    await token.save();

    await recalculateDepartmentTokens(token.departmentId);

    await logActivity({
      departmentId: token.departmentId,
      tokenId: token._id,
      tokenNumber: token.tokenNumber,
      patientName: token.patientName,
      actorId: req.user.uid,
      action: 'token_no_show',
    });

    socketService.emitTokenCompleted(token.toJSON());

    res.json({
      success: true,
      message: 'Patient marked as no-show',
      token,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/admin/activity/:deptId
 * Fetch recent activity audit log for a department (latest 50 events)
 */
router.get('/activity/:deptId', async (req, res, next) => {
  try {
    const { deptId } = req.params;

    const logs = await ActivityLog.find({ departmentId: deptId })
      .sort({ timestamp: -1 })
      .limit(50);

    res.json({
      success: true,
      activityLogs: logs,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
