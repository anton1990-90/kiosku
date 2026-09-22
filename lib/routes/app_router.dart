import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../core/config/app_config.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/report_period.dart';
import '../data/models/debt_model.dart';
import '../data/models/note_model.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/catatan/catatan_form_screen.dart';
import '../features/catatan/catatan_screen.dart';
import '../features/hutang/hutang_form_screen.dart';
import '../features/hutang/hutang_screen.dart';
import '../features/license/activation_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/kas/kas_screen.dart';
import '../features/kasir/kasir_screen.dart';
import '../features/produk/produk_screen.dart';
import '../features/profile/payment_methods_screen.dart';
import '../features/profile/store_info_screen.dart';
import '../features/profile/supplier_screen.dart';
import '../features/stok/stok_menipis_screen.dart';
import '../features/stok/stok_screen.dart';
import '../features/transaksi/transaksi_screen.dart';
import '../features/laporan/laporan_keuangan_screen.dart';
import '../features/laporan/laporan_screen.dart';
import '../features/laporan/rincian_penjualan_screen.dart';
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

      // Gerbang lisensi hanya aktif kalau server aktivasi sudah diisi.
      // Selama activationServerUrl masih 'ISI_...' aplikasi boleh dipakai
      // tanpa aktivasi supaya fitur bisa diuji. Begitu alamatnya diisi,
      // gerbang ini otomatis aktif kembali — jadi build yang dijual tetap
      // wajib aktivasi.
      final licenseGateActive = AppConfig.isActivationConfigured;

      // Belum berlisensi → wajib aktivasi lebih dulu.
      if (licenseGateActive && !licenseState.isLicensed) {
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
      // Halaman detail (tanpa bottom nav) — dibuka dengan tombol kembali.
      GoRoute(
        path: '/hutang',
        name: 'hutang',
        builder: (context, state) => const HutangScreen(),
      ),
      GoRoute(
        path: '/hutang/tambah',
        name: 'hutangTambah',
        builder: (context, state) => const HutangFormScreen(),
      ),
      GoRoute(
        path: '/hutang/edit',
        name: 'hutangEdit',
        builder: (context, state) =>
            HutangFormScreen(debt: state.extra as DebtModel?),
      ),
      GoRoute(
        path: '/catatan',
        name: 'catatan',
        builder: (context, state) => const CatatanScreen(),
      ),
      GoRoute(
        path: '/catatan/tambah',
        name: 'catatanTambah',
        builder: (context, state) => const CatatanFormScreen(),
      ),
      GoRoute(
        path: '/catatan/edit',
        name: 'catatanEdit',
        builder: (context, state) =>
            CatatanFormScreen(note: state.extra as NoteModel?),
      ),
      GoRoute(
        path: '/profile/toko',
        name: 'storeInfo',
        builder: (context, state) => const StoreInfoScreen(),
      ),
      GoRoute(
        path: '/profile/pembayaran',
        name: 'paymentMethods',
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/profile/supplier',
        name: 'supplier',
        builder: (context, state) => const SupplierScreen(),
      ),
      // Kas & riwayat uang masuk/keluar.
      GoRoute(
        path: '/kas',
        name: 'kas',
        builder: (context, state) => const KasScreen(),
      ),
      // Detail transaksi (hari ini / minggu / bulan).
      GoRoute(
        path: '/transaksi',
        name: 'transaksi',
        builder: (context, state) => const TransaksiScreen(),
      ),
      // Detail produk yang stoknya menipis / habis.
      GoRoute(
        path: '/stok/menipis',
        name: 'stokMenipis',
        builder: (context, state) => const StokMenipisScreen(),
      ),
      // Rincian produk terjual (filter harian + ekspor PDF/CSV).
      GoRoute(
        path: '/laporan/rincian',
        name: 'laporanRincian',
        builder: (context, state) => RincianPenjualanScreen(
          initialPeriod: state.extra as ReportPeriod?,
        ),
      ),
      // Laporan keuangan standar akuntansi (laba rugi, ekuitas, neraca, arus kas).
      GoRoute(
        path: '/laporan/keuangan',
        name: 'laporanKeuangan',
        builder: (context, state) => const LaporanKeuanganScreen(),
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
    // Alamat yang tidak dikenal tetap punya jalan keluar, jadi tombol
    // kembali Android maupun tombol di layar tidak menemui jalan buntu.
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 14),
              const Text(
                'Halaman tidak ditemukan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.uri.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Kembali ke Beranda'),
              ),
            ],
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
