import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'invoices_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<_NavItem> get _navItems {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    return [
      _NavItem('نقطة البيع', Icons.point_of_sale, const PosScreen()),
      _NavItem('المنتجات', Icons.inventory_2_outlined, const ProductsScreen()),
      _NavItem('الفواتير', Icons.receipt_long_outlined, const InvoicesScreen()),
      _NavItem('المخزون', Icons.warehouse_outlined, const InventoryScreen()),
      _NavItem('التقارير', Icons.bar_chart_outlined, const ReportsScreen()),
      if (isAdmin) _NavItem('المستخدمين', Icons.people_outline, const UsersScreen()),
      if (isAdmin) _NavItem('الإعدادات', Icons.settings_outlined, const SettingsScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = _navItems;
    if (_selectedIndex >= items.length) _selectedIndex = 0;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1D2E),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.point_of_sale, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 10),
                    const Text('نظام الكاشير', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(auth.userName, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: auth.isAdmin ? AppTheme.warningColor : AppTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        auth.isAdmin ? 'مدير' : 'كاشير',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                // Nav Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final selected = _selectedIndex == i;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: Icon(items[i].icon, color: selected ? Colors.white : Colors.white54, size: 22),
                          title: Text(items[i].label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onTap: () => setState(() => _selectedIndex = i),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                // Logout
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout, color: AppTheme.dangerColor, size: 22),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.dangerColor, fontSize: 14)),
                  onTap: () {
                    auth.logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Main Content
          Expanded(child: items[_selectedIndex].screen),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  _NavItem(this.label, this.icon, this.screen);
}
