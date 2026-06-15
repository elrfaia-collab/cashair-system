import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _lowStock = [];
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final prods = await db.getProducts(search: _searchCtrl.text);
    final low = await db.getLowStockProducts();
    final movements = await (await db.database).rawQuery('''
      SELECT sm.*, p.name as product_name, u.full_name as user_name
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      LEFT JOIN users u ON sm.user_id = u.id
      ORDER BY sm.created_at DESC LIMIT 100
    ''');
    setState(() { _products = prods; _lowStock = low; _movements = movements; _loading = false; });
  }

  Future<void> _adjustStock(Map<String, dynamic> product) async {
    final qtyCtrl = TextEditingController();
    String type = 'in';
    String notes = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تعديل مخزون: ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المخزون الحالي: ${product['stock_quantity']} ${product['unit'] ?? 'قطعة'}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ChoiceChip(
                  label: const Text('إضافة للمخزون'),
                  selected: type == 'in',
                  selectedColor: AppTheme.secondaryColor,
                  labelStyle: TextStyle(color: type == 'in' ? Colors.white : AppTheme.textPrimary),
                  onSelected: (_) => setS(() => type = 'in'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ChoiceChip(
                  label: const Text('خصم من المخزون'),
                  selected: type == 'out',
                  selectedColor: AppTheme.dangerColor,
                  labelStyle: TextStyle(color: type == 'out' ? Colors.white : AppTheme.textPrimary),
                  onSelected: (_) => setS(() => type = 'out'),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'الكمية *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                onChanged: (v) => notes = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text);
                if (qty == null || qty <= 0) return;
                await DatabaseHelper.instance.updateStock(
                  product['id'], qty, type, notes: notes.isEmpty ? null : notes);
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'كل المنتجات (${_products.length})'),
            Tab(text: 'تنبيهات المخزون (${_lowStock.length})'),
            const Tab(text: 'حركات المخزون'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // All Products
          _buildAllProducts(),
          // Low Stock
          _buildLowStock(),
          // Movements
          _buildMovements(),
        ],
      ),
    );
  }

  Widget _buildAllProducts() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(labelText: 'بحث', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => _load(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Table(
                    border: TableBorder.all(color: const Color(0xFFE5E7EB)),
                    columnWidths: const {
                      0: FlexColumnWidth(3), 1: FlexColumnWidth(2),
                      2: FixedColumnWidth(100), 3: FixedColumnWidth(100),
                      4: FixedColumnWidth(80), 5: FixedColumnWidth(80),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.primaryColor),
                        children: ['المنتج','الفئة','المخزون','الحد الأدنى','الوحدة','تعديل']
                          .map((h) => Padding(padding: const EdgeInsets.all(10),
                            child: Text(h, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
                      ),
                      ..._products.map((p) {
                        final low = (p['stock_quantity'] as int) <= (p['min_stock'] as int? ?? 5);
                        return TableRow(
                          decoration: BoxDecoration(color: low ? AppTheme.dangerColor.withOpacity(0.07) : Colors.white),
                          children: [
                            _cell(p['name'], bold: true),
                            _cell(p['category_name'] ?? '-'),
                            _cell('${p['stock_quantity']}', color: low ? AppTheme.dangerColor : AppTheme.secondaryColor, bold: true),
                            _cell('${p['min_stock'] ?? 5}'),
                            _cell(p['unit'] ?? 'قطعة'),
                            Padding(padding: const EdgeInsets.all(4),
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                                onPressed: () => _adjustStock(p),
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              )),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLowStock() {
    if (_lowStock.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 64, color: AppTheme.secondaryColor),
          SizedBox(height: 12),
          Text('المخزون بحالة جيدة', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lowStock.length,
      itemBuilder: (_, i) {
        final p = _lowStock[i];
        final stock = p['stock_quantity'] as int;
        return Card(
          color: stock == 0 ? AppTheme.dangerColor.withOpacity(0.05) : AppTheme.warningColor.withOpacity(0.05),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: stock == 0 ? AppTheme.dangerColor : AppTheme.warningColor,
              child: Text('$stock', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الحد الأدنى: ${p['min_stock'] ?? 5} ${p['unit'] ?? 'قطعة'}'),
            trailing: ElevatedButton.icon(
              onPressed: () => _adjustStock(p),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مخزون'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovements() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE5E7EB)),
        columnWidths: const {
          0: FlexColumnWidth(3), 1: FixedColumnWidth(80),
          2: FixedColumnWidth(80), 3: FixedColumnWidth(80),
          4: FixedColumnWidth(80), 5: FlexColumnWidth(2),
          6: FixedColumnWidth(130),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            children: ['المنتج','النوع','الكمية','قبل','بعد','المستخدم','التاريخ']
              .map((h) => Padding(padding: const EdgeInsets.all(10),
                child: Text(h, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
          ),
          ..._movements.map((m) => TableRow(
            decoration: BoxDecoration(color: m['movement_type'] == 'in' ? AppTheme.secondaryColor.withOpacity(0.05) : AppTheme.dangerColor.withOpacity(0.05)),
            children: [
              _cell(m['product_name'] ?? '-'),
              _cell(m['movement_type'] == 'in' ? '↑ داخل' : '↓ خارج',
                color: m['movement_type'] == 'in' ? AppTheme.secondaryColor : AppTheme.dangerColor, bold: true),
              _cell('${m['quantity']}'),
              _cell('${m['before_quantity'] ?? '-'}'),
              _cell('${m['after_quantity'] ?? '-'}'),
              _cell(m['user_name'] ?? '-'),
              _cell(m['created_at'] != null
                ? DateFormat('MM/dd HH:mm').format(DateTime.parse(m['created_at'])) : '-'),
            ],
          )),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? AppTheme.textPrimary)),
    );
  }
}
