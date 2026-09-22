import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/note_model.dart';
import '../../providers/note_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Warna catatan yang bisa dipilih pengguna.
const noteColorKeys = ['teal', 'amber', 'blue', 'red', 'gray'];

/// Warna aksen & latar untuk sebuah catatan.
({Color accent, Color background}) noteColors(String key) {
  switch (key) {
    case 'amber':
      return (accent: AppColors.warningMid, background: AppColors.warningLight);
    case 'blue':
      return (accent: AppColors.infoMid, background: AppColors.infoLight);
    case 'red':
      return (accent: AppColors.dangerMid, background: AppColors.dangerLight);
    case 'gray':
      return (accent: AppColors.textSecondary, background: AppColors.bgSoft);
    case 'teal':
    default:
      return (accent: AppColors.primaryDark, background: AppColors.primaryLight);
  }
}

/// Halaman Catatan — catatan bebas untuk pemilik toko.
class CatatanScreen extends ConsumerStatefulWidget {
  const CatatanScreen({super.key});

  @override
  ConsumerState<CatatanScreen> createState() => _CatatanScreenState();
}

class _CatatanScreenState extends ConsumerState<CatatanScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Catatan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/catatan/tambah'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catatan baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(noteProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Cari catatan',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: state.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(noteProvider.notifier).setSearch('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : state.notes.isEmpty
                    ? const EmptyState(
                        icon: Icons.note_alt_outlined,
                        title: 'Belum ada catatan',
                        subtitle:
                            'Simpan catatan penting: daftar belanja, pesanan '
                            'pelanggan, atau pengingat lainnya.',
                      )
                    : Responsive.centered(
                      ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: state.notes.length,
                          itemBuilder: (context, i) =>
                              _noteCard(state.notes[i]),
                        ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(NoteModel note) {
    final colors = noteColors(note.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withOpacity(0.25), width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/catatan/edit', extra: note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    Icon(Icons.push_pin, size: 16, color: colors.accent),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert,
                        size: 18, color: colors.accent),
                    onSelected: (value) async {
                      if (value == 'pin') {
                        await ref
                            .read(noteProvider.notifier)
                            .togglePin(note.id!, !note.isPinned);
                      } else if (value == 'edit') {
                        if (mounted) {
                          context.push('/catatan/edit', extra: note);
                        }
                      } else if (value == 'delete') {
                        await _confirmDelete(note);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(note.isPinned ? 'Lepas sematan' : 'Sematkan'),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
                ],
              ),
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.accent.withOpacity(0.85),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                Formatters.dateTime(note.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.accent.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(NoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus catatan?'),
        content: Text('"${note.title}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(noteProvider.notifier).deleteNote(note.id!);
    }
  }
}
