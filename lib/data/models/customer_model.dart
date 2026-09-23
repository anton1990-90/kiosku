/// Data pelanggan — buku pelanggan yang bisa ditambah, diedit, dan dihapus.
///
/// Sebelum v1.15.0 nama pelanggan hanya tersimpan sebagai teks bebas di tiap
/// catatan piutang, sehingga "Bu Siti" dan "bu siti" tampak seperti dua orang
/// yang berbeda dan nomor HP-nya tidak tersimpan di mana pun. Tabel ini
/// menjawab dua pertanyaan yang wajar: siapa saja yang masih berhutang, dan
/// bagaimana cara menghubunginya.
///
/// Nama pelanggan **tetap** disimpan apa adanya di `debts.party_name` dan
/// `sales.customer_name` sebagai rekaman saat transaksi terjadi — sama seperti
/// `sale_items.unit`. Jadi mengganti nama pelanggan di sini tidak mengubah
/// struk dan laporan yang sudah ada.
class CustomerModel {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Inisial untuk avatar bulat.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'P';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Ringkasan satu pelanggan untuk daftar di layar Pelanggan.
///
/// Dipisahkan dari [CustomerModel] karena isinya hasil hitungan, bukan kolom
/// tabel `customers` — sama seperti [DebtDetail] dipisahkan dari [DebtModel].
/// Kalau angka-angka ini ditumpangkan ke modelnya, `toMap` akan ikut membawa
/// kolom yang tidak ada di tabelnya.
class CustomerRingkasan {
  final CustomerModel customer;

  /// Sisa piutang yang belum dibayar (hanya yang belum lunas).
  final int totalPiutang;

  /// Jumlah uang yang benar-benar masuk dari pelanggan ini (semua transaksi).
  final int totalBelanja;

  /// Berapa nota yang tercatat atas nama pelanggan ini.
  final int jumlahTransaksi;

  /// Kapan terakhir pelanggan ini bertransaksi.
  final DateTime? transaksiTerakhir;

  const CustomerRingkasan({
    required this.customer,
    this.totalPiutang = 0,
    this.totalBelanja = 0,
    this.jumlahTransaksi = 0,
    this.transaksiTerakhir,
  });

  bool get adaPiutang => totalPiutang > 0;
}
