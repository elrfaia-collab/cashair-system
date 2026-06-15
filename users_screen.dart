import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../utils/app_theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await DatabaseHelper.instance.getUsers();
    setState(() { _users = users; _loading = false; });
  }

  Future<void> _showUserDialog([Map<String, dynamic>? user]) async {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    final passCtrl = TextEditingController();
    String role = user?['role'] ?? 'cashier';
    bool isActive = (user?['is_active'] ?? 1) == 1;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                TextFormField(controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم *'),
                  enabled: !isEdit,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                TextFormField(controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: isEdit ? 'كلمة المرور الجديدة (اتركها فارغة للاحتفاظ بالحالية)' : 'كلمة المرور *'),
                  validator: (v) => !isEdit && v!.isEmpty ? 'مطلوب' : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('مدير')),
                    DropdownMenuItem(value: 'cashier', child: Text('كاشير')),
                  ],
                  onChanged: (v) => setS(() => role = v!),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('حساب نشط'),
                    value: isActive,
                    onChanged: (v) => setS(() => isActive = v),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'full_name': nameCtrl.text.trim(),
                  'role': role,
                  'is_active': isActive ? 1 : 0,
                };
                if (!isEdit) data['username'] = usernameCtrl.text.trim() as dynamic;
                if (passCtrl.text.isNotEmpty) data['password'] = passCtrl.text as dynamic;
                if (isEdit) {
                  await DatabaseHelper.instance.updateUser(user['id'], data);
                } else {
                  await DatabaseHelper.instance.insertUser({
                    ...data, 'username': usernameCtrl.text.trim(), 'password': passCtrl.text,
                  });
                }
                Navigator.pop(ctx);
                _load();
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
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
        title: const Text('إدارة المستخدمين'),
        actions: [
          ElevatedButton.icon(
            onPressed: _showUserDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('مستخدم جديد'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final isAdmin = u['role'] == 'admin';
                final isActive = u['is_active'] == 1;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? AppTheme.warningColor : AppTheme.primaryColor,
                      child: Text(
                        (u['full_name'] as String? ?? u['username'] as String).substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(u['full_name'] ?? u['username'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('@${u['username']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin ? AppTheme.warningColor.withOpacity(0.15) : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(isAdmin ? 'مدير' : 'كاشير',
                          style: TextStyle(fontSize: 12, color: isAdmin ? AppTheme.warningColor : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.secondaryColor.withOpacity(0.1) : AppTheme.dangerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(isActive ? 'نشط' : 'موقوف',
                          style: TextStyle(fontSize: 12, color: isActive ? AppTheme.secondaryColor : AppTheme.dangerColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor), onPressed: () => _showUserDialog(u)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
