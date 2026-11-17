# NCC Attendance – Flutter App

A basic mobile companion to the NCC Attendance Portal. Staff log in, see the cadet list,
mark each cadet **P**resent / **A**bsent / **L**ate, and submit. A summary screen shows the totals.

It calls the same Express backend as the web portal (`app/backend`). If the backend isn't
running, it switches to **demo mode** with built-in sample cadets, so it opens without any setup.

## Screens
1. **Login** – staff email and password (`POST /api/auth/login`)
2. **Mark Attendance** – cadet list with P/A/L (present/absent/late) toggles and a "mark all present" button (`GET /api/students`)
3. **Face Attendance** (face icon in the top bar) – take a photo of one cadet or a whole platoon. The
   [face recognition service](../../face-recognition/README.md) identifies the faces, staff confirm the matches,
   and the confirmed cadets are marked Present.
4. **Summary** – present/absent/late counts and attendance % (`POST /api/attendance/mark`)

## Project structure
```
lib/
├── main.dart                  # App entry + theme
├── models/cadet.dart          # Cadet model + AttendanceStatus enum
├── data/mock_data.dart        # Sample cadets for demo mode
├── services/
│   ├── api_service.dart       # HTTP calls to the Express backend (with offline fallback)
│   └── face_service.dart      # Sends photos to the face recognition service
└── screens/
    ├── login_screen.dart
    ├── attendance_screen.dart
    ├── face_capture_screen.dart
    └── summary_screen.dart
```

## How to open and run

### 1. Install the tools (one-time)
- Install the **Flutter SDK**: https://docs.flutter.dev/get-started/install
- Install **Android Studio** (for the Android SDK and an emulator) or **VS Code** with the Flutter extension.
- Check your setup:
  ```bash
  flutter doctor
  ```

### 2. Generate the platform folders
This repo contains only the Dart source code. Run this once inside this folder to create the
`android/`, `ios/`, `web/` and other platform folders (your existing `lib/` code is kept):
```bash
cd mobile/ncc_attendance_app
flutter create .
```

### 3. Install the packages
```bash
flutter pub get
```

### 4. Run it
Start an Android emulator (or plug in a phone with USB debugging on), then:
```bash
flutter run
```
Or run it in the browser:
```bash
flutter run -d chrome
```
In demo mode, any non-empty email and password will log you in.

### 5. (Optional) Connect to the real backend
1. Start the backend: `cd app/backend && npm install && node server.js` (it runs on port 5001).
2. In `lib/services/api_service.dart`, set `baseUrl`:
   - Android emulator: `http://10.0.2.2:5001/api` (default)
   - Chrome / iOS simulator: `http://localhost:5001/api`
   - Real phone: `http://<your-PC-LAN-IP>:5001/api`

### 6. (Optional) Turn on face attendance
1. Start the face service: see [face-recognition/README.md](../../face-recognition/README.md) (runs on port 8000).
2. Set `baseUrl` in `lib/services/face_service.dart` the same way as above, but with port `8000`.
3. After `flutter create .`, add these platform settings:
   - **Android** (`android/app/src/main/AndroidManifest.xml`): add `android:usesCleartextTraffic="true"` to `<application>`.
     This allows plain-HTTP calls to your local servers.
   - **iOS** (`ios/Runner/Info.plist`): add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`
     with a short reason, for example "Used to capture cadet attendance".

## Opening in an IDE
- **VS Code:** File → Open Folder → `mobile/ncc_attendance_app`, then press F5.
- **Android Studio:** File → Open → `mobile/ncc_attendance_app`, then click ▶ Run.
