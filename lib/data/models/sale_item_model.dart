import '../../core/utils/angka.dart';

/// Sale item model — a line item in a sale transaction.
class SaleItemModel {
  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final int costPrice;   // Captured at time of sale
  final int sellPrice;   // Captured at time of sale
  final double quantity;
  /// Harga baris ini **setelah** potongan barisnya dikurangi.
  final int subtotal;
  /// Potongan untuk baris ini, dalam rupiah. Nol kalau tidak ada potongan.
  final int discount;
  /// Satuan saat barang ini terjual (pcs, kg, liter, …).
  ///
  /// Disimpan per baris, bukan dibaca ulang dari tabel `products`, supaya
  /// struk lama tetap menampilkan satuan yang benar meskipun pemilik sudah
  /// mengganti satuan produknya kemudian — perlakuan yang sama dengan
  /// [costPrice].
  final String unit;

  SaleItemModel({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    required this.subtotal,
    this.discount = 0,
    this.unit = 'pcs',
  });

  /// Harga baris sebelum potongan dikurangi.
  int get grossSubtotal => subtotal + discount;

  /// Laba baris ini: uang yang benar-benar dibayar dikurangi modal barangnya.
  ///
  /// Sengaja dihitung dari [subtotal], bukan dari `sellPrice - costPrice`,
  /// supaya potongan harga ikut mengurangi laba. Kalau tidak, laba yang
  /// dilaporkan lebih besar daripada uang yang benar-benar masuk.
  int get profit => subtotal - (costPrice * quantity).round();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'discount': discount,
      'unit': unit,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      costPrice: map['cost_price'] as int,
      sellPrice: map['sell_price'] as int,
      quantity: Angka.jumlah(map['quantity']),
      subtotal: map['subtotal'] as int,
      discount: (map['discount'] as int?) ?? 0,
      // Baris lama belum punya kolom ini, jadi harus punya nilai cadangan.
      unit: (map['unit'] as String?) ?? 'pcs',
    );
  }
}
