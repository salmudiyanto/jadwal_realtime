import 'package:jadwal_realtime/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <- gunakan ini
import 'package:firebase_core/firebase_core.dart';     // <- jangan lupa ini

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Inisialisasi Firebase
      await Firebase.initializeApp();

      // 2. Ambil waktu sekarang (dengan toleransi ±1 menit)
      final now = DateTime.now();
      final startTime = now.subtract(Duration(minutes: 1));
      final endTime = now.add(Duration(minutes: 1));

      // 3. Query jadwal yang jatuh tempo
      final schedules = await FirebaseFirestore.instance
          .collection('schedules')
          .where('datetime', isLessThanOrEqualTo: now)
          .where('isNotified', isEqualTo: false)
          .get();

      // 4. Trigger notifikasi
      for (final doc in schedules.docs) {
        final data = doc.data();
        await NotificationService.scheduleNotification(
          id: doc.id.hashCode,
          title: '⏰ ${data['title']}',
          body: data['description'] ?? 'Waktu jadwal telah tiba',
          scheduledTime: DateTime.now().add(Duration(seconds: 1)), // Tampilkan segera
        );

        // 5. Tandai sudah dikirim
        await doc.reference.update({'isNotified': true});
      }

      return true; // Return true = task sukses
    } catch (e) {
      print('Background task error: $e');
      return false; // Return false = task gagal
    }
  });
}

Future<void> _checkSchedules() async {
  final now = DateTime.now();
  print('mungkin object');
  // Mencari dokumen yang datetime-nya sama persis dengan sekarang
  final schedules = await FirebaseFirestore.instance
      .collection('schedules')
      .where('datetime', isEqualTo: Timestamp.fromDate(now)) // pastikan cocok formatnya
      .get();

  for (final doc in schedules.docs) {
    await NotificationService.scheduleNotification(
      id: doc.id.hashCode,
      title: 'Jadwal: ${doc['title']}',
      body: 'Waktunya untuk: ${doc['description']}',
      scheduledTime: now.add(Duration(seconds: 5)),
    );
  }
}
