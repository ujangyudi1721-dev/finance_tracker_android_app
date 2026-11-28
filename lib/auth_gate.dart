
import 'package:flutter/material.dart';

import 'household_gate.dart';
import 'pages/auth_page.dart';
import 'services/auth_service.dart';

/// Menentukan apakah pengguna harus login
/// atau dapat melanjutkan ke aplikasi.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Mendengarkan perubahan status autentikasi Supabase.
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Memeriksa apakah pengguna sudah login.
        final user = AuthService.currentUser;

        if (user == null) {
          return const AuthPage();
        }

        // Pengguna sudah login, lanjutkan pemeriksaan rumah tangga.
        return const HouseholdGate();
      },
    );
  }
}
