import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';

/// Satu tab pada navigasi utama.
///
/// [index] sengaja tidak mengikuti urutan daftar: ia adalah nomor tab utama
/// yang dipakai `_selectedIndex` dan tombol kembali. Untuk kasir daftarnya
/// lebih pendek, tetapi nomor tabnya tetap sama — jadi peta rute → nomor tab
/// tetap hanya ada di satu tempat.
class _TabNav {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabNav({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Tab pemilik toko — semuanya.
const _tabPemilik = <_TabNav>[
  _TabNav(
    index: 0,
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Beranda',
  ),
  _TabNav(
    index: 1,
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view,
    label: 'Produk',
  ),
  _TabNav(
    index: 2,
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    label: 'Kasir',
  ),
  _TabNav(
    index: 3,
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    label: 'Laporan',
  ),
  _TabNav(
    index: 4,
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profile',
  ),
];

/// Tab kasir — hanya yang memang haknya.
///
/// Hanya tiga, karena hanya tiga rute di dalam shell yang bukan milik pemilik
/// toko: Beranda, Kasir, dan Profile. Produk (pengelolaan barang) dan Laporan
/// (laba dan laporan keuangan) ditolak router untuk kasir, jadi tabnya tidak
/// ditampilkan sama sekali.
const _tabKasir = <_TabNav>[
  _TabNav(
    index: 0,
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Beranda',
  ),
  _TabNav(
    index: 2,
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    label: 'Kasir',
  ),
  _TabNav(
    index: 4,
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profile',
  ),
];

/// Shell dengan navigasi tetap untuk semua layar utama
/// (Beranda, Produk, Kasir, Laporan, Profile).
///
/// Tata letaknya mengikuti lebar layar:
///   * HP — bar navigasi di bawah, dengan tombol Kasir menonjol di tengah.
///   * Tablet (>= 720 dp) — `NavigationRail` di sisi kiri, karena bar bawah
///     terlihat janggal dan menyisakan banyak ruang kosong di layar lebar.
///
/// Di sini juga ditangani tombol kembali bawaan Android: dari tab mana pun
/// selain Beranda, menekan kembali akan membuka Beranda dulu, bukan langsung
/// menutup aplikasi.
///
/// Sejak v1.16.0 isinya bergantung pada peran akun yang sedang login: kasir
/// hanya melihat tab yang memang haknya. Rute milik pemilik toko ditolak oleh
/// router, dan menampilkan tab yang menolak dibuka lebih buruk daripada tidak
/// menampilkannya sama sekali — pengguna menekan, lalu dilempar balik ke
/// Beranda tanpa penjelasan.
class BottomNavShell extends ConsumerWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/produk')) return 1;
    // Stok adalah bagian dari Produk, dan penting untuk penanganan tombol
    // kembali: tanpa baris ini `/stok` dianggap Beranda sehingga menekan
    // kembali malah menutup aplikasi.
    if (location.startsWith('/stok')) return 1;
    if (location.startsWith('/kasir')) return 2;
    if (location.startsWith('/laporan')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/produk');
      case 2:
        context.go('/kasir');
      case 3:
        context.go('/laporan');
      case 4:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(context);
    final tablet = Responsive.isTablet(context);

    // Peran dibaca dari state auth, bukan disimpan lagi di sini: state auth
    // sudah menjadi sumber kebenaran untuk hak akses, dan menyimpannya ulang
    // berarti ada dua tempat yang bisa berbeda.
    final tabs = ref.watch(authProvider).isOwner ? _tabPemilik : _tabKasir;

    return PopScope<Object?>(
      // Di Beranda, kembali berarti keluar dari aplikasi (perilaku normal).
      // Di tab lain, kembali dulu ke Beranda.
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        body: tablet
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rail(context, tabs, selectedIndex),
                  Container(width: 0.5, color: AppColors.border),
                  Expanded(child: child),
                ],
              )
            : child,
        bottomNavigationBar:
            tablet ? null : _bottomBar(context, tabs, selectedIndex),
      ),
    );
  }

  // ------------------------------------------------------------ HP (bawah)

  Widget _bottomBar(
    BuildContext context,
    List<_TabNav> tabs,
    int selectedIndex,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Isi bar mengikuti [tabs]; yang tetap hanyalah tombol Kasir di
              // tengah, karena itu tombol yang paling sering ditekan.
              for (final tab in tabs)
                if (tab.index == 2)
                  _fabItem(context, selectedIndex)
                else
                  _navItem(
                    context,
                    icon: tab.icon,
                    activeIcon: tab.activeIcon,
                    label: tab.label,
                    index: tab.index,
                    selectedIndex: selectedIndex,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- tablet (rel)

  Widget _rail(BuildContext context, List<_TabNav> tabs, int selectedIndex) {
    return NavigationRail(
      selectedIndex: _railIndex(tabs, selectedIndex),
      // Nomor tujuan rel adalah nomor urut [tabs], bukan nomor tab utama —
      // untuk kasir keduanya berbeda.
      onDestinationSelected: (index) => _onTap(tabs[index].index, context),
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppColors.bgCard,
      indicatorColor: AppColors.primary.withOpacity(0.12),
      selectedIconTheme:
          const IconThemeData(color: AppColors.primary, size: 24),
      unselectedIconTheme:
          const IconThemeData(color: AppColors.textTertiary, size: 24),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront, color: Colors.white, size: 22),
        ),
      ),
      destinations: [
        for (final tab in tabs)
          NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: Text(tab.label),
          ),
      ],
    );
  }

  /// Nomor tab utama → nomor tujuan di rel tablet.
  ///
  /// `NavigationRail` menomori tujuannya dari nol mengikuti daftar yang
  /// diberikan, sedangkan [_selectedIndex] menomori tab utama 0..4. Untuk
  /// kasir daftarnya hanya tiga, jadi nomor tab tidak boleh dipakai langsung:
  /// rel akan menunjuk tujuan yang tidak ada dan Flutter melempar galat saat
  /// membangun layar.
  int _railIndex(List<_TabNav> tabs, int tabIndex) {
    final posisi = tabs.indexWhere((t) => t.index == tabIndex);
    return posisi < 0 ? 0 : posisi;
  }

  // -------------------------------------------------------------- tombol

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int selectedIndex,
  }) {
    final isActive = selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTap(index, context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Center FAB — Kasir (POS) — the fastest path to a sale.
  Widget _fabItem(BuildContext context, int selectedIndex) {
    final isActive = selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onTap(2, context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -8),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isActive
                      ? Border.all(color: AppColors.primaryDark, width: 3)
                      : null,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Kasir',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
