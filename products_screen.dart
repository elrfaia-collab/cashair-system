import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  final _searchCtrl = TextEditingController();
  int? _selectedCategory;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prods = await DatabaseHelper.instance.getProducts(search: _searchCtrl.text, categoryId: _selectedCategory);
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() { _products = prods; _categories = cats; _loading = false; });
  }

  Future<void> _showProductDialog([Map<String, dynamic>? product]) async {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final barcodeCtrl = TextEditingController(text: product?['barcode'] ?? '');
    final purchaseCtrl = TextEditingController(text: product?['purchase_price']?.toString() ?? '0');
    final priceCtrl = TextEditingController(text: product?['sale_price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?['stock_quantity']?.toString() ?? '0');
    final minStockCtrl = TextEditingController(text: product?['min_stock']?.toString() ?? '5');
    final descCtrl = TextEditingController(text: product?['description'] ?? '');
    int? catId = product?['category_id'];
    String unit = product?['unit'] ?? 'قطعة';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEdit ? 'تعديل منتج' : 'إضافة منتج جديد',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: TextFormField(controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'اسم المنتج *'),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: barcodeCtrl,
                        decoration: const InputDecoration(labelText: 'الباركود', prefixIcon: Icon(Icons.barcode_reader)))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<int>(
                        value: catId,
                        decoration: const InputDecoration(labelText: 'الفئة'),
                        items: _categories.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name']))).toList(),
                        onChanged: (v) => setS(() => catId = v),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(labelText: 'الوحدة'),
                        items: ['قطعة','كيلو','جرام','لتر','مل','علبة','كرتون','دستة']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setS(() => unit = v!),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(controller: purchaseCtrl,
                        decoration: const InputDecoration(labelText: 'سعر الشراء'),
                        keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: priceCtrl,
                        decoration: const InputDecoration(labelText: 'سعر البيع *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v!.isEmpty || double.tryParse(v) == null) ? 'مطلوب' : null)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(controller: stockCtrl,
                        decoration: const InputDecoration(labelText: 'الكمية'),
                        keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: minStockCtrl,
                        decoration: const InputDecoration(labelText: 'حد التنبيه'),
                        keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(controller: descCtrl, maxLines: 2,
                      decoration: const InputDecoration(labelText: 'وصف اختياري')),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final data = {
                              'name': nameCtrl.text.trim(),
                              'barcode': barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                              'category_id': catId,
                              'unit': unit,
                              'purchase_price': double.tryParse(purchaseCtrl.text) ?? 0,
                              'sale_price': double.parse(priceCtrl.text),
                              'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                              'min_stock': int.tryParse(minStockCtrl.text) ?? 5,
                              'description': descCtrl.text.trim(),
                            };
                            if (isEdit) {
                              await DatabaseHelper.instance.updateProduct(product['id'], data);
                            } else {
                              await DatabaseHelper.instance.insertProduct(data);
                            }
                            Navigator.pop(ctx);
                            _load();
                          },
                          child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة المنتج'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف منتج'),
        content: Text('هل تريد حذف "${product['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(product['id']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        actions: [
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: () => _showProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('منتج جديد'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(labelText: 'بحث بالاسم أو الباركود', prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => _load(),
                )),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: DropdownButtonFormField<int?>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('كل الفئات')),
                    ..._categories.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name']))),
                  ],
                  onChanged: (v) { setState(() => _selectedCategory = v); _load(); },
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_products.length} منتج', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات', style: TextStyle(color: AppTheme.textSecondary)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Table(
                          border: TableBorder.all(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(8)),
                          columnWidths: const {
                            0: FixedColumnWidth(120),
                            1: FlexColumnWidth(3),
                            2: FlexColumnWidth(2),
                            3: FixedColumnWidth(100),
                            4: FixedColumnWidth(100),
                            5: FixedColumnWidth(80),
                            6: FixedColumnWidth(80),
                            7: FixedColumnWidth(100),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: AppTheme.primaryColor),
                              children: ['الباركود','الاسم','الفئة','سعر الشراء','سعر البيع','المخزون','الوحدة','إجراءات']
                                .map((h) => Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(h, textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                )).toList(),
                            ),
                            ..._products.map((p) {
                              final low = (p['stock_quantity'] as int) <= (p['min_stock'] as int? ?? 5);
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: low ? AppTheme.dangerColor.withOpacity(0.05) : Colors.white,
                                ),
                                children: [
                                  _cell(p['barcode'] ?? '-', small: true),
                                  _cell(p['name'], bold: true),
                                  _cell(p['category_name'] ?? '-'),
                                  _cell('${fmt.format(p['purchase_price'])} ج.م'),
                                  _cell('${fmt.format(p['sale_price'])} ج.م', color: AppTheme.secondaryColor),
                                  _cell('${p['stock_quantity']}', color: low ? AppTheme.dangerColor : AppTheme.textPrimary, bold: low),
                                  _cell(p['unit'] ?? 'قطعة'),
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: isAdmin ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor), onPressed: () => _showProductDialog(p), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                        const SizedBox(width: 8),
                                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerColor), onPressed: () => _deleteProduct(p), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                      ],
                                    ) : const SizedBox(),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, bool small = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: small ? 11 : 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
    );
  }
}
