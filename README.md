# QueueLess (Review 2) — Real-Time Clinic Queue Dispatch System

QueueLess is a real-time clinic and outpatient queue management application built for **Android and Web**.

In **Review 2**, the application database was successfully migrated from Firebase Cloud Firestore to **MongoDB Atlas** with a dedicated **Node.js + Express + Socket.IO** backend, while preserving 100% of the Review 1 UI, workflow, and features.

---

## Architecture & Technology Stack

| Layer | Technology | Role |
|---|---|---|
| **Frontend** | Flutter 3.47 + Dart | Mobile (Android) & Web interfaces with Provider state management |
| **Authentication** | Firebase Authentication | Secure email/password login & registration |
| **Database** | MongoDB Atlas (`queueless_db`) | Primary NoSQL database (`users`, `departments`, `queue_tokens`, `activity_logs`) |
| **Backend API** | Node.js + Express | REST APIs with Firebase Admin token verification & authorization middleware |
| **Live Updates** | Socket.IO | Real-time queue changes and notification broadcasting |
| **Notifications** | Flutter Local Notifications | Floating in-app banners & native device notification channels |
| **Emails** | EmailJS | Booking confirmation email delivery with persistent audit logs |

---

## Live Deployed Web Application
- **URL:** [https://queueless-12345.web.app/](https://queueless-12345.web.app/)

---

## Project Structure

```
queueless/
├── backend/                   # Node.js + Express + MongoDB backend
│   ├── scripts/
│   │   ├── seed.js            # Department database seeding script
│   │   └── migrate_firestore.js # Firestore to MongoDB migration script
│   ├── src/
│   │   ├── config/            # MongoDB and Firebase Admin configurations
│   │   ├── middleware/        # verifyToken and requireAdmin middleware
│   │   ├── models/            # Mongoose schemas (User, Department, QueueToken, ActivityLog)
│   │   ├── routes/            # REST endpoints (/users, /departments, /queues, /admin)
│   │   ├── services/          # Queue business logic & Socket.IO emitter
│   │   ├── app.js             # Express app setup
│   │   └── server.js          # Server entry point
│   └── tests/
│       ├── setup.js           # MongoMemoryServer isolated test environment
│       └── api.test.js        # Full integration test suite (12 test cases)
├── lib/                       # Flutter client code
│   ├── models/                # AppUser, Department, QueueToken, ActivityLog
│   ├── providers/             # AuthProvider, QueueProvider (API + Socket.IO driven)
│   ├── screens/               # Auth, Splash, Department Selection, Live Pass, Admin Dashboard
│   ├── services/              # ApiService, SocketService, ApiConfig, NotificationService, EmailService
│   └── theme/                 # Blush-Peach-Nude-Plum-Maroon-Charcoal design system
├── test/
│   └── widget_test.dart       # Flutter unit tests for models & wait calculations
├── DESIGN.md                  # Visual system & design token specifications
├── PRODUCT.md                 # Product objectives & clinical audience specification
└── TESTING.md                 # Review 2 rubric test matrix, results, and bug fixes evidence
```

---

## Getting Started

### 1. Prerequisites
- **Node.js** v18+ and **npm**
- **Flutter SDK** v3.19+
- **Google Chrome** (for web) or **Android Studio / Emulator** (for mobile)

---

### 2. Backend Setup & Run

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables in `.env` (or copy from `.env.example`):
   ```env
   PORT=5000
   MONGODB_URI=mongodb+srv://<user>:<password>@cluster0.mongodb.net/queueless_db?retryWrites=true&w=majority
   FIREBASE_PROJECT_ID=queueless-12345
   ADMIN_BOOTSTRAP_SECRET=queueless_admin_bootstrap_secret_2026
   ```
4. Seed standard departments:
   ```bash
   npm run seed
   ```
5. Run the automated backend tests:
   ```bash
   npm test
   ```
6. Start the backend server:
   ```bash
   npm start
   ```
   The backend will be running at `http://localhost:5000` (Health check at `http://localhost:5000/api/health`).

---

### 3. Flutter App Setup & Run

1. In the project root, install Flutter packages:
   ```bash
   flutter pub get
   ```
2. Run unit tests:
   ```bash
   flutter test
   ```
3. Launch on Web (Chrome):
   ```bash
   flutter run -d chrome
   ```
4. Launch on Android Emulator:
   ```bash
   flutter run -d android
   ```
   *(Android automatically resolves `http://10.0.2.2:5000` via `lib/services/api_config.dart`)*

---

## Evaluation Rubric Verification
See [`TESTING.md`](TESTING.md) for the complete 19-test evaluation matrix, pass/fail evidence, bug resolution logs, and rubric mapping.
