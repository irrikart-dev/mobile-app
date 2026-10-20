import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_data.dart';
import '../../models/order_data.dart';
import '../../route/app_links.dart';
import '../../route/route_constants.dart';
import '../../route/route_tracker.dart';

final pushServiceProvider = Provider<PushService>(PushService.new);

/// FCM for the signed-in user: registers this device's token with
/// `POST /notifications/devices`, keeps it fresh, and routes taps.
///
/// Everything here is best-effort — a device that can't get a token (no
/// Play services, permission denied, APNs not set up) just goes without
/// pushes; the in-app notification centre still works.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _tapsWired = false;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// Call once a user is signed in.
  Future<void> start() async {
    try {
      _wireTaps();
      await _fcm.requestPermission();
      final token = await _fcm.getToken();
      if (token != null) await _register(token);
      for (final s in _subs) {
        await s.cancel();
      }
      _subs
        ..clear()
        ..add(_fcm.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen(_onForeground));
    } catch (e) {
      debugPrint('IrriKart: push unavailable — $e');
    }
  }

  /// Call **before** signing out, while the request can still authenticate.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _ref.read(notificationsRepositoryProvider).removeDevice(token);
      }
    } catch (e) {
      debugPrint('IrriKart: could not unregister push token — $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _ref
          .read(notificationsRepositoryProvider)
          .registerDevice(token, Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('IrriKart: could not register push token — $e');
    }
  }

  /// Taps that open the app — from the background, or from cold start.
  void _wireTaps() {
    if (_tapsWired) return;
    _tapsWired = true;
    FirebaseMessaging.onMessageOpenedApp.listen((m) => openPushTarget(m.data));
    unawaited(
      _fcm.getInitialMessage().then((m) {
        if (m != null) openPushTarget(m.data);
      }),
    );
  }

  /// FCM shows nothing itself while the app is open, so surface it in-app.
  void _onForeground(RemoteMessage message) {
    _ref.invalidate(unreadNotificationsProvider);
    final orderId = message.data['orderId'];
    if (orderId is String) _ref.invalidate(orderDetailProvider(orderId));
    final context = rootNavigatorKey.currentContext;
    final title = message.notification?.title;
    if (context == null || title == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(title),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => openPushTarget(message.data),
        ),
      ),
    );
  }

  /// Routes a push (or notification-centre row) by its `data`: an order,
  /// a campaign link, or else the centre itself.
  void openPushTarget(Map<String, dynamic> data) {
    _ref.invalidate(unreadNotificationsProvider);
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    openNotificationTarget(context, data);
  }
}

/// Shared by pushes and the notification centre.
void openNotificationTarget(BuildContext context, Map<String, dynamic> data) {
  final orderId = data['orderId'];
  final link = data['link'];
  if (orderId is String && orderId.isNotEmpty) {
    Navigator.of(context)
        .pushNamed(orderDetailsScreenRoute, arguments: orderId);
  } else if (link is String && link.isNotEmpty) {
    unawaited(openAppLink(context, link));
  } else if (ModalRoute.of(context)?.settings.name !=
      notificationsScreenRoute) {
    Navigator.of(context).pushNamed(notificationsScreenRoute);
  }
}
