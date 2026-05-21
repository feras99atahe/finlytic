// Generated from google-services.json for project wallet-tracker-40296
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not configured.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCJ9BkW94sP4OD6iv3Z_FxQRTMcAq6gShk',
    appId: '1:250653096987:android:b7f678418de0f46872ccbe',
    messagingSenderId: '250653096987',
    projectId: 'wallet-tracker-40296',
    storageBucket: 'wallet-tracker-40296.firebasestorage.app',
  );
}
