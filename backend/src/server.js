require('dotenv').config();
const http = require('http');
const app = require('./app');
const { connectDB } = require('./config/db');
const { initFirebase } = require('./config/firebase');
const { initSocket } = require('./services/socketService');

const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    // 1. Connect to MongoDB
    await connectDB();

    // 2. Initialize Firebase Admin SDK
    initFirebase();

    // 3. Create HTTP & Socket.IO server
    const server = http.createServer(app);
    initSocket(server);

    // 4. Start listening
    server.listen(PORT, () => {
      console.log(`🚀 [QueueLess Server] Running on http://localhost:${PORT}`);
      console.log(`🏥 Health check at: http://localhost:${PORT}/api/health`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('SIGTERM received. Shutting down gracefully...');
      server.close(() => {
        console.log('Server closed.');
        process.exit(0);
      });
    });
  } catch (error) {
    console.error('Fatal server startup error:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = { startServer };
