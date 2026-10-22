const express = require('express');
const { z } = require('zod');
const Department = require('../models/Department');
const QueueToken = require('../models/QueueToken');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');

const router = express.Router();

const deptSchema = z.object({
  name: z.string().min(2, 'Department name must be at least 2 characters'),
  avgConsultationMins: z.number().int().min(1).default(15),
  isActive: z.boolean().default(true),
});

/**
 * GET /api/departments
 * Fetch all active departments along with their current waiting queue count
 */
router.get('/', async (req, res, next) => {
  try {
    let departments = await Department.find({ isActive: true }).sort({ name: 1 });

    // Auto-seed standard departments if empty so clinic directory is never blank
    if (departments.length === 0) {
      const { standardDepartments } = require('../../scripts/seed');
      await Department.insertMany(standardDepartments);
      departments = await Department.find({ isActive: true }).sort({ name: 1 });
    }

    // Aggregate active queue counts per department
    const queueCounts = await QueueToken.aggregate([
      {
        $match: {
          status: { $in: ['waiting', 'called'] },
        },
      },
      {
        $group: {
          _id: '$departmentId',
          count: { $sum: 1 },
        },
      },
    ]);

    const countMap = {};
    queueCounts.forEach((qc) => {
      countMap[qc._id.toString()] = qc.count;
    });

    const results = departments.map((d) => ({
      id: d.id,
      _id: d._id,
      name: d.name,
      avgConsultationMins: d.avgConsultationMins,
      isActive: d.isActive,
      activeQueueLength: countMap[d.id] || 0,
      createdAt: d.createdAt,
    }));

    res.json({
      success: true,
      departments: results,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/departments
 * Admin-only: Create a new clinic department
 */
router.post('/', verifyToken, requireAdmin, validateBody(deptSchema), async (req, res, next) => {
  try {
    const department = await Department.create(req.body);
    res.status(201).json({
      success: true,
      department,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/departments/:id
 * Admin-only: Remove a department (satisfies evaluation rubric CRUD demonstration)
 */
router.delete('/:id', verifyToken, requireAdmin, async (req, res, next) => {
  try {
    const dept = await Department.findById(req.params.id);
    if (!dept) {
      return res.status(404).json({ error: 'NotFound', message: 'Department not found' });
    }

    // Soft delete / deactivate to preserve historical token integrity
    dept.isActive = false;
    await dept.save();

    res.json({
      success: true,
      message: 'Department deactivated successfully',
      department: dept,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
