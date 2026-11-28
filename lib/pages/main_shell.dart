
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'home_page.dart';
import 'members_page.dart';
import 'loans_page.dart';
import 'account_settings_page.dart';
import 'transaction_categories_page.dart';
import '../services/household_service.dart';

/// Kerangka utama aplikasi dengan navigasi berdasarkan peran pengguna.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Mengambil informasi rumah tangga dan peran pengguna.
  late final Future<Map<String, dynamic>?> _householdFuture;

  @override
  void initState() {
    super.initState();
    _householdFuture = HouseholdService.getMyHousehold();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _householdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal mengambil informasi rumah tangga.\n'
                  '${snapshot.error ?? ''}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        // Hanya Owner yang mendapatkan menu pengaturan.
        final isOwner = snapshot.data!['role'] == 'owner';

        // Menentukan halaman sesuai menu yang dipilih.
        final Widget page;

        if (_index == 0) {
          page = const DashboardPage();
        } else if (_index == 1) {
          page = const HomePage();
        } else if (_index == 2) {
          page = const LoansPage();
        } else if (_index == 3 && isOwner) {
          page = const MembersPage();
        } else if (_index == 4 && isOwner) {
          page = const AccountSettingsPage();
        } else if (_index == 5 && isOwner) {
          page = const TransactionCategoriesPage();
        } else {
          page = const DashboardPage();
        }

        return Scaffold(
          body: page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() {
                _index = i;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transaksi',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Utang & Piutang',
              ),

              // Menu Anggota hanya muncul untuk Owner.
              if (isOwner)
                const NavigationDestination(
                  icon: Icon(Icons.family_restroom_outlined),
                  selectedIcon: Icon(Icons.family_restroom),
                  label: 'Anggota',
                ),

              // Menu Pengaturan Akun hanya muncul untuk Owner.
              if (isOwner)
                const NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  selectedIcon: Icon(Icons.account_balance),
                  label: 'Akun',
                ),

              // Menu Pengaturan Kategori hanya muncul untuk Owner.
              if (isOwner)
                const NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: 'Kategori',
                ),
            ],
          ),
        );
      },
    );
  }
}
