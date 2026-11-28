
/// Model untuk merepresentasikan data utang dan piutang.
class LoanModel {
  final String id;
  final String jenis;
  final String nama;
  final String? pihakTerkait;
  final double totalLoan;
  final int tenor;
  final double cicilanPerBulan;
  final String status;
  final DateTime createdAt;
  final DateTime? tanggalMulai;
  final DateTime? jatuhTempo;
  final String? keterangan;
  final String householdId;
  final String? createdBy;

  LoanModel({
    required this.id,
    required this.jenis,
    required this.nama,
    this.pihakTerkait,
    required this.totalLoan,
    required this.tenor,
    required this.cicilanPerBulan,
    required this.status,
    required this.createdAt,
    this.tanggalMulai,
    this.jatuhTempo,
    this.keterangan,
    required this.householdId,
    this.createdBy,
  });

  /// Mengubah data JSON dari Supabase menjadi objek LoanModel.
  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'] as String,
      jenis: json['jenis'] as String,
      nama: json['nama'] as String,
      pihakTerkait: json['pihak_terkait'] as String?,
      totalLoan: (json['total_loan'] as num).toDouble(),
      tenor: (json['tenor'] as num).toInt(),
      cicilanPerBulan:
          (json['cicilan_per_bulan'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      tanggalMulai: json['tanggal_mulai'] == null
          ? null
          : DateTime.parse(json['tanggal_mulai'] as String),
      jatuhTempo: json['jatuh_tempo'] == null
          ? null
          : DateTime.parse(json['jatuh_tempo'] as String),
      keterangan: json['keterangan'] as String?,
      householdId: json['household_id'] as String,
      createdBy: json['created_by'] as String?,
    );
  }

  /// Menghasilkan data yang diperlukan untuk membuat pinjaman baru.
  ///
  /// ID, waktu pembuatan, rumah tangga, dan pembuat
  /// ditentukan oleh database atau service.
  Map<String, dynamic> toInsertJson() {
    return {
      'jenis': jenis,
      'nama': nama,
      'pihak_terkait': pihakTerkait,
      'total_loan': totalLoan,
      'tenor': tenor,
      'cicilan_per_bulan': cicilanPerBulan,
      'status': status,
      'tanggal_mulai':
          tanggalMulai?.toIso8601String().split('T').first,
      'jatuh_tempo':
          jatuhTempo?.toIso8601String().split('T').first,
      'keterangan': keterangan,
    };
  }

  /// Memeriksa apakah data merupakan utang.
  bool get isDebt => jenis == 'debt';

  /// Memeriksa apakah data merupakan piutang.
  bool get isReceivable => jenis == 'receivable';
}
