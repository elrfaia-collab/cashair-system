import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';
import '../widgets/receipt_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isReturn = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _searchCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final prods = await DatabaseHelper.instance.getProducts();
    setState(() {
      _products = prods;
      _filteredProducts = prods;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = query.isEmpty
          ? _products
          : _products.where((p) =>
              p['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
              (p['barcode'] ?? '').toString().contains(query)).toList();
    });
  }

  Future<void> _scanBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    final product = await DatabaseHelper.instance.getProductByBarcode(barcode.trim());
    if (product != null) {
      context.read<CartProvider>().addItem(product);
      _barcodeCtrl.clear();
    } else {
      _showError('الباركود غير موجود: $barcode');
      _barcodeCtrl.clear();
    }
    _barcodeFocus.requestFocus();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.dangerColor, duration: const Duration(seconds: 2)));
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) { _showError('السلة فارغة'); return; }

    final paidCtrl = TextEditingController(text: cart.total.toStringAsFixed(2));
    final discountCtrl = TextEditingController(text: cart.globalDiscount.toStringAsFixed(2));
    String payMethod = cart.paymentMethod;
    String custName = '';
    String custPhone = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(_isReturn ? 'تأكيد المرتجع' : 'إتمام عملية البيع',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _summaryRow('إجمالي المنتجات', cart.subtotal)),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: discountCtrl,
                  decoration: const InputDecoration(labelText: 'خصم إضافي', prefixText: 'ج.م '),
                  keyboardType: TextInputType.number,
                  onChanged: (v) { cart.setGlobalDiscount(double.tryParse(v) ?? 0); setS(() {}); },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: _summaryRow('الإجمالي النهائي', cart.total, bold: true, big: true),
                ),
                const SizedBox(height: 12),
                if (!_isReturn) ...[
                  DropdownButtonFormField<String>(
                    value: payMethod,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: ['كاش', 'بطاقة', 'تحويل'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) { payMethod = v!; cart.setPaymentMethod(v); },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: paidCtrl,
                    decoration: const InputDecoration(labelText: 'المبلغ المدفوع', prefixText: 'ج.م '),
                    keyboardType: TextInputType.number,
                    onChanged: (v) { cart.setPaidAmount(double.tryParse(v) ?? 0); setS(() {}); },
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('الباقي', (double.tryParse(paidCtrl.text) ?? 0) - cart.total),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'اسم العميل (اختياري)'),
                  onChanged: (v) => custName = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: _isReturn ? ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor) : null,
              onPressed: () async {
                Navigator.pop(ctx);
                await _processInvoice(custName, custPhone, payMethod,
                    double.tryParse(paidCtrl.text) ?? cart.total);
              },
              child: Text(_isReturn ? 'تأكيد المرتجع' : 'إتمام البيع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false, bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: big ? 16 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: AppTheme.textSecondary)),
        Text('${value.toStringAsFixed(2)} ج.م',
          style: TextStyle(fontSize: big ? 18 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: big ? AppTheme.primaryColor : AppTheme.textPrimary)),
      ],
    );
  }

  Future<void> _processInvoice(String custName, String custPhone, String payMethod, double paid) async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final invoiceNum = await DatabaseHelper.instance.generateInvoiceNumber();
    final invoice = {
      'invoice_number': invoiceNum,
      'type': _isReturn ? 'return' : 'sale',
      'customer_name': custName,
      'customer_phone': custPhone,
      'subtotal': cart.subtotal,
      'discount': cart.globalDiscount,
      'tax': 0.0,
      'total': cart.total,
      'paid_amount': paid,
      'change_amount': paid - cart.total,
      'payment_method': payMethod,
      'user_id': auth.userId,
    };
    final items = cart.items.map((i) => i.toMap()).toList();
    final invoiceId = await DatabaseHelper.instance.createInvoice(invoice, items);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          invoiceId: invoiceId,
          invoiceNumber: invoiceNum,
          invoice: invoice,
          items: items,
          cashierName: auth.userName,
        ),
      );
    }
    cart.clear();
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReturn ? '🔄 المرتجعات' : '🛒 نقطة البيع'),
        actions: [
          Switch(
            value: _isReturn,
            activeColor: AppTheme.warningColor,
            onChanged: (v) { setState(() => _isReturn = v); cart.clear(); },
          ),
          const Text('مرتجع  ', style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Products Panel
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Search + Barcode
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeCtrl,
                          focusNode: _barcodeFocus,
                          decoration: InputDecoration(
                            labelText: 'باركود - اضغط Enter للإضافة',
                            prefixIcon: const Icon(Icons.barcode_reader),
                            suffixIcon: IconButton(icon: const Icon(Icons.check), onPressed: () => _scanBarcode(_barcodeCtrl.text)),
                          ),
                          onSubmitted: _scanBarcode,
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(labelText: 'بحث بالاسم', prefixIcon: Icon(Icons.search)),
                          onChanged: _filterProducts,
                        ),
                      ),
                    ],
                  ),
                ),
                // Products Grid
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(child: Text('لا توجد منتجات', style: TextStyle(color: AppTheme.textSecondary)))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, childAspectRatio: 1.3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (_, i) {
                            final p = _filteredProducts[i];
                            final stock = p['stock_quantity'] as int;
                            final lowStock = stock <= (p['min_stock'] as int? ?? 5);
                            return InkWell(
                              onTap: () { if (stock > 0 || _isReturn) cart.addItem(p); else _showError('المنتج غير متاح في المخزون'); },
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2, color: stock == 0 ? Colors.grey : AppTheme.primaryColor, size: 28),
                                      const SizedBox(height: 4),
                                      Text(p['name'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text('${fmt.format(p['sale_price'])} ج.م',
                                        style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text('مخزون: $stock',
                                        style: TextStyle(fontSize: 10, color: lowStock ? AppTheme.dangerColor : AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Cart Panel
          Container(
            width: 340,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                // Cart Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isReturn ? AppTheme.warningColor : AppTheme.primaryColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_isReturn ? 'سلة المرتجع' : 'سلة المشتريات',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (cart.itemCount > 0)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () => cart.clear(),
                          tooltip: 'إفراغ السلة',
                        ),
                    ],
                  ),
                ),
                // Cart Items
                Expanded(
                  child: cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('السلة فارغة', style: TextStyle(color: Colors.grey[400])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: cart.items.length,
                          itemBuilder: (_, i) {
                            final item = cart.items[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(item.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis)),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: AppTheme.dangerColor),
                                          onPressed: () => cart.removeItem(item.productId),
                                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.dangerColor),
                                          onPressed: () => cart.updateQuantity(item.productId, item.quantity - 1),
                                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                        ),
                                        Container(
                                          width: 50,
                                          child: TextField(
                                            controller: TextEditingController(text: item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)),
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 4)),
                                            onSubmitted: (v) => cart.updateQuantity(item.productId, double.tryParse(v) ?? 1),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor),
                                          onPressed: () => cart.updateQuantity(item.productId, item.quantity + 1),
                                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                        ),
                                        const Spacer(),
                                        Text('${fmt.format(item.total)} ج.م',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                      ],
                                    ),
                                    Text('${fmt.format(item.unitPrice)} ج.م × ${item.quantity}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Cart Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('عدد الأصناف: ${cart.itemCount}', style: const TextStyle(color: AppTheme.textSecondary)),
                          Text('الإجمالي:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${fmt.format(cart.subtotal)} ج.م',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: cart.isEmpty ? null : _checkout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isReturn ? AppTheme.warningColor : AppTheme.secondaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(_isReturn ? Icons.assignment_return : Icons.check_circle_outline),
                          label: Text(_isReturn ? 'تأكيد المرتجع' : 'إتمام البيع', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
