import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/sell/sell_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/app_localizations.dart';

final appRouter = GoRouter(
  initialLocation: '/sell',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/sell', builder: (_, _) => const SellScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/inventory',
              builder: (_, _) => const InventoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/orders', builder: (_, _) => const OrdersScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/invoices', builder: (_, _) => const InvoicesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/analytics',
              builder: (_, _) => const AnalyticsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/settings', builder: (_, _) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Tablet (wide) → rail; phone → bottom bar.
    final isWide = MediaQuery.sizeOf(context).width >= 640;

    final destinations = <_Dest>[
      _Dest(Icons.point_of_sale, l.navSell),
      _Dest(Icons.inventory_2, l.navInventory),
      _Dest(Icons.dashboard_customize_outlined, l.navOrders),
      _Dest(Icons.receipt_long, l.navInvoices),
      _Dest(Icons.bar_chart, l.navAnalytics),
      _Dest(Icons.settings, l.navSettings),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

class _Dest {
  final IconData icon;
  final String label;
  const _Dest(this.icon, this.label);
}
