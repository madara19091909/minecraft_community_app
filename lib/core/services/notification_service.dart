import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class McNotificationService {
  McNotificationService._();
  static final McNotificationService instance = McNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@drawable/mcc_icon');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'mc_messages',
        'mcc Messages',
        description: 'New messages and important mcc activity.',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'mc_social',
        'mcc Social',
        description: 'Likes, follows, comments and other mcc activity.',
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required bool message,
  }) async {
    await initialize();
    final channelId = message ? 'mc_messages' : 'mc_social';
    final channelName = message ? 'mcc Messages' : 'mcc Social';
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: message
              ? 'New messages and important mcc activity.'
              : 'Likes, follows, comments and other mcc activity.',
          importance: message ? Importance.max : Importance.high,
          priority: message ? Priority.max : Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: title,
        ),
      ),
    );
  }
}
