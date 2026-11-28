
import 'package:flutter/material.dart';

import 'pages/main_shell.dart';
import 'services/household_service.dart';
import 'services/auth_service.dart';

/// Memeriksa apakah pengguna sudah memiliki rumah tangga.
///
/// Jika belum, pengguna diarahkan untuk membuat rumah tangga.
/// Jika sudah, aplikasi membuka halaman utama.
class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key});

  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  // Controller untuk nama rumah tangga.
  final TextEditingController _nameController =
      TextEditingController();

  // Menyimpan proses pemeriksaan rumah tangga.
  late Future<Map<String, dynamic>?> _householdFuture;

  // Mengontrol proses pembuatan rumah tangga.
  bool _isCreating = false;

  // Mengontrol proses logout.
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    // Memeriksa rumah tangga ketika halaman pertama dibuka.
    _householdFuture = HouseholdService.getMyHousehold();
  }

  /// Mengeluarkan pengguna dari aplikasi.
  ///
  /// Setelah logout, AuthGate akan mengarahkan pengguna
  /// kembali ke halaman Login.
  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService.signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  /// Membuat rumah tangga baru untuk akun yang sedang login.
  Future<void> _createHousehold() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama rumah tangga wajib diisi.'),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Database otomatis menetapkan pengguna sebagai Owner.
      await HouseholdService.createHousehold(name: name);

      if (!mounted) return;

      // Memeriksa kembali rumah tangga yang baru dibuat.
      setState(() {
        _householdFuture = HouseholdService.getMyHousehold();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rumah tangga berhasil dibuat.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat rumah tangga: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  /// Mengulangi pemeriksaan jika terjadi kesalahan.
  void _retry() {
    setState(() {
      _householdFuture = HouseholdService.getMyHousehold();
    });
  }

  /// Membuat tombol Logout pada AppBar.
  Widget _logoutButton() {
    return IconButton(
      tooltip: 'Logout',
      onPressed: _isLoggingOut ? null : _logout,
      icon: _isLoggingOut
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _householdFuture,
      builder: (context, snapshot) {
        // Menampilkan loading ketika memeriksa database.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rumah Tangga'),
              actions: [_logoutButton()],
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Menampilkan pesan jika pemeriksaan gagal.
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rumah Tangga'),
              actions: [_logoutButton()],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal memeriksa data rumah tangga.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final household = snapshot.data;

        // Jika sudah memiliki rumah tangga, buka halaman utama.
        if (household != null) {
          return const MainShell();
        }

        // Jika belum memiliki rumah tangga, tampilkan halaman setup.
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pengaturan Rumah Tangga'),
            actions: [_logoutButton()],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        size: 76,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Selamat Datang!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Buat rumah tangga keuangan Anda untuk '
                        'mengelola transaksi dan aset keluarga '
                        'bersama anggota lainnya.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Rumah Tangga',
                          hintText: 'Contoh: Keluarga Ujang',
                          prefixIcon: Icon(Icons.home_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            _isCreating ? null : _createHousehold,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Buat Rumah Tangga'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Akun Anda akan otomatis menjadi Owner '
                        'atau pemilik utama rumah tangga.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
