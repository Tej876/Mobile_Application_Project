require('dotenv').config();
const mongoose = require('mongoose');
const { connectDB } = require('../src/config/db');
const { initFirebase } = require('../src/config/firebase');
const User = require('../src/models/User');
const Department = require('../src/models/Department');
const QueueToken = require('../src/models/QueueToken');
const ActivityLog = require('../src/models/ActivityLog');

async function migrateFromFirestore() {
  console.log('🚀 [Migration] Starting Firestore to MongoDB migration...');
  await connectDB();
  const admin = initFirebase();

  try {
    const firestore = admin.firestore();

    // 1. Migrate Users
    console.log('📦 Migrating users collection...');
    const usersSnap = await firestore.collection('users').get();
    let userCount = 0;
    for (const doc of usersSnap.docs) {
      const data = doc.data();
      await User.findOneAndUpdate(
        { firebaseUid: doc.id },
        {
          firebaseUid: doc.id,
          name: data.name || '',
          email: data.email || '',
          role: data.role || 'patient',
          createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(),
        },
        { upsert: true, new: true }
      );
      userCount++;
    }
    console.log(`  ✓ Migrated ${userCount} users.`);

    // 2. Migrate Departments
    console.log('📦 Migrating departments collection...');
    const deptsSnap = await firestore.collection('departments').get();
    const deptIdMap = {}; // Maps Firestore doc.id -> MongoDB ObjectId
    let deptCount = 0;

    for (const doc of deptsSnap.docs) {
      const data = doc.data();
      const deptDoc = await Department.findOneAndUpdate(
        { name: data.name },
        {
          name: data.name,
          avgConsultationMins: data.avgConsultationMins || 15,
          isActive: true,
          createdAt: new Date(),
        },
        { upsert: true, new: true }
      );
      deptIdMap[doc.id] = deptDoc._id;
      deptCount++;

      // 3. Migrate subcollection 'queue' inside this department
      const queueSnap = await doc.ref.collection('queue').get();
      for (const qDoc of queueSnap.docs) {
        const qData = qDoc.data();
        await QueueToken.create({
          departmentId: deptDoc._id,
          patientId: qData.patientId || '',
          patientName: qData.patientName || '',
          tokenNumber: qData.tokenNumber || 1,
          status: qData.status || 'waiting',
          joinedAt: qData.joinedAt?.toDate ? qData.joinedAt.toDate() : new Date(),
          calledAt: qData.calledAt?.toDate ? qData.calledAt.toDate() : null,
          servedAt: qData.servedAt?.toDate ? qData.servedAt.toDate() : null,
          cancelledAt: qData.cancelledAt?.toDate ? qData.cancelledAt.toDate() : null,
          notifiedAt: qData.notifiedAt?.toDate ? qData.notifiedAt.toDate() : null,
        }).catch((err) => {
          // Ignore duplicate partial unique index errors during historical migration
          console.warn(`    ⚠️ Skipped duplicate/invalid token ${qDoc.id}: ${err.message}`);
        });
      }

      // 4. Migrate subcollection 'activityLog'
      const logSnap = await doc.ref.collection('activityLog').get();
      for (const lDoc of logSnap.docs) {
        const lData = lDoc.data();
        await ActivityLog.create({
          departmentId: deptDoc._id,
          tokenNumber: lData.tokenNumber || null,
          patientName: lData.patientName || '',
          actorId: lData.recipientEmail || 'system',
          action: lData.action || 'token_created',
          details: lData,
          timestamp: lData.timestamp?.toDate ? lData.timestamp.toDate() : new Date(),
        }).catch(() => {});
      }
    }
    console.log(`  ✓ Migrated ${deptCount} departments and their queues/logs.`);
    console.log('🎉 [Migration] Migration completed successfully.');
  } catch (error) {
    console.error('❌ [Migration] Error during migration:', error.message);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

if (require.main === module) {
  migrateFromFirestore();
}

module.exports = { migrateFromFirestore };
