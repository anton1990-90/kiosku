import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/note_model.dart';
import '../data/repositories/note_repository.dart';

/// State daftar catatan.
class NoteState {
  final List<NoteModel> notes;
  final String search;
  final bool isLoading;

  const NoteState({
    this.notes = const [],
    this.search = '',
    this.isLoading = false,
  });

  NoteState copyWith({
    List<NoteModel>? notes,
    String? search,
    bool? isLoading,
  }) {
    return NoteState(
      notes: notes ?? this.notes,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier catatan — CRUD dan sematkan.
class NoteNotifier extends StateNotifier<NoteState> {
  final NoteRepository _repo = NoteRepository();

  NoteNotifier() : super(const NoteState(isLoading: true)) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    state = state.copyWith(isLoading: true);
    final notes = await _repo.getAll(search: state.search);
    state = state.copyWith(notes: notes, isLoading: false);
  }

  Future<void> setSearch(String query) async {
    state = state.copyWith(search: query);
    await loadNotes();
  }

  Future<void> addNote(NoteModel note) async {
    await _repo.insert(note);
    await loadNotes();
  }

  Future<void> updateNote(NoteModel note) async {
    await _repo.update(note);
    await loadNotes();
  }

  Future<void> deleteNote(int id) async {
    await _repo.delete(id);
    await loadNotes();
  }

  Future<void> togglePin(int id, bool isPinned) async {
    await _repo.togglePin(id, isPinned);
    await loadNotes();
  }
}

final noteProvider = StateNotifierProvider<NoteNotifier, NoteState>((ref) {
  return NoteNotifier();
});
