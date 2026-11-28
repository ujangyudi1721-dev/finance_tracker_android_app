
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service untuk mengelola seluruh proses autentikasi pengguna.
class AuthService {
  /// Mengambil instance Supabase yang sudah diinisialisasi.
  static SupabaseClient get _db => Supabase.instance.client;

  /// Alamat Deep Link untuk kembali ke aplikasi setelah konfirmasi email.
  static const String emailRedirectUrl =
      'financetracker://login-callback/';

  /// Mengambil informasi pengguna yang sedang login.
  /// Menghasilkan null jika belum ada pengguna yang login.
  static User? get currentUser => _db.auth.currentUser;

  /// Memeriksa apakah pengguna sudah memiliki sesi login.
  static bool get isLoggedIn => currentUser != null;

  /// Login menggunakan email dan password.
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _db.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Mendaftarkan akun baru.
  ///
  /// Setelah email dikonfirmasi, pengguna diarahkan
  /// kembali ke aplikasi Finance Tracker.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _db.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: emailRedirectUrl,
    );
  }

  /// Mengirim ulang email konfirmasi untuk akun yang belum dikonfirmasi.
  static Future<void> resendSignupConfirmation({
    required String email,
  }) async {
    await _db.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: emailRedirectUrl,
    );
  }

  /// Mengeluarkan pengguna dari aplikasi.
  static Future<void> signOut() async {
    await _db.auth.signOut();
  }

  /// Mendengarkan perubahan status autentikasi.
  static Stream<AuthState> get authStateChanges {
    return _db.auth.onAuthStateChange;
  }
}
