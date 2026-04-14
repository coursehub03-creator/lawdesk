import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class ResetPinScreen extends StatefulWidget {
  final String email; // البريد الإلكتروني المؤكد

  const ResetPinScreen({super.key, required this.email});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _resetPin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin != confirmPin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رمزا PIN غير متطابقين')));
      return;
    }

    setState(() => _saving = true);

    final db = await DBHelper.database;
    await db.update(
      'users',
      {'pin': pin},
      where: 'username = ?',
      whereArgs: ['admin'],
    );

    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تحديث رمز PIN بنجاح')));
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إعادة تعيين رمز PIN')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'رمز PIN الجديد'),
                validator:
                    (val) =>
                        val == null || val.length != 4
                            ? 'أدخل رمزًا مكونًا من 4 أرقام'
                            : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'تأكيد رمز PIN'),
                validator:
                    (val) =>
                        val == null || val.length != 4
                            ? 'أدخل نفس رمز PIN مرة أخرى'
                            : null,
              ),

              const SizedBox(height: 30),
              _saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _resetPin();
                      }
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('تحديث رمز PIN'),
                  ),
              const SnackBar(
                content: Text(
                  'تم تحديث رمز PIN بنجاح. يمكنك الآن تسجيل الدخول باستخدامه',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
