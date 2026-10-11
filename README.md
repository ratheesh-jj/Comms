







VERY IMPORTANT FOR NEXT WORKING TIME:::::
    MAKE THE VIDEO AND AUDIO CALL IN THE SAME STREAM
    TO PREVENT  AUDIO VS VIDEO CALL FIGHTING ISSUES
    IF U DONT REMEMBER THE ISSUE, TRY RUNNING 2 EMULATORS
    AND JOIN THEM IN THE SAME ROOM WHERE ONE IS IN VIDEO CALL
    AND THE OTHER IS IN AUDIO CALL.
















# Flutter WebRTC Calling App

A minimal, cross-platform (iOS + Android) Flutter application for one-to-one voice and video calling using WebRTC. This project includes a Dart-based signalling server using `shelf` and WebSockets.

## Features
- **One-to-One Calling**: Voice and Video support.
- **Cross-Platform**: iOS and Android.
- **Minimal UI**: Strict Black/Grey/White palette.
- **Signalling Server**: Dart-based WebSocket server.
- **Clean Architecture**: Separation of Signalling and WebRTC services.

## Prerequisites
- Flutter SDK (Latest Stable)
- Dart SDK
- Android Emulator or Physical Device
- iOS Simulator or Physical Device (Mac only)

## Project Structure
- `lib/`: Flutter application code.
- `server/`: Dart signalling server.
- `android/` & `ios/`: Native configuration.

## Setup & Running

### 1. Signalling Server
The app requires the signalling server to be running first.

```bash
cd server
dart pub get
dart bin/server.dart
```
Server runs on port `8080`.

**Note for Android Emulator**: The emulator can access the host machine's localhost via `10.0.2.2`. The app is configured to use `ws://10.0.2.2:8080` by default. If running on a real device, replace this with your machine's local IP address (e.g., `ws://192.168.1.5:8080`) in `lib/screens/home_screen.dart`.

### 2. Flutter App
```bash
flutter pub get
flutter run
```

## Testing
### Unit Tests
```bash
flutter test
```

### Manual Testing
1. Start the server.
2. Launch App Instance A (Simulator/Emulator 1).
3. Launch App Instance B (Simulator/Emulator 2).
4. Enter the same **Room ID** on both devices.
5. Tap **Start Video Call** on one device.
6. Check for video/audio connection.

## Configuration
### Android Permissions
Permissions are configured in `android/app/src/main/AndroidManifest.xml`.
- Camera
- Microphone
- Internet

### iOS Permissions
Permissions are configured in `ios/Runner/Info.plist`.
- NSCameraUsageDescription
- NSMicrophoneUsageDescription

### STUN/TURN
The app uses Google's public STUN server by default. To add a TURN server for relaying media behind restrictive NATs, modify `lib/services/webrtc_service.dart` or pass through `.env` vars (implementation ready for expansion).

## Native Integration Notes
### CallKit (iOS) & Foreground Service (Android)
For production apps, you must integrate:
- **iOS**: `flutter_callkit_incoming` for native incoming call UI. Add `PushKit` capability in Xcode.
- **Android**: `flutter_foreground_task` or `audio_service` to keep the microphone active in background. Add `FOREGROUND_SERVICE` permission.

This reference implementation focuses on the active foreground experience.
