
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_model.dart';
import '../models/loan_installment_model.dart';
import 'household_service.dart';

/// Service untuk mengelola data utang, piutang, dan pembayaran.
class LoanService {
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

  /// Mengubah tanggal menjadi format YYYY-MM-DD.
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // READ: DATA PINJAMAN
  // =========================================================

  /// Mengambil seluruh data utang dan piutang rumah tangga.
  static Future<List<LoanModel>> getLoans() async {
    final householdId = await _getHouseholdId();

    final response = await _db
        .from('loans')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false);

    return response.map((row) => LoanModel.fromJson(row)).toList();
  }

  /// Menghitung sisa setiap pinjaman berdasarkan pembayaran aktif.
  ///
  /// Pinjaman cancelled dan completed memiliki sisa kewajiban Rp0.
  /// Pembayaran yang sudah dibalik tidak mengurangi sisa pinjaman.
  /// Nilai pokok pinjaman awal tidak pernah diubah.
  static Future<Map<String, double>> getOutstandingBalances(
    List<LoanModel> loans,
  ) async {
    if (loans.isEmpty) return {};

    final householdId = await _getHouseholdId();

    // Memastikan pinjaman berasal dari rumah tangga pengguna.
    final verifiedLoans = await _db
        .from('loans')
        .select('id')
        .eq('household_id', householdId);

    final verifiedLoanIds = verifiedLoans
        .map((row) => row['id'].toString())
        .toSet();

    final verifiedLoanList = loans
        .where((loan) => verifiedLoanIds.contains(loan.id))
        .toList();

    if (verifiedLoanList.isEmpty) return {};

    // Menyiapkan total pembayaran aktif setiap pinjaman.
    final Map<String, double> totalPaidByLoan = {
      for (final loan in verifiedLoanList) loan.id: 0,
    };

    // Hanya pinjaman aktif yang perlu dihitung pembayarannya.
    final activeLoans = verifiedLoanList
        .where((loan) => loan.status == 'active')
        .toList();

    if (activeLoans.isNotEmpty) {
      final activeLoanIds = activeLoans.map((loan) => loan.id).toList();

      // Mengambil jadwal cicilan pinjaman aktif.
      final installmentResponse = await _db
          .from('loan_installments')
          .select('id, loan_id')
          .inFilter('loan_id', activeLoanIds);

      // Memetakan ID cicilan ke ID pinjamannya.
      final Map<String, String> installmentToLoan = {};

      for (final row in installmentResponse) {
        installmentToLoan[row['id'].toString()] =
            row['loan_id'].toString();
      }

      if (installmentToLoan.isNotEmpty) {
        final installmentIds = installmentToLoan.keys.toList();

        // Mengambil pembayaran aktif saja.
        final paymentResponse = await _db
            .from('loan_payments')
            .select('installment_id, jumlah')
            .eq('status', 'active')
            .inFilter('installment_id', installmentIds);

        // Menjumlahkan pembayaran aktif setiap pinjaman.
        for (final payment in paymentResponse) {
          final installmentId = payment['installment_id'].toString();
          final loanId = installmentToLoan[installmentId];

          if (loanId == null) continue;

          final amount = (payment['jumlah'] as num).toDouble();

          totalPaidByLoan[loanId] =
              (totalPaidByLoan[loanId] ?? 0) + amount;
        }
      }
    }

    // Menghitung sisa kewajiban setiap pinjaman.
    final Map<String, double> outstandingBalances = {};

    for (final loan in verifiedLoanList) {
      // Pinjaman yang dibatalkan atau lunas tidak memiliki kewajiban.
      if (loan.status == 'cancelled' ||
          loan.status == 'completed') {
        outstandingBalances[loan.id] = 0;
        continue;
      }

      final totalPaid = totalPaidByLoan[loan.id] ?? 0;
      final remaining = loan.totalLoan - totalPaid;

      outstandingBalances[loan.id] =
          remaining > 0 ? remaining : 0;
    }

    return outstandingBalances;
  }

  /// Mengambil satu data pinjaman berdasarkan ID.
  static Future<LoanModel?> getLoanById(String loanId) async {
    final householdId = await _getHouseholdId();

    final response = await _db
        .from('loans')
        .select()
        .eq('id', loanId)
        .eq('household_id', householdId)
        .maybeSingle();

    if (response == null) return null;

    return LoanModel.fromJson(response);
  }

  // =========================================================
  // READ: JADWAL CICILAN
  // =========================================================

  /// Mengambil jadwal cicilan beserta total pembayaran aktif.
  static Future<List<LoanInstallmentModel>> getInstallments(
    String loanId,
  ) async {
    final householdId = await _getHouseholdId();

    // Memastikan pinjaman berasal dari rumah tangga pengguna.
    final loan = await _db
        .from('loans')
        .select('id')
        .eq('id', loanId)
        .eq('household_id', householdId)
        .maybeSingle();

    if (loan == null) {
      throw Exception('Data pinjaman tidak ditemukan.');
    }

    // Mengambil seluruh jadwal cicilan.
    final installmentResponse = await _db
        .from('loan_installments')
        .select()
        .eq('loan_id', loanId)
        .order('tanggal');

    if (installmentResponse.isEmpty) return [];

    // Mengumpulkan ID seluruh cicilan.
    final installmentIds = installmentResponse
        .map((row) => row['id'].toString())
        .toList();

    // Mengambil pembayaran aktif untuk semua cicilan.
    final paymentResponse = await _db
        .from('loan_payments')
        .select('installment_id, jumlah')
        .eq('status', 'active')
        .inFilter('installment_id', installmentIds);

    // Menghitung total pembayaran setiap cicilan.
    final Map<String, double> totalPembayaran = {};

    for (final payment in paymentResponse) {
      final installmentId = payment['installment_id'].toString();
      final amount = (payment['jumlah'] as num).toDouble();

      totalPembayaran[installmentId] =
          (totalPembayaran[installmentId] ?? 0) + amount;
    }

    // Menggabungkan data cicilan dengan hasil perhitungan.
    return installmentResponse.map((row) {
      final data = Map<String, dynamic>.from(row);
      final installmentId = data['id'].toString();

      data['total_dibayar'] =
          totalPembayaran[installmentId] ?? 0.0;

      return LoanInstallmentModel.fromJson(data);
    }).toList();
  }

  // =========================================================
  // READ: RIWAYAT PEMBAYARAN
  // =========================================================

  /// Mengambil riwayat pembayaran dari satu cicilan.
  ///
  /// Riwayat pembayaran aktif maupun reversed tetap ditampilkan.
  static Future<List<Map<String, dynamic>>> getPayments(
    String installmentId,
  ) async {
    final householdId = await _getHouseholdId();

    // Memastikan cicilan memang milik rumah tangga pengguna.
    final installment = await _db
        .from('loan_installments')
        .select('loan_id')
        .eq('id', installmentId)
        .maybeSingle();

    if (installment == null) {
      throw Exception('Data cicilan tidak ditemukan.');
    }

    final loan = await _db
        .from('loans')
        .select('id')
        .eq('id', installment['loan_id'])
        .eq('household_id', householdId)
        .maybeSingle();

    if (loan == null) {
      throw Exception('Anda tidak memiliki akses ke cicilan ini.');
    }

    // Mengambil seluruh riwayat, termasuk pembayaran yang dibalik.
    final response = await _db
        .from('loan_payments')
        .select()
        .eq('installment_id', installmentId)
        .order('tanggal', ascending: false);

    return response
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // =========================================================
  // CREATE: DATA PINJAMAN DAN JADWAL CICILAN
  // =========================================================

  /// Membuat data utang atau piutang beserta jadwal cicilan.
  ///
  /// Seluruh proses penyimpanan dilakukan oleh satu RPC
  /// agar data pinjaman dan jadwal cicilan tetap konsisten.
  static Future<String> createLoan({
    required String jenis,
    required String nama,
    String? pihakTerkait,
    required double totalLoan,
    required int tenor,
    required double cicilanPerBulan,
    required DateTime tanggalMulai,
    String? keterangan,
  }) async {
    // Memastikan jenis pinjaman valid.
    if (jenis != 'debt' && jenis != 'receivable') {
      throw Exception('Jenis pinjaman tidak valid.');
    }

    // Memastikan nama pinjaman tidak kosong.
    if (nama.trim().isEmpty) {
      throw Exception('Nama pinjaman wajib diisi.');
    }

    // Memastikan total pinjaman valid.
    if (!totalLoan.isFinite || totalLoan <= 0) {
      throw Exception('Total pinjaman harus lebih dari nol.');
    }

    // Memastikan tenor valid.
    if (tenor < 1) {
      throw Exception('Tenor minimal satu bulan.');
    }

    // Memastikan cicilan valid.
    if (!cicilanPerBulan.isFinite || cicilanPerBulan <= 0) {
      throw Exception('Nominal cicilan harus lebih dari nol.');
    }

    // Memeriksa kecocokan total pinjaman dengan cicilan.
    final totalTerjadwal = cicilanPerBulan * tenor;

    if (cicilanPerBulan * (tenor - 1) >= totalLoan ||
        totalTerjadwal < totalLoan) {
      throw Exception(
        'Nominal cicilan tidak sesuai dengan total pinjaman dan tenor.',
      );
    }

    // Memanggil fungsi PostgreSQL untuk menyimpan pinjaman.
    final result = await _db.rpc(
      'create_loan_with_installments',
      params: {
        'p_jenis': jenis,
        'p_nama': nama.trim(),
        'p_pihak_terkait': pihakTerkait?.trim(),
        'p_total_loan': totalLoan,
        'p_tenor': tenor,
        'p_cicilan_per_bulan': cicilanPerBulan,
        'p_tanggal_mulai': _formatDate(tanggalMulai),
        'p_keterangan': keterangan?.trim(),
      },
    );

    return result.toString();
  }

  // =========================================================
  // CREATE: PEMBAYARAN CICILAN
  // =========================================================

  /// Mencatat pembayaran cicilan, baik sebagian maupun penuh.
  ///
  /// Database otomatis membuat transaksi keuangan,
  /// menyimpan riwayat pembayaran, dan memperbarui status cicilan.
  static Future<String> recordPayment({
    required String installmentId,
    required double amount,
    required DateTime date,
    required String account,
    String? note,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('Nominal pembayaran harus lebih dari nol.');
    }

    if (account.trim().isEmpty) {
      throw Exception('Rekening pembayaran wajib dipilih.');
    }

    if (installmentId.trim().isEmpty) {
      throw Exception('Data cicilan tidak valid.');
    }

    final result = await _db.rpc(
      'record_loan_payment',
      params: {
        'p_installment_id': installmentId,
        'p_jumlah': amount,
        'p_tanggal': _formatDate(date),
        'p_akun': account.trim(),
        'p_keterangan': note?.trim(),
      },
    );

    return result.toString();
  }

  // =========================================================
  // REVERSAL: PEMBATALAN PEMBAYARAN
  // =========================================================

  /// Membatalkan pembayaran tanpa menghapus riwayat.
  ///
  /// Database otomatis membuat transaksi koreksi.
  static Future<String> reversePayment({
    required String paymentId,
    String? note,
  }) async {
    if (paymentId.trim().isEmpty) {
      throw Exception('ID pembayaran tidak valid.');
    }

    final result = await _db.rpc(
      'reverse_loan_payment',
      params: {
        'p_payment_id': paymentId,
        'p_keterangan': note?.trim(),
      },
    );

    return result.toString();
  }

  // =========================================================
  // CANCEL: PEMBATALAN PINJAMAN
  // =========================================================

  /// Membatalkan pinjaman aktif, termasuk pinjaman yang sudah
  /// memiliki pembayaran sebagian.
  ///
  /// Pembayaran, jadwal cicilan, dan transaksi keuangan lama
  /// tetap dipertahankan oleh database.
  static Future<String> cancelLoan({
    required String loanId,
    String? note,
  }) async {
    if (loanId.trim().isEmpty) {
      throw Exception('ID pinjaman tidak valid.');
    }

    final result = await _db.rpc(
      'cancel_loan',
      params: {
        'p_loan_id': loanId,
        'p_keterangan': note?.trim(),
      },
    );

    return result.toString();
  }
}
