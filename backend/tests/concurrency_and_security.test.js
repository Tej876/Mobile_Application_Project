const request = require('supertest');
const app = require('../src/app');
const User = require('../src/models/User');
const Department = require('../src/models/Department');
const QueueToken = require('../src/models/QueueToken');
const ActivityLog = require('../src/models/ActivityLog');
const socketService = require('../src/services/socketService');

require('./setup');

describe('QueueLess Concurrency, Security & Extended API Tests', () => {
  let sampleDept;
  const patientUid = 'patient-uid-101';
  const adminUid = 'admin-uid-999';

  const patientToken = `mock-${patientUid}`;
  const adminToken = `mock-admin-${adminUid}`;

  beforeEach(async () => {
    // Ensure Mongoose unique indexes (including partial unique index on QueueToken) are built
    await QueueToken.init();
    await User.init();
    await Department.init();

    // Seed test department
    sampleDept = await Department.create({
      name: 'Cardiology',
      avgConsultationMins: 20,
      isActive: true,
    });

    // Seed test patient
    await User.create({
      firebaseUid: patientUid,
      name: 'Alice Wonder',
      email: 'alice@example.com',
      role: 'patient',
    });

    // Seed test admin
    await User.create({
      firebaseUid: adminUid,
      name: 'Dr. Head Admin',
      email: 'admin@queueless.test',
      role: 'admin',
    });
  });

  // =========================================================================
  // 1. CONCURRENCY & SIMULTANEOUS BOOKING TESTS
  // =========================================================================
  describe('Simultaneous Booking & Concurrency Protection [CONC-01, CONC-02]', () => {
    test('[CONC-01] Simultaneous double-booking by same patient is caught by concurrency protection', async () => {
      // Fire 2 concurrent join requests at the exact same millisecond via Promise.all
      const [res1, res2] = await Promise.all([
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer ${patientToken}`)
          .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' }),
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer ${patientToken}`)
          .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' }),
      ]);

      const statuses = [res1.status, res2.status].sort();
      // Exactly one request must succeed (201) and one must be rejected (409)
      expect(statuses).toEqual([201, 409]);

      // Verify that in MongoDB, exactly ONE active token exists for this patient
      const activeTokens = await QueueToken.find({
        patientId: patientUid,
        status: { $in: ['waiting', 'called'] },
      });
      expect(activeTokens.length).toBe(1);
    });

    test('[CONC-02] Multiple distinct patients booking simultaneously receive ordered token numbers', async () => {
      const p2Uid = 'patient-uid-202';
      const p3Uid = 'patient-uid-303';
      const p4Uid = 'patient-uid-404';

      await User.insertMany([
        { firebaseUid: p2Uid, name: 'Bob', email: 'bob@example.com', role: 'patient' },
        { firebaseUid: p3Uid, name: 'Charlie', email: 'charlie@example.com', role: 'patient' },
        { firebaseUid: p4Uid, name: 'Diana', email: 'diana@example.com', role: 'patient' },
      ]);

      // 4 patients join the queue concurrently
      const results = await Promise.all([
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer ${patientToken}`)
          .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' }),
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer mock-${p2Uid}`)
          .send({ departmentId: sampleDept.id, patientName: 'Bob' }),
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer mock-${p3Uid}`)
          .send({ departmentId: sampleDept.id, patientName: 'Charlie' }),
        request(app)
          .post('/api/queues')
          .set('Authorization', `Bearer mock-${p4Uid}`)
          .send({ departmentId: sampleDept.id, patientName: 'Diana' }),
      ]);

      // All 4 requests must succeed with HTTP 201
      results.forEach((res) => {
        expect(res.status).toBe(201);
        expect(res.body.success).toBe(true);
      });

      // Query database for all waiting tokens in this department
      const tokensInDb = await QueueToken.find({
        departmentId: sampleDept.id,
        status: 'waiting',
      }).sort({ tokenNumber: 1 });

      expect(tokensInDb.length).toBe(4);

      // Verify strict sequential ordering with zero collisions: [1, 2, 3, 4]
      const tokenNumbers = tokensInDb.map((t) => t.tokenNumber);
      expect(tokenNumbers).toEqual([1, 2, 3, 4]);
    });
  });

  // =========================================================================
  // 2. AUTHENTICATION, AUTHORIZATION & SECURITY TESTS
  // =========================================================================
  describe('Authentication, Authorization & Role Security [AUTH-SEC]', () => {
    test('[AUTH-SEC-01] Patient cannot self-escalate role to admin without bootstrap secret', async () => {
      const res = await request(app)
        .post('/api/users/me')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({
          name: 'Alice Hacker',
          email: 'alice@example.com',
          role: 'admin', // Attempt unauthorized role elevation
        });

      expect(res.status).toBe(200);
      // Privilege escalation must be rejected: assigned role remains patient
      expect(res.body.user.role).toBe('patient');

      const userInDb = await User.findOne({ firebaseUid: patientUid });
      expect(userInDb.role).toBe('patient');
    });

    test('[AUTH-SEC-02] Patient providing invalid bootstrap secret cannot elevate to admin', async () => {
      const res = await request(app)
        .post('/api/users/me')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({
          name: 'Alice Hacker',
          email: 'alice@example.com',
          role: 'admin',
          adminSecret: 'wrong_guess_secret_xyz',
        });

      expect(res.status).toBe(200);
      expect(res.body.user.role).toBe('patient');

      const userInDb = await User.findOne({ firebaseUid: patientUid });
      expect(userInDb.role).toBe('patient');
    });

    test('[AUTH-SEC-03] Legitimate admin provisioning succeeds with valid bootstrap secret', async () => {
      const newAdminUid = 'bootstrap-admin-007';
      const bootstrapSecret = process.env.ADMIN_BOOTSTRAP_SECRET || 'queueless_admin_bootstrap_secret_2026';

      const res = await request(app)
        .post('/api/users/me')
        .set('Authorization', `Bearer mock-${newAdminUid}`)
        .send({
          name: 'Legit Admin',
          email: 'newadmin@queueless.test',
          role: 'admin',
          adminSecret: bootstrapSecret,
        });

      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe('admin');

      const userInDb = await User.findOne({ firebaseUid: newAdminUid });
      expect(userInDb.role).toBe('admin');
    });

    test('[AUTH-SEC-04] Request with empty Bearer token receives HTTP 401 Unauthorized', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', 'Bearer ');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('Unauthorized');
    });
  });

  // =========================================================================
  // 3. PATIENT ACTIVE TOKEN, HISTORY & CANCELLATION TESTS
  // =========================================================================
  describe('Active Token, History & Cancellation Edge Cases [QUE-EXT]', () => {
    test('[QUE-EXT-01] GET /api/queues/active returns active token with position and wait time', async () => {
      // 1. When patient has no active token
      const emptyRes = await request(app)
        .get('/api/queues/active')
        .set('Authorization', `Bearer ${patientToken}`);

      expect(emptyRes.status).toBe(200);
      expect(emptyRes.body.hasActiveToken).toBe(false);
      expect(emptyRes.body.token).toBeNull();

      // 2. Book a token
      await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      // 3. When patient has an active token
      const activeRes = await request(app)
        .get('/api/queues/active')
        .set('Authorization', `Bearer ${patientToken}`);

      expect(activeRes.status).toBe(200);
      expect(activeRes.body.hasActiveToken).toBe(true);
      expect(activeRes.body.token.tokenNumber).toBe(1);
      expect(activeRes.body.token.position).toBe(1);
      expect(activeRes.body.token.estWaitMins).toBe(5);
    });

    test('[QUE-EXT-02] GET /api/queues/history returns patient past tokens sorted newest first', async () => {
      // Book token #1
      const book1 = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      // Cancel token #1
      await request(app)
        .patch(`/api/queues/${book1.body.token.id}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);

      // Book token #2
      await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      const historyRes = await request(app)
        .get('/api/queues/history')
        .set('Authorization', `Bearer ${patientToken}`);

      expect(historyRes.status).toBe(200);
      expect(historyRes.body.success).toBe(true);
      expect(historyRes.body.tokens.length).toBe(2);
      // Newest should be first
      expect(new Date(historyRes.body.tokens[0].joinedAt).getTime()).toBeGreaterThanOrEqual(
        new Date(historyRes.body.tokens[1].joinedAt).getTime()
      );
    });

    test('[QUE-EXT-03] Attempting to cancel an already cancelled token returns HTTP 400 Bad Request', async () => {
      const bookRes = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      const tokenId = bookRes.body.token.id;

      // First cancel succeeds
      const cancel1 = await request(app)
        .patch(`/api/queues/${tokenId}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);
      expect(cancel1.status).toBe(200);

      // Second cancel on already cancelled token must return 400 Bad Request
      const cancel2 = await request(app)
        .patch(`/api/queues/${tokenId}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);
      expect(cancel2.status).toBe(400);
      expect(cancel2.body.error).toBe('BadRequest');
      expect(cancel2.body.message).toContain('current status is \'cancelled\'');
    });

    test('[QUE-EXT-04] Attempting to cancel a non-existent token ID returns HTTP 404 Not Found', async () => {
      const nonExistentId = '654321654321654321654321'; // Valid 24-char ObjectId that does not exist
      const res = await request(app)
        .patch(`/api/queues/${nonExistentId}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);

      expect(res.status).toBe(404);
      expect(res.body.error).toBe('NotFound');
    });
  });

  // =========================================================================
  // 4. ADMIN EDGE CASES & DISPATCH TESTS
  // =========================================================================
  describe('Admin Operations Edge Cases [ADM-EXT]', () => {
    test('[ADM-EXT-01] Admin call-next on an empty queue returns HTTP 404 Not Found', async () => {
      const res = await request(app)
        .patch(`/api/admin/queues/${sampleDept.id}/call-next`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(404);
      expect(res.body.error).toBe('NotFound');
      expect(res.body.message).toBe('No waiting patients in queue for this department');
    });

    test('[ADM-EXT-02] Admin can mark a patient as no-show and record activity log', async () => {
      const bookRes = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      const tokenId = bookRes.body.token.id;

      const noShowRes = await request(app)
        .patch(`/api/admin/queues/${tokenId}/no-show`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(noShowRes.status).toBe(200);
      expect(noShowRes.body.token.status).toBe('no_show');

      // Verify database persistence
      const inDb = await QueueToken.findById(tokenId);
      expect(inDb.status).toBe('no_show');

      // Verify activity log was recorded
      const log = await ActivityLog.findOne({ tokenId, action: 'token_no_show' });
      expect(log).not.toBeNull();
    });

    test('[ADM-EXT-03] Admin can fetch department activity logs via GET /api/admin/activity/:deptId', async () => {
      // Book a token to generate an activity log
      await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      const res = await request(app)
        .get(`/api/admin/activity/${sampleDept.id}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.activityLogs)).toBe(true);
      expect(res.body.activityLogs.length).toBeGreaterThanOrEqual(1);
      expect(res.body.activityLogs[0].action).toBe('token_created');
    });
  });

  // =========================================================================
  // 5. SOCKET.IO EVENT EMISSION & LIFECYCLE TESTS
  // =========================================================================
  describe('Socket.IO Service & Event Broadcasting [SOCK-01, SOCK-02]', () => {
    test('[SOCK-01] Socket service event emitters execute gracefully when io is null', () => {
      // socketService exports emit methods that guard if (!io) return;
      expect(() => {
        socketService.emitQueueUpdated(sampleDept.id);
        socketService.emitTokenCreated({ departmentId: sampleDept.id, patientId: patientUid });
        socketService.emitTokenCancelled({ departmentId: sampleDept.id, patientId: patientUid });
        socketService.emitTokenCalled({ departmentId: sampleDept.id, patientId: patientUid });
        socketService.emitTokenCompleted({ departmentId: sampleDept.id, patientId: patientUid });
      }).not.toThrow();
    });

    test('[SOCK-02] Queue operations trigger real-time broadcast methods with token payload', async () => {
      const emitCreatedSpy = jest.spyOn(socketService, 'emitTokenCreated');
      const emitCancelledSpy = jest.spyOn(socketService, 'emitTokenCancelled');

      // 1. Booking triggers emitTokenCreated
      const bookRes = await request(app)
        .post('/api/queues')
        .set('Authorization', `Bearer ${patientToken}`)
        .send({ departmentId: sampleDept.id, patientName: 'Alice Wonder' });

      expect(emitCreatedSpy).toHaveBeenCalledTimes(1);
      expect(emitCreatedSpy.mock.calls[0][0].patientName).toBe('Alice Wonder');

      // 2. Cancellation triggers emitTokenCancelled
      await request(app)
        .patch(`/api/queues/${bookRes.body.token.id}/cancel`)
        .set('Authorization', `Bearer ${patientToken}`);

      expect(emitCancelledSpy).toHaveBeenCalledTimes(1);
      expect(emitCancelledSpy.mock.calls[0][0].status).toBe('cancelled');

      emitCreatedSpy.mockRestore();
      emitCancelledSpy.mockRestore();
    });
  });
});
