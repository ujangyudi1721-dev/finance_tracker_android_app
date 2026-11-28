
import 'package:flutter/material.dart';

import '../services/household_service.dart';

/// Halaman untuk Owner menambahkan anggota rumah tangga.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  // Mengontrol kolom email anggota.
  final TextEditingController _emailController = TextEditingController();

  // Menandai apakah proses penambahan sedang berlangsung.
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Menambahkan akun yang sudah terdaftar sebagai Member.
  Future<void> _addMember() async {
    final email = _emailController.text.trim();

    // Memeriksa apakah email sudah diisi.
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan alamat email yang valid.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Memanggil fungsi RPC Supabase untuk menambahkan anggota.
      await HouseholdService.addHouseholdMember(email: email);

      if (!mounted) return;

      _emailController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anggota berhasil ditambahkan sebagai Member.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan anggota: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggota Rumah Tangga'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.family_restroom,
            size: 64,
            color: Colors.teal,
          ),
          const SizedBox(height: 12),

          Text(
            'Kelola Anggota Keluarga',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          const Text(
            'Tambahkan akun keluarga yang sudah terdaftar '
            'di Finance Tracker. Anggota yang ditambahkan '
            'akan menggunakan data keuangan rumah tangga yang sama.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          const Text(
            'Email Anggota',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'contoh@email.com',
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _addMember,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(
                _isLoading ? 'Menambahkan...' : 'Tambah Anggota',
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.teal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pastikan email anggota sudah terdaftar '
                      'dan akun tersebut sudah dikonfirmasi. '
                      'Akun yang ditambahkan akan mendapatkan '
                      'peran Member.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
