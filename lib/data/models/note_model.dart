/// Catatan bebas untuk pemilik toko.
/// Warnanya dipakai sebagai penanda visual di daftar catatan.
class NoteModel {
  final int? id;
  final String title;
  final String? body;

  /// Nama warna dari [NoteColors.all] — 'teal', 'amber', 'blue', 'red', 'gray'.
  final String color;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    this.id,
    required this.title,
    this.body,
    this.color = 'teal',
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Cuplikan isi untuk ditampilkan di daftar.
  String get preview {
    final text = (body ?? '').replaceAll('\n', ' ').trim();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String?,
      color: (map['color'] as String?) ?? 'teal',
      isPinned: ((map['is_pinned'] as int?) ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  NoteModel copyWith({
    int? id,
    String? title,
    String? body,
    String? color,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
