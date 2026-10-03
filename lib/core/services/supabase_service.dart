import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class McNotificationService {
  McNotificationService._();
  static final McNotificationService instance = McNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'mc_messages',
        'MC Messages',
        description: 'New messages and important MC activity.',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'mc_social',
        'MC Social',
        description: 'Likes, follows, comments and other activity.',
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
    final channelName = message ? 'MC Messages' : 'MC Social';
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: message
              ? 'New messages and important MC activity.'
              : 'Likes, follows, comments and other activity.',
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
