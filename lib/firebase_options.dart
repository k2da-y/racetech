// File generated from android/app/google-services.json.
// Run `flutterfire configure` to regenerate this file when Firebase apps change.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have only been configured for Android.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-5K4QFmIGjYYlyWWBRqXiavJ6E04W9IA',
    appId: '1:669775311994:android:c4adbabc8e925ed7a477c3',
    messagingSenderId: '669775311994',
    projectId: 'conquer-51741',
    storageBucket: 'conquer-51741.firebasestorage.app',
  );
}
