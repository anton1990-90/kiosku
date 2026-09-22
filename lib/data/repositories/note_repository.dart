import '../database/database_helper.dart';
import '../models/note_model.dart';

/// Repositori catatan. Semua data lokal (offline).
class NoteRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<NoteModel>> getAll({String? search}) async {
    final db = await _db.database;
    final trimmed = search?.trim() ?? '';

    final results = await db.query(
      'notes',
      where: trimmed.isEmpty
          ? null
          : 'title LIKE ? OR body LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%', '%$trimmed%'],
      // Yang disematkan selalu di atas, lalu yang paling baru diubah.
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return results.map((m) => NoteModel.fromMap(m)).toList();
  }

  Future<NoteModel?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return NoteModel.fromMap(results.first);
  }

  Future<int> insert(NoteModel note) async {
    final db = await _db.database;
    return await db.insert('notes', note.toMap());
  }

  Future<int> update(NoteModel note) async {
    final db = await _db.database;
    return await db.update(
      'notes',
      note.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Sematkan / lepas sematan.
  Future<void> togglePin(int id, bool isPinned) async {
    final db = await _db.database;
    await db.update(
      'notes',
      {
        'is_pinned': isPinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM notes');
    return (rows.first['c'] as int?) ?? 0;
  }
}
