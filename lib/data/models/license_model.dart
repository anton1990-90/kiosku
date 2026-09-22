/// Lisensi aplikasi — hasil aktivasi yang disimpan di perangkat.
class LicenseModel {
  final String code;
  final String deviceId;
  final String customerName;
  final String storeName;
  final DateTime activatedAt;

  const LicenseModel({
    required this.code,
    required this.deviceId,
    required this.customerName,
    required this.storeName,
    required this.activatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'device_id': deviceId,
      'customer_name': customerName,
      'store_name': storeName,
      'activated_at': activatedAt.toIso8601String(),
    };
  }

  factory LicenseModel.fromMap(Map<String, dynamic> map) {
    return LicenseModel(
      code: map['code'] as String,
      deviceId: map['device_id'] as String,
      customerName: (map['customer_name'] as String?) ?? '',
      storeName: (map['store_name'] as String?) ?? '',
      activatedAt:
          DateTime.tryParse(map['activated_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// Kesalahan aktivasi yang pesannya sudah siap ditampilkan ke pengguna.
class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);

  @override
  String toString() => message;
}
