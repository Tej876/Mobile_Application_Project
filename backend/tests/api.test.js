const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const Department = require('../src/models/Department');
const QueueToken = require('../src/models/QueueToken');
const ActivityLog = require('../src/models/ActivityLog');

require('./setup');

describe('QueueLess Backend Integration Tests', () => {
  let sampleDept;
  const patientUid = 'patient-uid-123';
  const adminUid = 'admin-uid-999';

  const patientToken = `mock-${patientUid}`;
  const adminToken = `mock-admin-${adminUid}`;

  beforeEach(async () => {
    // Seed test department
    sampleDept = await Department.create({
      name: 'General Medicine',
      avgConsultationMins: 15,
      isActive: true,
    });

    // Seed test users in MongoDB
    await User.create({
      firebaseUid: patientUid,
      name: 'Jane Doe',
      email: 'jane@example.com',
      role: 'patient',
    });

    await User.create({
      firebaseUid: adminUid,
      name: 'Dr. Admin',
      email: 'admin@queueless.test',
      role: 'admin',
    });
  });

  describe('Root and Health API', () => {
    test('GET / returns 200 OK and API overview', async () => {
      const res = await request(app).get('/');
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('QueueLess Backend API');
      expect(res.body.status).toBe('online');
      expect(res.body.endpoints).toBeDefined();
    });

    test('GET /api/health returns 200 OK and database status', async () => {
      const res = await request(app).get('/api/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.database).toBe('connected');
    });
  });

  describe('Authentication & Profile [AUTH-01, AUTH-05]', () => {
    test('[AUTH-01] GET /api/users/me returns authenticated patient profile', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${patientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.user.firebaseUid).toBe(patientUid);
      expect(res.body.user.role).toBe('patient');
    });

    test('[AUTH-05] Patient attempting admin endpoint receives HTTP 403 Forbidden', async () => {
      const res = await request(app)
        .get(`/api/admin/queues/${sampleDept.id}`)
        .set('Authorization', `Bearer ${patientToken}`); // Patient token

      expect(res.status).toBe(403);
      expect(res.body.error).toBe('Forbidden');
    });

    test('Unauthenticated request to protected endpoint receives HTTP 401 Unauthorized', async () => {
      const res = await request(app).get('/api/users/me');
      expect(res.status).toBe(401);
    });

    test('Firebase account with no MongoDB profile can recover as a patient', async () => {
      const uid = 'firebase-only-patient-456';
      const token = `mock-${uid}`;

      const missingRes = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${token}`);

      expect(missingRes.status).toBe(404);

      const recoveryRes = await request(app)
        .post('/api/users/me/recover')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Recovered Patient',
          firebaseUid: 'client-supplied-uid',
          email: 'client-supplied@example.com',
          role: 'admin',
        });

      expect(recoveryRes.status).toBe(201);
      expect(recoveryRes.body.user.firebaseUid).toBe(uid);
      expect(recoveryRes.body.user.email).toBe('patient@queueless.test');
      expect(recoveryRes.body.user.name).toBe('Recovered Patient');
      expect(recoveryRes.body.user.role).toBe('patient');

      const storedUser = await User.findOne({ firebaseUid: uid });
      expect(storedUser).not.toBeNull();
      expect(storedUser.role).toBe('patient');
    });

    test('recovery is idempotent and preserves an existing profile', async () => {
      const uid = 'firebase-only-patient-repeat';
      const token = `mock-${uid}`;
      const endpoint = () =>
        request(app)
          .post('/api/users/me/recover')
          .set('Authorization', `Bearer ${token}`)
          .send({ name: 'First Recovery Name' });

      const firstRes = await endpoint();
      const secondRes = await endpoint();

      expect(firstRes.status).toBe(201);
      expect(secondRes.status).toBe(200);
      expect(secondRes.body.user.id).toBe(firstRes.body.user.id);
      expect(secondRes.body.user.name).toBe('First Recovery Name');
      expect(await User.countDocuments({ firebaseUid: uid })).toBe(1);
    });

    test('temporary MongoDB failure remains a server error, not a missing-profile response', async () => {
      const findOne = jest
        .spyOn(User, 'findOne')
        .mockResolvedValueOnce(null)
        .mockRejectedValueOnce(new Error('temporary database failure'));

      try {
        const res = await request(app)
          .get('/api/users/me')
          .set('Authorization', `Bearer ${patientToken}`);

        expect(res.status).toBe(500);
        expect(res.status).not.toBe(404);
      } finally {
        findOne.mockRestore();
      }
    });
  });

  describe('Departments API', () => {
    test('GET /api/departments returns active departments with queue length', async () => {
      const res = await request(app)
        .get('/api/departments')
        .set('Authorization', `Bearer ${patientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.departments)).toBe(true);
      expect(res.body.departments.length).toBe(1);
      expect(res.body.departments[0].name).toBe('General Medicine');
      expect(res.body.departments[0].activeQueueLength).toBe(0);
    });
  });

  describe('Queue Operations [QUE-01, QUE-02, QUE-03, QUE-04, DB-02]', () => {
    test('[QUE-01] Patient can join department queue and receive token #1', async () => {
      const res = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({
          departmentId: sampleDept.id,
          patientName: 'Jane Doe',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.token.tokenNumber).toBe(1);
      expect(res.body.token.position).toBe(1);
      expect(res.body.token.estWaitMins).toBe(5); // 0 ahead * 15 + 5 = 5

      const savedInDb = await QueueToken.findOne({ patientId: patientUid });
      expect(savedInDb).not.toBeNull();
      expect(savedInDb.status).toBe('waiting');
    });

    test('[QUE-02] Duplicate booking attempt while active is rejected with HTTP 409 Conflict', async () => {
      // First booking
      await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({
          departmentId: sampleDept.id,
          patientName: 'Jane Doe',
        });

      // Second booking attempt by the same patient
      const res = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({
          departmentId: sampleDept.id,
          patientName: 'Jane Doe',
        });

      expect(res.status).toBe(409);
      expect(res.body.error).toBe('Conflict');
    });

    test('[QUE-03] Sequential bookings receive ordered token numbers and estimated waits', async () => {
      // Patient 1
      await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Jane Doe' });

      // Patient 2
      const patient2Uid = 'patient-uid-456';
      await User.create({
        firebaseUid: patient2Uid,
        name: 'John Smith',
        email: 'john@example.com',
        role: 'patient',
      });

      const res2 = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer mock-${patient2Uid}`)
        .send({ departmentId: sampleDept.id, patientName: 'John Smith' });

      expect(res2.status).toBe(201);
      expect(res2.body.token.tokenNumber).toBe(2);
      expect(res2.body.token.position).toBe(2);
      expect(res2.body.token.estWaitMins).toBe(20); // 1 ahead * 15 + 5 = 20
    });

    test('[QUE-04] Patient can cancel waiting token and remaining tokens are renumbered', async () => {
      // Create Patient 1 and Patient 2
      const p1Res = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Jane Doe' });

      const patient2Uid = 'patient-uid-456';
      await User.create({
        firebaseUid: patient2Uid,
        name: 'John Smith',
        email: 'john@example.com',
        role: 'patient',
      });

      const p2Res = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer mock-${patient2Uid}`)
        .send({ departmentId: sampleDept.id, patientName: 'John Smith' });

      const p1TokenId = p1Res.body.token.id;

      // Patient 1 cancels
      const cancelRes = await request(app)
        .patch(`/api/queues/${p1TokenId}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);

      expect(cancelRes.status).toBe(200);
      expect(cancelRes.body.token.status).toBe('cancelled');

      // Patient 2 should now be renumbered to token #1!
      const p2InDb = await QueueToken.findById(p2Res.body.token.id);
      expect(p2InDb.tokenNumber).toBe(1);

      // Verify activity log was recorded
      const log = await ActivityLog.findOne({ tokenId: p1TokenId, action: 'token_cancelled' });
      expect(log).not.toBeNull();
    });

    test('[DB-02] Another patient cannot cancel someone else token', async () => {
      const p1Res = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Jane Doe' });

      const maliciousUid = 'malicious-user-666';
      await User.create({
        firebaseUid: maliciousUid,
        name: 'Attacker',
        email: 'attacker@example.com',
        role: 'patient',
      });

      const cancelRes = await request(app)
        .patch(`/api/queues/${p1Res.body.token.id}/cancel`)
        .set('Authorization', `Bearer mock-${maliciousUid}`);

      expect(cancelRes.status).toBe(403);
      expect(cancelRes.body.error).toBe('Forbidden');
    });
  });

  describe('Admin Operations [QUE-05, QUE-06]', () => {
    test('[QUE-05] Admin can call next patient in line and update status to called', async () => {
      const bookRes = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Jane Doe' });

      const callRes = await request(app)
        .patch(`/api/admin/queues/${sampleDept.id}/call-next`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(callRes.status).toBe(200);
      expect(callRes.body.token.status).toBe('called');
      expect(callRes.body.token.calledAt).toBeDefined();

      const inDb = await QueueToken.findById(bookRes.body.token.id);
      expect(inDb.status).toBe('called');
    });

    test('[QUE-06] Admin can complete consultation and mark token served', async () => {
      const bookRes = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Jane Doe' });

      const completeRes = await request(app)
        .patch(`/api/admin/queues/${bookRes.body.token.id}/complete`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(completeRes.status).toBe(200);
      expect(completeRes.body.token.status).toBe('served');
      expect(completeRes.body.token.servedAt).toBeDefined();

      const log = await ActivityLog.findOne({ tokenId: bookRes.body.token.id, action: 'token_served' });
      expect(log).not.toBeNull();
    });
  });
});
