import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      default: return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDtuxahEVj78OTSIZKaa6z8Q69CNWymO78',
    appId: '1:708576389273:web:15dce7b898db575097f008',
    messagingSenderId: '708576389273',
    projectId: 'servis360-15b4a',
    authDomain: 'servis360-15b4a.firebaseapp.com',
    storageBucket: 'servis360-15b4a.firebasestorage.app',
    measurementId: 'G-FMH5TW36HL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBX-9HFavvc7PvH7MuM22Xd9ymJSeWDdSo',
    appId: '1:708576389273:android:ANDROID_APP_ID',
    messagingSenderId: '708576389273',
    projectId: 'servis360-15b4a',
    storageBucket: 'servis360-15b4a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBX-9HFavvc7PvH7MuM22Xd9ymJSeWDdSo',
    appId: '1:708576389273:ios:IOS_APP_ID',
    messagingSenderId: '708576389273',
    projectId: 'servis360-15b4a',
    storageBucket: 'servis360-15b4a.firebasestorage.app',
  );
}
