
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service untuk mengelola rumah tangga dan anggota keluarga.
class HouseholdService {
  /// Mengambil koneksi Supabase.
  static SupabaseClient get _db => Supabase.instance.client;

  /// Membuat rumah tangga baru.
  ///
  /// Akun yang sedang login otomatis menjadi Owner.
  static Future<String> createHousehold({
    required String name,
  }) async {
    final result = await _db.rpc(
      'create_household',
      params: {
        'p_name': name,
      },
    );

    return result.toString();
  }

  /// Mengambil data rumah tangga milik pengguna yang login.
  static Future<Map<String, dynamic>?> getMyHousehold() async {
    final user = _db.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final result = await _db
        .from('household_members')
        .select('''
          role,
          households (
            id,
            name,
            created_at
          )
        ''')
        .eq('user_id', user.id)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    final householdData = result['households'];

    if (householdData == null) {
      return null;
    }

    return {
      'id': householdData['id'],
      'name': householdData['name'],
      'role': result['role'],
      'created_at': householdData['created_at'],
    };
  }


  /// Menambahkan pengguna terdaftar ke rumah tangga sebagai Member.
  ///
  /// Fungsi ini hanya dapat dijalankan oleh pengguna dengan peran Owner.
  static Future<void> addHouseholdMember({
    required String email,
  }) async {
    await _db.rpc(
      'add_household_member',
      params: {
        'p_email': email.trim(),
      },
    );
  }

}
