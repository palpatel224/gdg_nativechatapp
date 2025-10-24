# GDG Native Chat App 💬

A feature-rich real-time chat application built with Flutter and Firebase, showcasing modern mobile development practices with BLoC state management.

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-blue)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 🎥 Demo Video

**Watch the full demo:** [YouTube Demo](https://youtu.be/8Cg2CdFLFIo)

## ✨ Features

### 🔐 Authentication

- Email/Password authentication with Firebase Auth
- User profile creation and management
- Profile photo upload to Firebase Storage
- Custom status messages

### 💬 Real-Time Messaging

- Instant one-on-one messaging with Cloud Firestore
- Message delivery status (Sent ✓, Delivered ✓✓, Read ✓✓)
- Real-time typing indicators
- Message timestamps with smart formatting
- Pull-to-refresh chat list

### 📍 Location Features

- Live location sharing with continuous updates
- Interactive Google Maps integration
- Static map previews in chat
- Start/stop location sharing controls

### 🟢 User Presence

- Real-time online/offline status
- Last seen timestamps
- Dual presence tracking (Firestore + Realtime Database)
- Automatic status updates on app lifecycle changes

### 🔔 Push Notifications

- Firebase Cloud Messaging (FCM) integration
- Foreground and background notifications
- Notification tap handling with deep linking
- Multi-device token management

### 🎨 Modern UI/UX

- Material Design 3 principles
- Custom theming with Google Fonts
- Smooth animations and transitions
- Cached network images for performance
- Responsive layouts

## 🛠️ Tech Stack

**Frontend**

- Flutter 3.9.2+ / Dart
- BLoC Pattern (flutter_bloc) for state management
- Clean Architecture with Repository Pattern

**Backend & Services**

- Firebase Auth (Authentication)
- Cloud Firestore (Real-time database)
- Firebase Storage (File storage)
- Firebase Realtime Database (Presence system)
- Firebase Cloud Messaging (Push notifications)

**Maps & Location**

- Google Maps Flutter
- Geolocator

**UI & Assets**

- Material Design
- Google Fonts
- Cached Network Image
- Flutter SVG

## 📋 Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK (included with Flutter)
- Android Studio or Xcode
- Firebase account
- Google Cloud account (for Maps API)
- Git

## 🚀 Quick Setup

### 1. Clone Repository

```bash
git clone https://github.com/palpatel224/gdg_nativechatapp.git
cd gdg_nativechatapp
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android and/or iOS apps to your Firebase project
3. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
4. Run FlutterFire CLI:

```bash
flutterfire configure
```

5. Enable Firebase services:
   - **Authentication**: Email/Password provider
   - **Firestore Database**: Start in production mode
   - **Realtime Database**: Enable
   - **Storage**: Enable
   - **Cloud Messaging**: Enable

### 4. Environment Variables

Create a `.env` file in the project root:

```env
GOOGLE_API_KEY=your_google_maps_api_key_here
```

### 5. Google Maps API

1. Get API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Maps SDK for Android/iOS
3. Add to Android (`android/app/src/main/AndroidManifest.xml`):

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

4. Add to iOS (`ios/Runner/AppDelegate.swift`):

```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

### 6. Firestore Security Rules

Add these rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /chats/{chatId} {
      allow read, write: if request.auth != null &&
        request.auth.uid in resource.data.participants;
    }
    match /chats/{chatId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 7. Run the App

```bash
# Check connected devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios

# Release build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 📁 Project Structure

```
lib/
├── main.dart                   # App entry point
├── firebase_options.dart       # Firebase configuration
├── blocs/                      # State management
│   ├── auth/                   # Authentication BLoC
│   ├── chat/                   # Chat functionality BLoC
│   ├── home/                   # Home screen BLoC
│   └── map/                    # Maps BLoC
├── services/                   # Business logic layer
│   ├── auth_service.dart
│   ├── chat_service.dart
│   ├── notification_service.dart
│   ├── presence_service.dart
│   ├── profile_service.dart
│   └── typing_service.dart
├── repositories/               # Data layer
│   ├── auth_repository.dart
│   └── chat_repository.dart
├── models/                     # Data models
│   ├── user_model.dart
│   ├── chat_model.dart
│   └── message_model.dart
├── pages/                      # UI screens
│   ├── auth/                   # Login & Signup
│   ├── chat/                   # Chat & Map screens
│   ├── home/                   # Chat list
│   ├── profile/                # Profile editing
│   └── main_page.dart          # Main navigation
├── widgets/                    # Reusable components
├── theme/                      # App theming
└── config/                     # Configuration files

android/                        # Android native code
ios/                           # iOS native code
assets/                        # Images & icons
```

## 🔑 Key Dependencies

```yaml
# State Management
flutter_bloc: ^8.1.6
equatable: ^2.0.5

# Firebase
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
firebase_storage: ^12.3.4
firebase_database: ^11.0.0
firebase_messaging: ^15.2.10

# Maps & Location
google_maps_flutter: ^2.10.0
geolocator: ^13.0.2

# UI & Utils
google_fonts: ^6.2.1
cached_network_image: ^3.4.1
image_picker: ^1.1.2
flutter_dotenv: ^5.1.0
intl: ^0.19.0
```

## 💡 Key Features Implementation

### Message Status Tracking

Messages show three distinct states:

- **Sent (✓)**: Delivered to server
- **Delivered (✓✓)**: Received on recipient device
- **Read (✓✓)**: Viewed in chat (blue ticks)

### Live Location Sharing

- Continuous GPS updates via Geolocator
- Real-time Firestore sync
- Google Maps display with custom markers
- Automatic cleanup on stop

### Typing Indicators

- Real-time status updates in Firestore
- Debounced for performance
- Visual feedback with animated dots

### User Presence System

- Dual database tracking (Firestore + RTDB)
- App lifecycle monitoring
- Automatic online/offline updates
- Last seen timestamps

## 🔒 Security

- ✅ `.env` file in `.gitignore` (never commit secrets)
- ✅ Firebase Security Rules implemented
- ✅ Environment variables for API keys
- ✅ Firestore access control by user authentication
- ✅ Token-based FCM authentication

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [BLoC Library](https://bloclibrary.dev/)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)

## 👨‍💻 Author

**Pal Patel**

- GitHub: [@palpatel224](https://github.com/palpatel224)
- Project: GDG Native Chat App
