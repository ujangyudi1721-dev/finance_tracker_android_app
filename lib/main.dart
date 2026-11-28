
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'auth_gate.dart';

/// Titik awal aplikasi Finance Tracker.
Future<void> main() async {
  // Memastikan Flutter siap sebelum menjalankan kode asynchronous.
  WidgetsFlutterBinding.ensureInitialized();

  // Memeriksa apakah konfigurasi Supabase tersedia.
  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  // Menginisialisasi koneksi Supabase.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Menjalankan aplikasi utama.
  runApp(const MyApp());
}

/// Widget utama aplikasi.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finance Tracker',

      // Mengatur tema visual aplikasi.
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),

      // AuthGate menentukan halaman berdasarkan status login.
      home: const AuthGate(),
    );
  }
}

/// Halaman yang ditampilkan jika konfigurasi Supabase kosong.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SUPABASE_URL / SUPABASE_ANON_KEY kosong.\n'
              'Jalankan aplikasi dengan --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
