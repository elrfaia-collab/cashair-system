import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopAddressCtrl;
  late TextEditingController _shopPhoneCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _prefixCtrl;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await DatabaseHelper.instance.getSettings();
    _settings = settings;
    _shopNameCtrl = TextEditingController(text: settings['shop_name'] ?? '');
    _shopAddressCtrl = TextEditingController(text: settings['shop_address'] ?? '');
    _shopPhoneCtrl = TextEditingController(text: settings['shop_phone'] ?? '');
    _taxCtrl = TextEditingController(text: settings['tax_rate'] ?? '0');
    _currencyCtrl = TextEditingController(text: settings['currency'] ?? 'ج.م');
    _footerCtrl = TextEditingController(text: settings['receipt_footer'] ?? '');
    _prefixCtrl = TextEditingController(text: settings['invoice_prefix'] ?? 'INV');
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updates = {
      'shop_name': _shopNameCtrl.text,
      'shop_address': _shopAddressCtrl.text,
      'shop_phone': _shopPhoneCtrl.text,
      'tax_rate': _taxCtrl.text,
      'currency': _currencyCtrl.text,
      'receipt_footer': _footerCtrl.text,
      'invoice_prefix': _prefixCtrl.text,
    };
    for (var e in updates.entries) {
      await DatabaseHelper.instance.updateSetting(e.key, e.value);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات'), backgroundColor: AppTheme.secondaryColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
        actions: [
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: [
                      _section('معلومات المتجر', [
                        _field(_shopNameCtrl, 'اسم المتجر', Icons.store, required: true),
                        _field(_shopAddressCtrl, 'العنوان', Icons.location_on),
                        _field(_shopPhoneCtrl, 'رقم الهاتف', Icons.phone),
                      ])),
                      const SizedBox(height: 20),
                      _section('إعدادات الفواتير', [
                        _field(_prefixCtrl, 'بادئة رقم الفاتورة (مثال: INV)', Icons.tag),
                        _field(_taxCtrl, 'نسبة الضريبة (%)', Icons.percent, number: true),
                        _field(_currencyCtrl, 'العملة', Icons.currency_exchange),
                        _field(_footerCtrl, 'نص أسفل الإيصال', Icons.notes, maxLines: 3),
                      ])),
                    ])),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: Column(children: [
                      _section('معاينة الإيصال', [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            const Icon(Icons.receipt_long, size: 40, color: AppTheme.primaryColor),
                            const SizedBox(height: 8),
                            Text(_shopNameCtrl.text.isEmpty ? 'اسم المتجر' : _shopNameCtrl.text,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (_shopAddressCtrl.text.isNotEmpty)
                              Text(_shopAddressCtrl.text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            if (_shopPhoneCtrl.text.isNotEmpty)
                              Text('هاتف: ${_shopPhoneCtrl.text}', style: const TextStyle(fontSize: 12)),
                            const Divider(),
                            const Text('${_prefixCtrl_placeholder}-000001', style: TextStyle(fontSize: 11)),
                            const Divider(),
                            const Text('شكراً لزيارتكم', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ]),
                        ),
                      ])),
                    ])),
                  ],
                ),
              ),
            ),
    );
  }

  // Using a placeholder for preview since we can't reference the controller in a const context
  static const _prefixCtrl_placeholder = 'INV';

  Widget _section(String title, List<Widget> children) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 16),
        ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)),
      ]),
    ));
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, bool number = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required ? (v) => v!.isEmpty ? 'مطلوب' : null : null,
      onChanged: (_) => setState(() {}),
    );
  }
}
