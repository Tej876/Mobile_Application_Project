const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const authRoutes = require('./routes/auth');
const departmentRoutes = require('./routes/departments');
const queueRoutes = require('./routes/queues');
const adminRoutes = require('./routes/admin');
const errorHandler = require('./middleware/errorHandler');

const User = require('./models/User');
const Department = require('./models/Department');
const QueueToken = require('./models/QueueToken');
const ActivityLog = require('./models/ActivityLog');

const app = express();

// Standard middlewares
app.use(cors());
app.use(express.json());

// Welcome / API Status Root Endpoint
app.get('/', (req, res) => {
  const dbState = mongoose.connection.readyState;
  const dbStatusMap = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };

  res.json({
    name: 'QueueLess Backend API',
    version: '2.0.0',
    status: 'online',
    database: dbStatusMap[dbState] || 'unknown',
    endpoints: {
      health: '/api/health',
      departments: '/api/departments',
      users: '/api/users/me',
      queues: '/api/queues',
      admin: '/api/admin',
    },
    message: 'QueueLess Node.js + Express + MongoDB Atlas + Socket.IO API is operational.',
  });
});

// Public Health Check Endpoint
app.get('/api/health', (req, res) => {
  const dbState = mongoose.connection.readyState;
  const dbStatusMap = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };

  res.json({
    status: 'ok',
    service: 'QueueLess Backend API',
    version: '2.0.0',
    database: dbStatusMap[dbState] || 'unknown',
    timestamp: new Date().toISOString(),
  });
});

