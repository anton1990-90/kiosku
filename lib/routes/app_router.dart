import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../core/constants/app_colors.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/license/activation_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/kasir/kasir_screen.dart';
import '../features/produk/produk_screen.dart';
import '../features/stok/stok_screen.dart';
import '../features/laporan/laporan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../shared/widgets/bottom_nav_shell.dart';

/// App router with auth guards and ShellRoute for bottom navigation.
/// Redirects unauthenticated users to login.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final licenseState = ref.watch(licenseProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Sambil memuat status auth & lisensi, tetap di splash.
      if (authState.isLoading || licenseState.isLoading) {
        return location == '/' ? null : '/';
      }

      final isActivationRoute = location.startsWith('/auth/activation');

      // Belum berlisensi → wajib aktivasi lebih dulu.
      if (!licenseState.isLicensed) {
        return isActivationRoute ? null : '/auth/activation';
      }

      // Sudah berlisensi tapi masih di layar aktivasi → lanjut ke alur akun.
      if (isActivationRoute) {
        if (authState.isAuthenticated) return '/dashboard';
        return authState.isFirstRun ? '/auth/register' : '/auth/login';
      }

      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = location.startsWith('/auth');

      // Belum login → ke register (pertama kali) atau login.
      if (!isLoggedIn && !isAuthRoute) {
        return authState.isFirstRun ? '/auth/register' : '/auth/login';
      }

      // Sudah login tapi di layar auth/splash → ke dashboard.
      if (isLoggedIn && (isAuthRoute || location == '/')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Splash screen (shown while auth state loads)
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      // Auth routes (no bottom nav)
      GoRoute(
        path: '/auth/activation',
        name: 'activation',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Main app routes (with bottom nav shell)
      ShellRoute(
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/kasir',
            name: 'kasir',
            builder: (context, state) => const KasirScreen(),
          ),
          GoRoute(
            path: '/produk',
            name: 'produk',
            builder: (context, state) => const ProdukScreen(),
          ),
          GoRoute(
            path: '/stok',
            name: 'stok',
            builder: (context, state) => const StokScreen(),
          ),
          GoRoute(
            path: '/laporan',
            name: 'laporan',
            builder: (context, state) => const LaporanScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Halaman tidak ditemukan',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    ),
  );
});

/// Simple splash screen with app logo, shown while auth state loads.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.storefront,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TokoKu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sembako & Penjualan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
