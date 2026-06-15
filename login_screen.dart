import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_usernameCtrl.text, _passwordCtrl.text);
    if (success && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else if (mounted) {
      setState(() => _error = 'اسم المستخدم أو كلمة المرور غير صحيحة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30)],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.point_of_sale, color: Colors.white, size: 45),
                ),
                const SizedBox(height: 20),
                const Text('نظام الكاشير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Text('تسجيل الدخول', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline)),
                  textAlign: TextAlign.right,
                  validator: (v) => v!.isEmpty ? 'أدخل اسم المستخدم' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textAlign: TextAlign.right,
                  validator: (v) => v!.isEmpty ? 'أدخل كلمة المرور' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 18),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 13)),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      child: auth.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('دخول', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('مدير: admin / admin123', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                Text('كاشير: cashier / cashier123', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
