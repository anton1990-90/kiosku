import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/note_model.dart';
import '../../providers/note_provider.dart';
import 'catatan_screen.dart' show noteColorKeys, noteColors;

/// Form tambah / edit catatan.
class CatatanFormScreen extends ConsumerStatefulWidget {
  final NoteModel? note;

  const CatatanFormScreen({super.key, this.note});

  @override
  ConsumerState<CatatanFormScreen> createState() => _CatatanFormScreenState();
}

class _CatatanFormScreenState extends ConsumerState<CatatanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _color = 'teal';
  bool _isPinned = false;
  bool _saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    if (n != null) {
      _titleController.text = n.title;
      _bodyController.text = n.body ?? '';
      _color = n.color;
      _isPinned = n.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final existing = widget.note;
    final note = NoteModel(
      id: existing?.id,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim().isEmpty
          ? null
          : _bodyController.text.trim(),
      color: _color,
      isPinned: _isPinned,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(noteProvider.notifier);
    if (isEditing) {
      await notifier.updateNote(note);
    } else {
      await notifier.addNote(note);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = noteColors(_color);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          IconButton(
            tooltip: _isPinned ? 'Lepas sematan' : 'Sematkan',
            onPressed: () => setState(() => _isPinned = !_isPinned),
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? AppColors.primary : null,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Pemilih warna
              const Text(
                'Warna penanda',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: noteColorKeys.map((key) {
                  final c = noteColors(key);
                  final isSelected = _color == key;
                  return GestureDetector(
                    onTap: () => setState(() => _color = key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? c.accent : AppColors.border,
                          width: isSelected ? 2.5 : 0.5,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 18, color: c.accent)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Judul'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                maxLines: 10,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Isi catatan (opsional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Simpan Perubahan' : 'Simpan Catatan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
