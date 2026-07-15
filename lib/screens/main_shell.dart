import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/finance_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import 'accounts_screen.dart';
import 'add_debt_screen.dart';
import 'add_transaction_screen.dart';
import 'analytics_screen.dart';
import 'balance_setup_screen.dart';
import 'contacts_screen.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'import_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import 'reconcile_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  void _onFabPressed() {
    if (_index == 3) {
      // Debts tab → open AddDebtScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AddDebtScreen(),
          fullscreenDialog: true,
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AddTransactionScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the home-screen widget's balance in sync with the latest total.
    final total = context.watch<FinanceService>().totalBalance;
    WidgetService.updateBalance(total);

    final pages = [
      HomeScreen(onSeeAllTransactions: () => _go(1)),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const DebtsScreen(),
      const GoalsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: AppTheme.light, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'finlytic',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.dark,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded),
            onSelected: (value) {
              if (value == 'dashboard') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DashboardScreen()));
              } else if (value == 'reconcile') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ReconcileScreen()));
              } else if (value == 'profile') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
              } else if (value == 'balance_setup') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BalanceSetupScreen()));
              } else if (value == 'import') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ImportScreen()));
              } else if (value == 'contacts') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ContactsScreen()));
              } else if (value == 'accounts') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AccountsScreen()));
              } else if (value == 'reminders') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_outlined, color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Dashboard',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reconcile',
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Reconcile with bank',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Profile',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'balance_setup',
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Balance Setup',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_rounded,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Import CSV',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contacts',
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Contacts',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Accounts',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reminders',
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppTheme.dark),
                    const SizedBox(width: 12),
                    Text('Reminders',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: pages[_index],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _index == 3 ? 'Add Debt' : 'New',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.lightGray)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _go,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Ledger',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.handshake_outlined),
              activeIcon: Icon(Icons.handshake_rounded),
              label: 'Debts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag_rounded),
              label: 'Goals',
            ),
          ],
        ),
      ),
    );
  }
}
