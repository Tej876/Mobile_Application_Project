const mongoose = require('mongoose');

let mongoMemoryInstance = null;

async function connectDB(uri) {
  const mongoUri = uri || process.env.MONGODB_URI || 'mongodb://localhost:27017/queueless_db';

  try {
    const conn = await mongoose.connect(mongoUri, {
      autoIndex: true,
      serverSelectionTimeoutMS: 2000, // Quick timeout to detect if local mongod is absent
    });
    console.log(`✅ [MongoDB] Connected to database: ${conn.connection.name} (${conn.connection.host})`);
    return conn;
  } catch (error) {
    // If local mongod is not running, provide an automatic embedded MongoDB fallback for instant local dev
    const isLocalhost = mongoUri.includes('localhost') || mongoUri.includes('127.0.0.1');
    const isConnectionRefused = error.message.includes('ECONNREFUSED') || error.message.includes('buffering timed out');

    if (isLocalhost && isConnectionRefused && process.env.NODE_ENV !== 'production') {
      console.warn(`⚠️ [MongoDB] Local MongoDB is not running on 127.0.0.1:27017 (${error.message}).`);
      console.log(`🚀 [MongoDB] Spinning up self-contained embedded MongoDB database for local development...`);

      try {
        const { MongoMemoryServer } = require('mongodb-memory-server');
        mongoMemoryInstance = await MongoMemoryServer.create({
          instance: {
            dbName: 'queueless_db',
          },
        });

        const memoryUri = mongoMemoryInstance.getUri();
        const conn = await mongoose.connect(memoryUri, {
          autoIndex: true,
        });

        console.log(`✅ [MongoDB] Connected to embedded MongoDB successfully!`);
        console.log(`ℹ️ [Note] For cloud persistence, put your MongoDB Atlas connection string in backend/.env:`);
        console.log(`   MONGODB_URI=mongodb+srv://<username>:<password>@cluster0.mongodb.net/queueless_db?retryWrites=true&w=majority\n`);

        // Automatically seed standard departments so app is ready immediately
        try {
          const Department = require('../models/Department');
          const count = await Department.countDocuments();
          if (count === 0) {
            const { standardDepartments } = require('../../scripts/seed');
            await Department.insertMany(standardDepartments);
            console.log(`🌱 [MongoDB] Auto-seeded 6 standard clinic departments into database.`);
          }
        } catch (seedErr) {
          console.warn(`⚠️ [MongoDB] Seeding notice: ${seedErr.message}`);
        }

        return conn;
      } catch (memErr) {
        console.error(`❌ [MongoDB] Embedded fallback failed: ${memErr.message}`);
      }
    }

    console.error(`❌ [MongoDB] Connection error: ${error.message}`);
    console.error(`\n👉 HOW TO FIX THIS:`);
    console.error(`Option A (Cloud - Recommended):`);
    console.error(`  1. Create a free database on MongoDB Atlas (https://www.mongodb.com/cloud/atlas)`);
    console.error(`  2. In backend/.env, set MONGODB_URI to your Atlas connection string:`);
    console.error(`     MONGODB_URI=mongodb+srv://<user>:<password>@cluster0.mongodb.net/queueless_db?retryWrites=true&w=majority\n`);
    console.error(`Option B (Local):`);
    console.error(`  Start your local MongoDB service:`);
    console.error(`  net start MongoDB  (Windows) or mongod\n`);

    if (process.env.NODE_ENV !== 'test') {
      process.exit(1);
    }
    throw error;
  }
}

async function disconnectDB() {
  await mongoose.disconnect();
  if (mongoMemoryInstance) {
    await mongoMemoryInstance.stop();
  }
}

module.exports = { connectDB, disconnectDB };
