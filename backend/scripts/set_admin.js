require('dotenv').config();
const mongoose = require('mongoose');
const { connectDB } = require('../src/config/db');
const User = require('../src/models/User');

async function setAdmin() {
  const target = process.argv[2];
  if (!target) {
    console.log('Usage: node scripts/set_admin.js <email_or_firebaseUid>');
    console.log('Example: node scripts/set_admin.js admin@example.com');
    process.exit(1);
  }

  await connectDB();

  const user = await User.findOne({
    $or: [
      { email: target.toLowerCase().trim() },
      { firebaseUid: target.trim() },
    ],
  });

  if (!user) {
    // If user record doesn't exist yet, create an admin profile entry
    const isEmail = target.includes('@');
    const newUser = await User.create({
      firebaseUid: isEmail ? 'pending-' + Date.now() : target,
      name: 'Admin User',
      email: isEmail ? target.toLowerCase().trim() : 'admin@clinic.test',
      role: 'admin',
    });
    console.log(`✅ Created new Admin profile in MongoDB for: ${target}`);
  } else {
    user.role = 'admin';
    await user.save();
    console.log(`✅ Updated ${user.email} (${user.firebaseUid}) role to: 'admin'`);
  }

  await mongoose.disconnect();
  process.exit(0);
}

if (require.main === module) {
  setAdmin();
}

module.exports = { setAdmin };