// Live Database Inspector (Visual Web Dashboard & JSON)
app.get('/api/db-view', async (req, res, next) => {
  try {
    const [users, departments, tokens, activityLogs] = await Promise.all([
      User.find({}).sort({ createdAt: -1 }).limit(50),
      Department.find({}).sort({ name: 1 }),
      QueueToken.find({}).populate('departmentId', 'name').sort({ joinedAt: -1 }).limit(50),
      ActivityLog.find({}).populate('departmentId', 'name').sort({ timestamp: -1 }).limit(50),
    ]);

    const stats = {
      totalUsers: users.length,
      totalDepartments: departments.length,
      activeTokens: tokens.filter((t) => t.status === 'waiting' || t.status === 'called').length,
      totalTokens: tokens.length,
      totalActivityLogs: activityLogs.length,
    };

    if (req.query.format === 'json' || req.headers.accept?.includes('application/json')) {
      return res.json({ success: true, stats, users, departments, tokens, activityLogs });
    }

    // HTML Visual Viewer
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>QueueLess — Live MongoDB Inspector</title>
  <meta http-equiv="refresh" content="3">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: #181516; color: #F6E7E2; padding: 24px; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #33252B; padding-bottom: 16px; margin-bottom: 24px; }
    h1 { color: #E6CFC8; font-size: 24px; }
    .live-badge { background: #2E6F54; color: #fff; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: bold; animation: pulse 2s infinite; }
    @keyframes pulse { 0% { opacity: 0.7; } 50% { opacity: 1; } 100% { opacity: 0.7; } }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 30px; }
    .card { background: #251D21; border: 1px solid #43333B; border-radius: 12px; padding: 18px; }
    .card-title { font-size: 12px; color: #BF9B8E; text-transform: uppercase; letter-spacing: 0.5px; }
    .card-value { font-size: 28px; font-weight: bold; color: #FFFBFA; margin-top: 6px; }
    .section-title { font-size: 18px; color: #E6CFC8; margin: 28px 0 12px 0; border-left: 4px solid #593E47; padding-left: 10px; }
    table { width: 100%; border-collapse: collapse; background: #20181C; border-radius: 8px; overflow: hidden; margin-bottom: 24px; font-size: 13.5px; }
    th { background: #2D2228; text-align: left; padding: 12px; color: #E6CFC8; font-weight: 600; border-bottom: 1px solid #43333B; }
    td { padding: 11px 12px; border-bottom: 1px solid #2B1E24; color: #E2D5D0; }
    tr:hover { background: #2A1F25; }
    .badge { padding: 3px 8px; border-radius: 6px; font-size: 11.5px; font-weight: 600; }
    .badge-waiting { background: #593E47; color: #F6E7E2; }
    .badge-called { background: #2E6F54; color: #fff; }
    .badge-served { background: #1B4D3E; color: #A3E4D7; }
    .badge-cancelled { background: #5C232A; color: #FADBD8; }
    .mono { font-family: monospace; font-size: 12px; color: #BF9B8E; }
    .footer { font-size: 12px; color: #7E6570; text-align: center; margin-top: 30px; }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <h1>🏥 QueueLess — Live MongoDB Database Inspector</h1>
      <p style="color: #BF9B8E; font-size: 13px; margin-top: 4px;">Database: <strong style="color: #fff;">queueless_db</strong> | Auto-refreshing every 3s</p>
    </div>
    <span class="live-badge">● LIVE SYNC</span>
  </div>

  <div class="stats-grid">
    <div class="card"><div class="card-title">Registered Users</div><div class="card-value">${stats.totalUsers}</div></div>
    <div class="card"><div class="card-title">Departments</div><div class="card-value">${stats.totalDepartments}</div></div>
    <div class="card"><div class="card-title">Active Queue Tokens</div><div class="card-value" style="color: #A3E4D7;">${stats.activeTokens}</div></div>
    <div class="card"><div class="card-title">Total Tokens (History)</div><div class="card-value">${stats.totalTokens}</div></div>
    <div class="card"><div class="card-title">Audit Logs Recorded</div><div class="card-value">${stats.totalActivityLogs}</div></div>
  </div>

  <div class="section-title">Collection: queue_tokens (${tokens.length} records)</div>
  <table>
    <thead>
      <tr>
        <th>Token #</th>
        <th>Patient Name</th>
        <th>Department</th>
        <th>Status</th>
        <th>Joined At</th>
        <th>MongoDB _id</th>
      </tr>
    </thead>
    <tbody>
      ${tokens.length === 0 ? '<tr><td colspan="6" style="text-align:center; padding: 24px; color: #7E6570;">No queue tokens in database yet. Book a token in Flutter to see it here live!</td></tr>' : ''}
      ${tokens.map(t => `
        <tr>
          <td><strong style="color: #FFFBFA; font-size: 15px;">#${String(t.tokenNumber).padStart(2, '0')}</strong></td>
          <td>${t.patientName}</td>
          <td>${t.departmentId?.name || t.departmentId || 'General'}</td>
          <td><span class="badge badge-${t.status}">${t.status.toUpperCase()}</span></td>
          <td>${new Date(t.joinedAt).toLocaleTimeString()}</td>
          <td class="mono">${t.id}</td>
        </tr>
      `).join('')}
    </tbody>
  </table>

  <div class="section-title">Collection: activity_logs (Recent 50 Actions)</div>
  <table>
    <thead>
      <tr>
        <th>Action</th>
        <th>Patient Name</th>
        <th>Token #</th>
        <th>Actor ID</th>
        <th>Timestamp</th>
      </tr>
    </thead>
    <tbody>
      ${activityLogs.length === 0 ? '<tr><td colspan="5" style="text-align:center; padding: 24px; color: #7E6570;">No activity logs recorded yet.</td></tr>' : ''}
      ${activityLogs.map(l => `
        <tr>
          <td><strong style="color: #E6CFC8;">${l.action}</strong></td>
          <td>${l.patientName || '—'}</td>
          <td>${l.tokenNumber ? '#' + l.tokenNumber : '—'}</td>
          <td class="mono">${l.actorId}</td>
          <td>${new Date(l.timestamp).toLocaleTimeString()}</td>
        </tr>
      `).join('')}
    </tbody>
  </table>

  <div class="section-title">Collection: users (${users.length} profiles)</div>
  <table>
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Role</th>
        <th>Firebase UID</th>
        <th>Created At</th>
      </tr>
    </thead>
    <tbody>
      ${users.length === 0 ? '<tr><td colspan="5" style="text-align:center; padding: 24px; color: #7E6570;">No user profiles synced yet. Log in or register to sync profile.</td></tr>' : ''}
      ${users.map(u => `
        <tr>
          <td><strong>${u.name}</strong></td>
          <td>${u.email}</td>
          <td><span class="badge" style="background:#43333B; color:#FFFBFA;">${u.role}</span></td>
          <td class="mono">${u.firebaseUid}</td>
          <td>${new Date(u.createdAt).toLocaleDateString()}</td>
        </tr>
      `).join('')}
    </tbody>
  </table>

  <div class="footer">
    QueueLess MongoDB Real-Time Architecture • Review 2 Evaluation Ready
  </div>
</body>
</html>
    `;

    res.send(html);
  } catch (err) {
    next(err);
  }
});

// Mounted Routes
app.use('/api/users', authRoutes);
app.use('/api/departments', departmentRoutes);
app.use('/api/queues', queueRoutes);
app.use('/api/admin', adminRoutes);

// Catch-all 404
app.use((req, res) => {
  res.status(404).json({
    error: 'NotFound',
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// Centralized Error Handler
app.use(errorHandler);

module.exports = app;
