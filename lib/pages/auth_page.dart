
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Halaman untuk login dan registrasi pengguna.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Controller untuk membaca email dan password.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  // Menentukan mode halaman: login atau registrasi.
  bool _isRegister = false;

  // Mengontrol tampilan password.
  bool _obscurePassword = true;

  // Mencegah tombol ditekan berulang kali.
  bool _isLoading = false;

  // Menentukan apakah email konfirmasi perlu dikirim ulang.
  bool _showResendButton = false;

  /// Menampilkan pesan kepada pengguna.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Memproses login atau registrasi.
  Future<void> _submit() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validasi email dan password.
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi.');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Format email tidak valid.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Password minimal 6 karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegister) {
        // Membuat akun baru dengan alamat Deep Link.
        final response = await AuthService.signUp(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (response.session == null) {
          // Email perlu dikonfirmasi sebelum login.
          setState(() {
            _showResendButton = true;
          });

          _showMessage(
            'Registrasi berhasil. Silakan periksa email Anda.',
          );
        } else {
          setState(() {
            _showResendButton = false;
          });

          _showMessage('Registrasi berhasil.');
        }
      } else {
        // Login menggunakan email dan password.
        await AuthService.signIn(
          email: email,
          password: password,
        );

        if (!mounted) return;

        _showMessage('Login berhasil.');
      }
    } catch (error) {
      _showMessage('Terjadi kesalahan: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Mengirim ulang email konfirmasi.
  Future<void> _resendConfirmation() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Masukkan alamat email yang valid.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.resendSignupConfirmation(
        email: email,
      );

      if (!mounted) return;

      _showMessage(
        'Email konfirmasi berhasil diminta. Silakan periksa inbox Anda.',
      );
    } catch (error) {
      _showMessage('Gagal mengirim email konfirmasi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Membersihkan controller untuk mencegah memory leak.
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // Logo aplikasi.
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 72,
                    color: Colors.teal,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Finance Tracker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _isRegister
                        ? 'Buat akun keuangan keluarga'
                        : 'Silakan login ke akun Anda',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 32),

                  // Input email.
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Input password.
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol login atau registrasi.
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isRegister ? 'Daftar Akun' : 'Login',
                          ),
                  ),

                  // Tombol kirim ulang email konfirmasi.
                  if (_showResendButton) ...[
                    const SizedBox(height: 12),

                    const Text(
                      'Belum menerima email konfirmasi atau tautan lama bermasalah?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : _resendConfirmation,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Kirim Ulang Email Konfirmasi'),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Berpindah antara mode login dan registrasi.
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isRegister = !_isRegister;
                              _showResendButton = false;
                            });
                          },
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Login'
                          : 'Belum punya akun? Daftar',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
