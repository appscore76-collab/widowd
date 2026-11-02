// firebase_messaging 17 deprecated getToken/onTokenRefresh/deleteToken in favour
// of register()/onRegistered, which return a Firebase Installation ID. We
// deliberately keep the FCM registration token here: it's what the standard FCM
// server API (and our Edge Functions) send to, and what device_tokens stores.
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../members/members_repository.dart';

/// Public Web Push (VAPID) key for the widowd-dev web app, from the Firebase
/// console → Cloud Messaging → Web Push certificates. Public, not a secret.
const webPushVapidKey =
    'BFgnX0vUczQivmWPu2UfxkdQhB3Zekg5kS3QgKfxp8C5vvR_mEc_wQGSUYXs9FxxsYZqbW4IUM5FqZyLtVPILGA';

/// Registers this device for push and keeps its FCM token saved in Supabase
/// so Edge Functions can reach the member. Every call is best-effort: push is
/// never allowed to break sign-in or the app, and it no-ops when Firebase
/// isn't initialised (e.g. in tests).
class PushService {
  PushService(this._repository);

  final MembersRepository _repository;
  StreamSubscription<String>? _refreshSub;

  bool get _available => Firebase.apps.isNotEmpty;

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => kIsWeb ? 'web' : 'other',
  };

  String get platform => kIsWeb ? 'web' : _platform;

  /// Asks for notification permission (if [requestPermission]) and saves the
  /// token for the signed-in member. Call after sign-up / sign-in (a user
  /// gesture, which web push requires), and on app start for signed-in members.
  Future<void> registerForCurrentUser({bool requestPermission = false}) async {
    if (!_available) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (requestPermission) {
        await messaging.requestPermission();
      }
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? webPushVapidKey : null,
      );
      if (token != null) await _save(token);

      // A device's token can rotate; keep the saved one current.
      _refreshSub ??= messaging.onTokenRefresh.listen(_save);
    } catch (error, stack) {
      debugPrint('Push registration failed: $error\n$stack');
    }
  }

  Future<void> _save(String token) =>
      _repository.saveDeviceToken(token: token, platform: platform);

  /// Removes this device's token on sign-out so it stops receiving pushes.
  Future<void> unregister() async {
    if (!_available) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? webPushVapidKey : null,
      );
      if (token != null) await _repository.deleteDeviceToken(token);
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('Push unregister failed: $error');
    }
  }

  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}

/// Handles a push that arrives while a native app is in the background or
/// terminated. Must be a top-level function. The web uses
/// `web/firebase-messaging-sw.js` instead.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do yet — the system shows the notification. A richer handler
  // (data messages, badges) can go here later.
}
