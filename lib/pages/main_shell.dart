import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'home_page.dart';

/// The frame of the app: a bottom bar to switch between the pages.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Only the current page is built. When you come back to a tab, it is
    // created again, so it always loads fresh data.
    final Widget page = _index == 0 ? const DashboardPage() : const HomePage();

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
        ],
      ),
    );
  }
}