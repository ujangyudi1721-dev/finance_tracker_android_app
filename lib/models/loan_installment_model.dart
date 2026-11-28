
/// Model untuk merepresentasikan jadwal dan pembayaran cicilan utang/piutang.
class LoanInstallmentModel {
  final String id;
  final String loanId;
  final double jumlah;
  final DateTime tanggal;
  final String status;

  // Total pembayaran yang masih aktif.
  final double totalDibayar;

  LoanInstallmentModel({
    required this.id,
    required this.loanId,
    required this.jumlah,
    required this.tanggal,
    required this.status,
    this.totalDibayar = 0,
  });

  /// Mengubah data JSON dari Supabase menjadi objek cicilan.
  factory LoanInstallmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return LoanInstallmentModel(
      id: json['id'] as String,
      loanId: json['loan_id'] as String,
      jumlah: (json['jumlah'] as num).toDouble(),
      tanggal: DateTime.parse(json['tanggal'] as String),
      status: json['status'] as String? ?? 'unpaid',
      totalDibayar:
          (json['total_dibayar'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Mengubah objek cicilan menjadi JSON.
  ///
  /// Total pembayaran dihitung dari riwayat pembayaran,
  /// bukan disimpan langsung pada tabel cicilan.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_id': loanId,
      'jumlah': jumlah,
      'tanggal': tanggal.toIso8601String().split('T').first,
      'status': status,
    };
  }

  /// Menghitung sisa pembayaran cicilan.
  double get sisaPembayaran {
    final sisa = jumlah - totalDibayar;
    return sisa > 0 ? sisa : 0;
  }

  /// Menghitung persentase pembayaran.
  double get persentasePembayaran {
    if (jumlah <= 0) return 0;

    final persentase = (totalDibayar / jumlah) * 100;
    return persentase.clamp(0, 100).toDouble();
  }

  /// Memeriksa apakah cicilan sudah lunas.
  bool get isPaid => sisaPembayaran <= 0;

  /// Memeriksa apakah cicilan belum dibayar sama sekali.
  bool get isUnpaid => totalDibayar <= 0;

  /// Memeriksa apakah cicilan sudah dibayar sebagian.
  bool get isPartial => totalDibayar > 0 && sisaPembayaran > 0;
}
