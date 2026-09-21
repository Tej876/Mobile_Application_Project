# QueueLess

QueueLess is a Flutter mobile/web application for real-time clinic queue management.

## Features

- Patient and Admin roles
- Email/password login with Firebase Authentication
- Real-time department queues using Cloud Firestore
- Patients can join a department queue and view:
  - Token number
  - Queue position
  - Estimated waiting time
  - Current status
- Patients can cancel only while their token is waiting
- Admin can call the next patient, mark a patient as served, or mark no-show
- Queue activity log
- Firebase Cloud Messaging support for third-in-line notifications

## Tech Stack

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging
- Provider state management

## Requirements

Install:

- Flutter SDK
- Google Chrome or Android emulator/device
- Firebase CLI
- FlutterFire CLI

## Run Locally

Clone the repository:

```bash
git clone https://github.com/Tej876/Mobile_Application_Project.git
cd Mobile_Application_Project
