
/// Model untuk merepresentasikan riwayat pembayaran utang/piutang.
class LoanPaymentModel {
  final String id;
  final String installmentId;
  final double jumlah;
  final DateTime tanggal;
  final String akun;

  // ID transaksi keuangan yang dibuat saat pembayaran.
  final int transactionId;

  // ID transaksi koreksi jika pembayaran dibatalkan.
  final int? reversalTransactionId;

  // active atau reversed.
  final String status;

  final String? createdBy;
  final DateTime createdAt;

  // Informasi pembatalan pembayaran.
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? reversalNote;

  LoanPaymentModel({
    required this.id,
    required this.installmentId,
    required this.jumlah,
    required this.tanggal,
    required this.akun,
    required this.transactionId,
    this.reversalTransactionId,
    required this.status,
    this.createdBy,
    required this.createdAt,
    this.reversedAt,
    this.reversedBy,
    this.reversalNote,
  });

  /// Mengubah data JSON dari Supabase menjadi objek pembayaran.
  factory LoanPaymentModel.fromJson(Map<String, dynamic> json) {
    return LoanPaymentModel(
      id: json['id'] as String,
      installmentId: json['installment_id'] as String,
      jumlah: (json['jumlah'] as num).toDouble(),
      tanggal: DateTime.parse(json['tanggal'] as String),
      akun: json['akun'] as String? ?? 'cash',
      transactionId: (json['transaction_id'] as num).toInt(),
      reversalTransactionId:
          (json['reversal_transaction_id'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'active',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reversedAt: json['reversed_at'] == null
          ? null
          : DateTime.parse(json['reversed_at'] as String),
      reversedBy: json['reversed_by'] as String?,
      reversalNote: json['reversal_note'] as String?,
    );
  }

  /// Memeriksa apakah pembayaran masih berlaku.
  bool get isActive => status == 'active';

  /// Memeriksa apakah pembayaran sudah dibatalkan.
  bool get isReversed => status == 'reversed';
}
