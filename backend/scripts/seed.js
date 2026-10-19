require('dotenv').config();
const mongoose = require('mongoose');
const { connectDB } = require('../src/config/db');
const Department = require('../src/models/Department');
const User = require('../src/models/User');

const standardDepartments = [
  { name: 'General Medicine', avgConsultationMins: 15, isActive: true },
  { name: 'Cardiology', avgConsultationMins: 20, isActive: true },
  { name: 'Orthopedics', avgConsultationMins: 25, isActive: true },
  { name: 'Pediatrics', avgConsultationMins: 15, isActive: true },
  { name: 'Dermatology', avgConsultationMins: 10, isActive: true },
  { name: 'Neurology', avgConsultationMins: 30, isActive: true },
];

async function seed() {
  try {
    console.log('🌱 Starting MongoDB database seeding...');
    await connectDB();

    for (const dept of standardDepartments) {
      const existing = await Department.findOne({ name: dept.name });
      if (!existing) {
        await Department.create(dept);
        console.log(`  ➕ Seeded department: ${dept.name} (${dept.avgConsultationMins} mins)`);
      } else {
        console.log(`  ✓ Department exists: ${dept.name}`);
      }
    }

    console.log('✅ Seeding completed successfully.');
    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  seed();
}

module.exports = { seed, standardDepartments };
