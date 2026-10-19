const { Server } = require('socket.io');
const { admin } = require('../config/firebase');
const User = require('../models/User');

let io = null;

function initSocket(server) {
  io = new Server(server, {
    cors: {
      origin: '*', // Allow Flutter Web and mobile clients
      methods: ['GET', 'POST', 'PATCH'],
    },
    transports: ['websocket', 'polling'],
  });

  // Socket authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      if (!token) {
        // Allow unauthenticated connection for public queue length tracking, but with guest role
        socket.user = { uid: null, role: 'guest' };
        return next();
      }

      // Test mode / Mock token support
      if (process.env.NODE_ENV === 'test' && token.startsWith('mock-')) {
        const isMockAdmin = token.includes('admin');
        socket.user = {
          uid: token.replace('mock-', ''),
          email: isMockAdmin ? 'admin@queueless.test' : 'patient@queueless.test',
          name: isMockAdmin ? 'Test Admin' : 'Test Patient',
          role: isMockAdmin ? 'admin' : 'patient',
        };
        return next();
      }

      const decodedToken = await admin.auth().verifyIdToken(token);
      const dbUser = await User.findOne({ firebaseUid: decodedToken.uid });

      socket.user = {
        uid: decodedToken.uid,
        email: decodedToken.email,
        name: decodedToken.name || dbUser?.name || 'User',
        role: dbUser ? dbUser.role : 'patient',
      };

      next();
    } catch (err) {
      console.warn(`⚠️ [Socket.IO] Auth verification failed: ${err.message}. Assigning guest.`);
      socket.user = { uid: null, role: 'guest' };
      next();
    }
  });

  io.on('connection', (socket) => {
    const userUid = socket.user?.uid;
    const userRole = socket.user?.role;

    console.log(`🔌 [Socket.IO] Client connected: ${socket.id} (User: ${userUid || 'Guest'}, Role: ${userRole})`);

    // Auto-join personal user room if authenticated
    if (userUid) {
      socket.join(`user:${userUid}`);
    }

    // Subscribe to department room for live queue updates
    socket.on('join:department', (deptId) => {
      if (deptId) {
        socket.join(`department:${deptId}`);
        console.log(`📌 [Socket.IO] ${socket.id} joined department:${deptId}`);
      }
    });

    socket.on('leave:department', (deptId) => {
      if (deptId) {
        socket.leave(`department:${deptId}`);
        console.log(`📌 [Socket.IO] ${socket.id} left department:${deptId}`);
      }
    });

    socket.on('disconnect', (reason) => {
      console.log(`🔌 [Socket.IO] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  return io;
}

function getIO() {
  return io;
}

// Broadcasting helpers
function emitQueueUpdated(departmentId, payload = {}) {
  if (!io) return;
  const deptRoom = `department:${departmentId}`;
  io.to(deptRoom).emit('queue:updated', { departmentId, ...payload, timestamp: new Date().toISOString() });
}

function emitTokenCreated(token) {
  if (!io || !token) return;
  const deptRoom = `department:${token.departmentId}`;
  const userRoom = `user:${token.patientId}`;
  const payload = { token, timestamp: new Date().toISOString() };

  io.to(deptRoom).emit('token:created', payload);
  io.to(userRoom).emit('token:created', payload);
  emitQueueUpdated(token.departmentId);
}

function emitTokenCancelled(token) {
  if (!io || !token) return;
  const deptRoom = `department:${token.departmentId}`;
  const userRoom = `user:${token.patientId}`;
  const payload = { token, timestamp: new Date().toISOString() };

  io.to(deptRoom).emit('token:cancelled', payload);
  io.to(userRoom).emit('token:cancelled', payload);
  emitQueueUpdated(token.departmentId);
}

function emitTokenCalled(token) {
  if (!io || !token) return;
  const deptRoom = `department:${token.departmentId}`;
  const userRoom = `user:${token.patientId}`;
  const payload = { token, timestamp: new Date().toISOString() };

  io.to(deptRoom).emit('token:called', payload);
  io.to(userRoom).emit('token:called', payload);
  emitQueueUpdated(token.departmentId);
}

function emitTokenCompleted(token) {
  if (!io || !token) return;
  const deptRoom = `department:${token.departmentId}`;
  const userRoom = `user:${token.patientId}`;
  const payload = { token, timestamp: new Date().toISOString() };

  io.to(deptRoom).emit('token:completed', payload);
  io.to(userRoom).emit('token:completed', payload);
  emitQueueUpdated(token.departmentId);
}

module.exports = {
  initSocket,
  getIO,
  emitQueueUpdated,
  emitTokenCreated,
  emitTokenCancelled,
  emitTokenCalled,
  emitTokenCompleted,
};
