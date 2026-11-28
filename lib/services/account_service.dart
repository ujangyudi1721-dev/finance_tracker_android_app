
import 'package:supabase_flutter/supabase_flutter.dart';

import 'household_service.dart';

/// Service untuk mengelola akun keuangan rumah tangga.
class AccountService {
  /// Mengambil koneksi Supabase.
  static SupabaseClient get _db => Supabase.instance.client;

  /// Mengambil ID rumah tangga pengguna yang sedang login.
  static Future<String> _getHouseholdId() async {
    final household = await HouseholdService.getMyHousehold();

    if (household == null || household['id'] == null) {
      throw Exception('Rumah tangga belum ditemukan.');
    }

    return household['id'].toString();
  }

  /// Mengambil daftar akun rumah tangga.
  ///
  /// Secara default hanya akun aktif yang ditampilkan.
  /// Owner dapat menggunakan activeOnly = false
  /// untuk melihat akun yang sudah dinonaktifkan.
  static Future<List<Map<String, dynamic>>> getAccounts({
    bool activeOnly = true,
  }) async {
    final householdId = await _getHouseholdId();

    var query = _db
        .from('accounts')
        .select('id, household_id, kode, nama, is_active, created_at')
        .eq('household_id', householdId);

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('nama');

    return response
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Menambahkan akun baru.
  ///
  /// Hanya Owner yang diizinkan oleh RLS Supabase.
  static Future<String> createAccount({
    required String kode,
    required String nama,
  }) async {
    final householdId = await _getHouseholdId();
    final user = _db.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final normalizedCode = kode.trim().toLowerCase();
    final normalizedName = nama.trim();

    if (normalizedCode.isEmpty || normalizedName.isEmpty) {
      throw Exception('Kode dan nama akun wajib diisi.');
    }

    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$')
        .hasMatch(normalizedCode)) {
      throw Exception(
        'Kode akun hanya boleh berisi huruf kecil, angka, '
        'garis bawah, dan tanda hubung.',
      );
    }

    final response = await _db
        .from('accounts')
        .insert({
          'household_id': householdId,
          'kode': normalizedCode,
          'nama': normalizedName,
          'created_by': user.id,
        })
        .select('id')
        .single();

    return response['id'].toString();
  }

  /// Mengubah nama akun.
  ///
  /// Kode akun tidak dapat diubah agar riwayat transaksi
  /// tetap menggunakan identitas akun yang sama.
  static Future<void> updateAccount({
    required String accountId,
    required String nama,
  }) async {
    final householdId = await _getHouseholdId();
    final normalizedName = nama.trim();

    if (accountId.trim().isEmpty) {
      throw Exception('ID akun tidak valid.');
    }

    if (normalizedName.isEmpty) {
      throw Exception('Nama akun wajib diisi.');
    }

    await _db
        .from('accounts')
        .update({
          'nama': normalizedName,
        })
        .eq('id', accountId)
        .eq('household_id', householdId);
  }

  /// Mengaktifkan atau menonaktifkan akun.
  ///
  /// Akun yang dinonaktifkan tetap tersimpan di database
  /// agar riwayat transaksi tidak rusak.
  static Future<void> setAccountActive({
    required String accountId,
    required bool isActive,
  }) async {
    final householdId = await _getHouseholdId();

    if (accountId.trim().isEmpty) {
      throw Exception('ID akun tidak valid.');
    }

    await _db
        .from('accounts')
        .update({
          'is_active': isActive,
        })
        .eq('id', accountId)
        .eq('household_id', householdId);
  }
}
