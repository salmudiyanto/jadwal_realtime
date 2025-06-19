import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:jadwal_realtime/auth_wrapper.dart';
import 'package:jadwal_realtime/register_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadwal Realtime',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
    ),
    ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/register' : (context) => const RegisterScreen(),
      },
    );
  }
}
