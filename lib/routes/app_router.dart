import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_colors.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
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

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // While checking auth state, stay on the splash screen.
      if (authState.isLoading) {
        return state.matchedLocation == '/'
            ? null
            : '/';
      }

      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      // Not logged in → redirect to register (first run) or login.
      if (!isLoggedIn && !isAuthRoute) {
        return authState.isFirstRun ? '/auth/register' : '/auth/login';
      }

      // Logged in but on auth screen or splash → go to dashboard.
      if (isLoggedIn && (isAuthRoute || state.matchedLocation == '/')) {
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
