// Firebase configuration for the widowd app, per platform.
//
// These are the Firebase *client* identifiers for the `widowd-dev` project —
// not secrets. The same values ship inside android/app/google-services.json
// and ios/Runner/GoogleService-Info.plist, so this file is committed. Secrets
// (server keys, service accounts) never go here; see CLAUDE.md.
//
// Hand-written to mirror `flutterfire configure`. If the Firebase apps change,
// regenerate from the Firebase console / the native config files.
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is only configured for web, Android and iOS. '
          'defaultTargetPlatform $defaultTargetPlatform is not supported.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpMHPEWhNJ1CwD2KhB6K_XGdutyJRcmxs',
    appId: '1:747251750497:web:7f126fda53735e8d133c20',
    messagingSenderId: '747251750497',
    projectId: 'widowd-dev',
    authDomain: 'widowd-dev.firebaseapp.com',
    storageBucket: 'widowd-dev.firebasestorage.app',
    measurementId: 'G-VFE5G7SQ3J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGZ9cqKmqsNfbKlTAjnHPO0DXUMRIK58I',
    appId: '1:747251750497:android:812468fe5c121756133c20',
    messagingSenderId: '747251750497',
    projectId: 'widowd-dev',
    storageBucket: 'widowd-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCAXYXcmwxvo0fhOVVzZPGgpW_I5vIUBeI',
    appId: '1:747251750497:ios:01d9196c70425fef133c20',
    messagingSenderId: '747251750497',
    projectId: 'widowd-dev',
    storageBucket: 'widowd-dev.firebasestorage.app',
    iosBundleId: 'com.scoreconsultancy.widowd',
  );
}
