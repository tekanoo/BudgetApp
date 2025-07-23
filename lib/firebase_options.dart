import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCM5iOOTWQJgXbSd0Mb6LzAsfw3l2l_2r4', // Récupérez depuis Firebase Console
    appId: '1:320883807207:web:a55f66b507d34724d9e342', // Format: 1:320883807207:web:...
    messagingSenderId: '320883807207',
    projectId: 'budget-app-26741',
    authDomain: 'budget-app-26741.firebaseapp.com',
    storageBucket: 'budget-app-26741.firebasestorage.app',
  );

  // Vous pouvez garder les autres plateformes pour plus tard
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIU3gJwizb5mc3ida_nmVLk2_-VhJ17kc',
    appId: '1:320883807207:android:d90aa3515557e7b9d9e342',
    messagingSenderId: '320883807207',
    projectId: 'budget-app-26741',
    storageBucket: 'budget-app-26741.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your-ios-api-key',
    appId: 'your-ios-app-id',
    messagingSenderId: '320883807207',
    projectId: 'budget-app-26741',
    storageBucket: 'budget-app-26741.firebasestorage.app',
    iosClientId: 'your-ios-client-id',
    iosBundleId: 'com.example.budgetApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'your-macos-api-key',
    appId: 'your-macos-app-id',
    messagingSenderId: '320883807207',
    projectId: 'budget-app-26741',
    storageBucket: 'budget-app-26741.firebasestorage.app',
    iosClientId: 'your-macos-client-id',
    iosBundleId: 'com.example.budgetApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'your-windows-api-key',
    appId: 'your-windows-app-id',
    messagingSenderId: '320883807207',
    projectId: 'budget-app-26741',
    storageBucket: 'budget-app-26741.firebasestorage.app',
  );
}