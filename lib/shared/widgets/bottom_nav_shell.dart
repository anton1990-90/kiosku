import '../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';

/// Shell widget with persistent bottom navigation bar.
/// Wraps all main screens (Dashboard, Kasir, Produk, Stok, Laporan, Profile).
class BottomNavShell extends StatelessWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/produk')) return 1;
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
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
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
                _navItem(
                  context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Beranda',
                  index: 0,
                  selectedIndex: selectedIndex,
                ),
                _navItem(
                  context,
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view,
                  label: 'Produk',
                  index: 1,
                  selectedIndex: selectedIndex,
                ),
                _fabItem(context, selectedIndex),
                _navItem(
                  context,
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Laporan',
                  index: 3,
                  selectedIndex: selectedIndex,
                ),
                _navItem(
                  context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 4,
                  selectedIndex: selectedIndex,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
