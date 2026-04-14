import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import 'client_list_screen.dart';
import 'login_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isChecking = false;

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      _showMessage('أدخل رمز PIN مكون من 4 أرقام');
      return;
    }

    setState(() => _isChecking = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      _showMessage('الرجاء تسجيل الدخول بالبريد الإلكتروني أولاً');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final email = currentUser.email!;
    final db = await DBHelper.database;
    final result = await db.query(
      'users',
      where: 'username = ? AND pin = ?',
      whereArgs: [email, pin],
    );

    if (result.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ClientListScreen()),
      );
    } else {
      _showMessage('رمز PIN غير صحيح');
    }

    setState(() => _isChecking = false);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _navigateToEmailLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول برمز PIN')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'رمز PIN',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (val) =>
                        val == null || val.length != 4
                            ? 'أدخل رمز PIN صحيح'
                            : null,
              ),
              const SizedBox(height: 30),
              _isChecking
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) _verifyPin();
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('تسجيل الدخول'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _navigateToEmailLogin,
                child: const Text('تسجيل الدخول بالبريد الإلكتروني'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
