import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jadwal_realtime/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:jadwal_realtime/background_service.dart';
import 'package:permission_handler/permission_handler.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _requestExactAlarmPermission() async {
    try{
      print("oioi");
      if (await Permission.scheduleExactAlarm.request().isGranted) {
        print('Izin exact alarm diberikan');
      } else {
        print('Izin ditolak, notifikasi mungkin tidak tepat waktu');
      }
    }catch(e){
      print("error minta izin $e");
    }
  }

  // Future<void> _testNotification() async {
  //   await NotificationService.showTestNotification();
  // }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // _testNotification();
    _requestExactAlarmPermission;
    _initNotifications();
    _startBackgroundTask();
  }

  Future<void> _initNotifications() async {
    await NotificationService.initialize();

    // Cek jadwal setiap kali app dibuka
    _checkImmediateSchedules();
  }

  // final schedules = await FirebaseFirestore.instance
  //     .collection('schedules')
  //     .where('datetime', isLessThanOrEqualTo: now)
  //     .where('isNotified', isEqualTo: false)
  //     .get();

  Future<void> _checkImmediateSchedules() async {
    final now = DateTime.now();
    final schedules = await FirebaseFirestore.instance
        .collection('schedules')
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where('datetime', isLessThanOrEqualTo: now)
        .where('isNotified', isEqualTo: false)
        .get();
    for (final doc in schedules.docs) {
      NotificationService.tampilNotifikasi(
        id: doc.id.hashCode,
        title: 'Jadwal Sekarang : ${doc['title']}',
        body: doc['description'],
      );
      // NotificationService.scheduleNotification(
      //   id: doc.id.hashCode,
      //   title: 'Jadwal Sekarang: ${doc['title']}',
      //   body: doc['description'],
      //   scheduledTime: now,
      // );
    }
  }

  void _startBackgroundTask() {
    try{
      Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      Workmanager().registerPeriodicTask(
        'schedule-checker',
        'checkSchedules',
        frequency: Duration(minutes: 15),  // Cek setiap 15 menit
      );
      print("jalanji");
    }on PlatformException catch(e){
      print("Task Gagal : ${e.message}");
    }
  }



  Future<void> _addSchedule() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null) return;

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await FirebaseFirestore.instance.collection('schedules').add({
      'title': _titleController.text,
      'description': _descController.text,
      'datetime': dateTime,
      'userId': _user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isCompleted': false,
      'isNotified' : false,
    });

    await NotificationService.scheduleNotification(
      id: dateTime.hashCode, // ID unik berdasarkan waktu
      title: '⏰ ${_titleController.text}',
      body: _descController.text.isNotEmpty
          ? _descController.text
          : 'Jadwal dimulai pada ${DateFormat('HH:mm').format(dateTime)}',
      scheduledTime: dateTime,
    );

    _titleController.clear();
    _descController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }

    print(_selectedDate);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _toggleComplete(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(docId)
        .update({'isCompleted': !currentStatus, 'isNotified': true});
  }

  Future<void> _deleteSchedule(String docId) async {
    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddScheduleDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: _user?.uid)
            .orderBy('datetime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada jadwal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text('Tap + untuk menambahkan'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateTime = (data['datetime'] as Timestamp).toDate();
              final isCompleted = data['isCompleted'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isCompleted ? Colors.grey[200] : null,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      DateFormat('dd').format(dateTime),
                      style: TextStyle(
                        color: isCompleted ? Colors.grey : Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(
                    data['title'],
                    style: TextStyle(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description'] ?? ''),
                      Text(
                        DateFormat('EEEE, dd MMM y • HH:mm').format(dateTime),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isCompleted
                              ? Icons.undo
                              : Icons.check_circle,
                          color: isCompleted ? Colors.grey : Colors.green,
                        ),
                        onPressed: () => _toggleComplete(doc.id, isCompleted),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSchedule(doc.id),
                      ),
                    ],
                  ),
                  onTap: () => _showEditDialog(context, doc.id, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Jadwal'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Harap isi judul';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(
                          _selectedDate == null
                              ? 'Pilih Tanggal'
                              : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(
                          _selectedTime == null
                              ? 'Pilih Waktu'
                              : _selectedTime!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: _addSchedule,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      ) {
    final dateTime = (data['datetime'] as Timestamp).toDate();
    _titleController.text = data['title'];
    _descController.text = data['description'] ?? '';
    _selectedDate = dateTime;
    _selectedTime = TimeOfDay.fromDateTime(dateTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Jadwal'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Harap isi judul';
                    }
                    return null;
                  },
                ),
                // ... (field lainnya sama seperti di _showAddScheduleDialog)
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;

              await FirebaseFirestore.instance
                  .collection('schedules')
                  .doc(docId)
                  .update({
                'title': _titleController.text,
                'description': _descController.text,
                'datetime': DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedTime!.hour,
                  _selectedTime!.minute,
                ),
              });

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}