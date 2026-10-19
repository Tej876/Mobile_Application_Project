const QueueToken = require('../models/QueueToken');
const Department = require('../models/Department');
const ActivityLog = require('../models/ActivityLog');
const socketService = require('./socketService');

/**
 * Calculates current queue position and estimated wait minutes for a token
 */
async function calculatePositionAndWait(token, department) {
  if (!token) return { position: 0, estWaitMins: 0 };

  if (token.status === 'called') {
    return { position: 0, estWaitMins: 0 };
  }

  if (token.status !== 'waiting') {
    return { position: 0, estWaitMins: 0 };
  }

  // Count how many waiting tokens were created before this token
  const peopleAhead = await QueueToken.countDocuments({
    departmentId: token.departmentId,
    status: 'waiting',
    $or: [
      { joinedAt: { $lt: token.joinedAt } },
      { joinedAt: token.joinedAt, _id: { $lt: token._id } },
    ],
  });

  const position = peopleAhead + 1; // 1-based position in line
  const avgMins = department?.avgConsultationMins || 15;
  // Formula from Section 7: (People Ahead * Avg Mins) + 5
  const estWaitMins = peopleAhead * avgMins + 5;

  return { position, estWaitMins };
}

/**
 * Recalculate deterministic token numbers for all waiting tokens in a department
 * Ensures the next waiting patient is #1, second is #2, etc.
 */
async function recalculateDepartmentTokens(departmentId) {
  const waitingTokens = await QueueToken.find({
    departmentId,
    status: 'waiting',
  }).sort({ joinedAt: 1, _id: 1 });

  let currentNum = 1;
  const bulkOps = [];

  for (const token of waitingTokens) {
    if (token.tokenNumber !== currentNum) {
      bulkOps.push({
        updateOne: {
          filter: { _id: token._id },
          update: { $set: { tokenNumber: currentNum } },
        },
      });
    }
    currentNum++;
  }

  if (bulkOps.length > 0) {
    await QueueToken.bulkWrite(bulkOps);
  }
}

/**
 * Logs an activity into MongoDB activity_logs
 */
async function logActivity({ departmentId, tokenId, tokenNumber, patientName, actorId, action, details }) {
  try {
    return await ActivityLog.create({
      departmentId,
      tokenId: tokenId || null,
      tokenNumber: tokenNumber || null,
      patientName: patientName || '',
      actorId,
      action,
      details: details || {},
      timestamp: new Date(),
    });
  } catch (err) {
    console.error('⚠️ [ActivityLog] Failed to log activity:', err.message);
  }
}

module.exports = {
  calculatePositionAndWait,
  recalculateDepartmentTokens,
  logActivity,
};
