import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _dailyReport;
  List<Map<String, dynamic>> _weeklyData = [];
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadReports(); }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final daily = await DatabaseHelper.instance.getDailyReport(_selectedDate);
    // Weekly data
    final db = await DatabaseHelper.instance.database;
    final weekly = await db.rawQuery('''
      SELECT DATE(created_at) as date, 
             COALESCE(SUM(CASE WHEN type='sale' THEN total ELSE 0 END),0) as sales,
             COALESCE(SUM(CASE WHEN type='return' THEN total ELSE 0 END),0) as returns
      FROM invoices 
      WHERE DATE(created_at) >= DATE('now','-6 days')
      GROUP BY DATE(created_at)
      ORDER BY date
    ''');
    setState(() { _dailyReport = daily; _weeklyData = weekly; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والإحصائيات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selector
                  Row(children: [
                    const Text('التقرير اليومي: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context,
                          initialDate: DateTime.parse(_selectedDate), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) {
                          setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(d));
                          _loadReports();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(_selectedDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loadReports,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('تحديث'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // Daily Summary Cards
                  if (_dailyReport != null) ...[
                    Row(children: [
                      _statCard('المبيعات', '${_dailyReport!['sales']['count']}', 'فاتورة',
                        '${fmt.format(_dailyReport!['sales']['total'])} ج.م', Icons.point_of_sale, AppTheme.primaryColor),
                      const SizedBox(width: 16),
                      _statCard('المرتجعات', '${_dailyReport!['returns']['count']}', 'مرتجع',
                        '${fmt.format(_dailyReport!['returns']['total'])} ج.م', Icons.assignment_return, AppTheme.warningColor),
                      const SizedBox(width: 16),
                      _statCard('صافي الإيرادات', '', 'اليوم',
                        '${fmt.format(_dailyReport!['net'])} ج.م', Icons.account_balance_wallet, AppTheme.secondaryColor),
                      const SizedBox(width: 16),
                      _statCard('الخصومات', '', 'إجمالي',
                        '${fmt.format(_dailyReport!['sales']['discount'])} ج.م', Icons.discount_outlined, AppTheme.dangerColor),
                    ]),
                    const SizedBox(height: 24),
                    // Weekly Chart
                    if (_weeklyData.isNotEmpty) Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('مبيعات آخر 7 أيام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: BarChart(BarChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60,
                                    getTitlesWidget: (v, _) => Text(fmt.format(v), style: const TextStyle(fontSize: 10)))),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                                    getTitlesWidget: (v, _) {
                                      final idx = v.toInt();
                                      if (idx < 0 || idx >= _weeklyData.length) return const Text('');
                                      final date = _weeklyData[idx]['date'] as String;
                                      return Text(date.substring(5), style: const TextStyle(fontSize: 10));
                                    })),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _weeklyData.asMap().entries.map((e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(toY: (e.value['sales'] as num).toDouble(), color: AppTheme.primaryColor, width: 16, borderRadius: BorderRadius.circular(4)),
                                    BarChartRodData(toY: (e.value['returns'] as num).toDouble(), color: AppTheme.warningColor, width: 16, borderRadius: BorderRadius.circular(4)),
                                  ],
                                )).toList(),
                              )),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              _legend('مبيعات', AppTheme.primaryColor),
                              const SizedBox(width: 16),
                              _legend('مرتجعات', AppTheme.warningColor),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Top Products
                    if ((_dailyReport!['top_products'] as List).isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أكثر المنتجات مبيعاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Table(
                                border: TableBorder.all(color: const Color(0xFFE5E7EB)),
                                columnWidths: const {0: FixedColumnWidth(30), 1: FlexColumnWidth(3), 2: FixedColumnWidth(80), 3: FixedColumnWidth(120)},
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                                    children: ['#','المنتج','الكمية','الإيرادات']
                                      .map((h) => Padding(padding: const EdgeInsets.all(8),
                                        child: Text(h, textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
                                  ),
                                  ...(_dailyReport!['top_products'] as List).asMap().entries.map((e) {
                                    final p = e.value as Map;
                                    return TableRow(children: [
                                      Padding(padding: const EdgeInsets.all(8),
                                        child: Text('${e.key + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(8),
                                        child: Text(p['product_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                      Padding(padding: const EdgeInsets.all(8),
                                        child: Text('${p['qty']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(8),
                                        child: Text('${fmt.format(p['total'])} ج.م', textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold))),
                                    ]);
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, String count, String subtitle, String amount, IconData icon, Color color) {
    return Expanded(child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 10),
          if (count.isNotEmpty)
            Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    ));
  }

  Widget _legend(String label, Color color) {
    return Row(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
