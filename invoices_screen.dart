import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';
import '../widgets/receipt_dialog.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String _dateFrom = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30)));
  String _dateTo = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _type;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _type = _tabCtrl.index == 0 ? null : _tabCtrl.index == 1 ? 'sale' : 'return');
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoices = await DatabaseHelper.instance.getInvoices(
      dateFrom: _dateFrom, dateTo: _dateTo, type: _type);
    setState(() { _invoices = invoices; _loading = false; });
  }

  Future<void> _viewInvoice(Map<String, dynamic> invoice) async {
    final items = await DatabaseHelper.instance.getInvoiceItems(invoice['id']);
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          invoiceId: invoice['id'],
          invoiceNumber: invoice['invoice_number'],
          invoice: invoice,
          items: items,
          cashierName: invoice['cashier_name'] ?? '',
        ),
      );
    }
  }

  double get _totalSales {
    return _invoices.where((i) => i['type'] == 'sale').fold(0, (s, i) => s + (i['total'] as num));
  }

  double get _totalReturns {
    return _invoices.where((i) => i['type'] == 'return').fold(0, (s, i) => s + (i['total'] as num));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'الكل'), Tab(text: 'مبيعات'), Tab(text: 'مرتجعات')],
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text('من: ', style: TextStyle(fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context,
                      initialDate: DateTime.parse(_dateFrom), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) { setState(() => _dateFrom = DateFormat('yyyy-MM-dd').format(d)); _load(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Text(_dateFrom),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('إلى: ', style: TextStyle(fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context,
                      initialDate: DateTime.parse(_dateTo), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) { setState(() => _dateTo = DateFormat('yyyy-MM-dd').format(d)); _load(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Text(_dateTo),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('تحديث')),
              ],
            ),
          ),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              _statCard('إجمالي الفواتير', '${_invoices.length}', Icons.receipt, AppTheme.primaryColor),
              const SizedBox(width: 12),
              _statCard('إجمالي المبيعات', '${fmt.format(_totalSales)} ج.م', Icons.trending_up, AppTheme.secondaryColor),
              const SizedBox(width: 12),
              _statCard('إجمالي المرتجعات', '${fmt.format(_totalReturns)} ج.م', Icons.assignment_return, AppTheme.warningColor),
              const SizedBox(width: 12),
              _statCard('الصافي', '${fmt.format(_totalSales - _totalReturns)} ج.م', Icons.account_balance_wallet, AppTheme.primaryColor),
            ]),
          ),
          // Table
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTable(fmt),
                _buildTable(fmt, type: 'sale'),
                _buildTable(fmt, type: 'return'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ])),
        ]),
      ),
    ));
  }

  Widget _buildTable(NumberFormat fmt, {String? type}) {
    final filtered = type == null ? _invoices : _invoices.where((i) => i['type'] == type).toList();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (filtered.isEmpty) return const Center(child: Text('لا توجد فواتير', style: TextStyle(color: AppTheme.textSecondary)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE5E7EB)),
        columnWidths: const {
          0: FixedColumnWidth(140),
          1: FixedColumnWidth(80),
          2: FlexColumnWidth(2),
          3: FixedColumnWidth(100),
          4: FixedColumnWidth(120),
          5: FixedColumnWidth(100),
          6: FixedColumnWidth(80),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            children: ['رقم الفاتورة','النوع','العميل','الإجمالي','التاريخ','الكاشير','عرض']
              .map((h) => Padding(padding: const EdgeInsets.all(10),
                child: Text(h, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
          ),
          ...filtered.map((inv) => TableRow(
            decoration: BoxDecoration(color: inv['type'] == 'return' ? AppTheme.warningColor.withOpacity(0.05) : Colors.white),
            children: [
              _cell(inv['invoice_number'] ?? ''),
              _cell(inv['type'] == 'sale' ? 'بيع' : 'مرتجع',
                color: inv['type'] == 'sale' ? AppTheme.secondaryColor : AppTheme.warningColor, bold: true),
              _cell(inv['customer_name'] ?? '-'),
              _cell('${fmt.format(inv['total'])} ج.م', bold: true),
              _cell(DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(inv['created_at']))),
              _cell(inv['cashier_name'] ?? '-'),
              Padding(padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryColor, size: 20),
                  onPressed: () => _viewInvoice(inv),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                )),
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
