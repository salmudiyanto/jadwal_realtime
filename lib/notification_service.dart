import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);
  }


  static Future<void> showTestNotification() async {
    await _notifications.show(
      999, // ID unik untuk notifikasi tes
      '🎉 Tes Notifikasi Berhasil!',
      'Ini adalah contoh notifikasi dari aplikasi Jadwal Anda',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Channel Tes',
          channelDescription: 'Channel untuk notifikasi tes',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Colors.green,
        ),
      ),
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try{
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime.from(scheduledTime, tz.local);

      if (scheduled.isBefore(now)) {
        scheduled = now.add(const Duration(seconds: 10)); // jadwalkan 10 detik ke depan
      }
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'schedule_channel',
            'Jadwal Reminder',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        // androidAllowWhileIdle: true,
        // uiLocalNotificationDateInterpretation:
        // UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }on PlatformException catch (e){
      if (e.code == 'exact_alarms_not_permitted') {
        // Fallback ke notifikasi tidak tepat waktu
        await _notifications.show(
          id,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id', // Wajib unik
              'Nama Channel', // Ditampilkan di pengaturan notifikasi user
              channelDescription: 'Deskripsi Channel',
              importance: Importance.max, // Prioritas tinggi
              priority: Priority.high, // Tampilkan di atas notifikasi lain
              icon: '@mipmap/ic_launcher', // Icon default
              color: Colors.blue, // Warna accent
              enableVibration: true,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'), // File di /res/raw/
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Icon besar
              styleInformation: BigTextStyleInformation(''), // Notifikasi expanded
              autoCancel: true, // Hilang saat diklik
              ongoing: false, // Tidak sticky
              showWhen: true, // Tampilkan waktu
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true, // Tampilkan alert
              presentBadge: true, // Tampilkan badge
              presentSound: true,
              sound: 'default', // atau nama file custom
              badgeNumber: 1,
              threadIdentifier: 'thread-id',
            ),
          ),
        );
      }
    }

  }
}