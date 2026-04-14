import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'pin_login_screen.dart';

class CreatePinScreen extends StatefulWidget {
  final String email;

  const CreatePinScreen({super.key, required this.email});

  @override
  State<CreatePinScreen> createState() => CreatePinScreenState();
}

class CreatePinScreenState extends State<CreatePinScreen> {
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _savePin() async {
    final pin = pinController.text.trim();
    final confirm = confirmPinController.text.trim();

    if (pin != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رمزا PIN غير متطابقين')));
      return;
    }

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يحتوي رمز PIN على 4 أرقام فقط')),
      );
      return;
    }

    setState(() => _saving = true);

    final db = await DBHelper.database;

    // تحقق مما إذا كان المستخدم موجودًا مسبقًا
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [widget.email],
    );

    if (result.isEmpty) {
      // المستخدم غير موجود
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('المستخدم غير مسجل محليًا')));
      setState(() => _saving = false);
      return;
    }

    // تحديث رمز PIN للمستخدم الحالي
    await db.update(
      'users',
      {'pin': pin},
      where: 'username = ?',
      whereArgs: [widget.email],
    );

    setState(() => _saving = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء رمز PIN')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'رمز PIN'),
                validator:
                    (val) =>
                        val == null ||
                                val.length != 4 ||
                                !RegExp(r'^\d{4}$').hasMatch(val)
                            ? 'الرجاء إدخال 4 أرقام'
                            : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'تأكيد رمز PIN'),
                validator:
                    (val) =>
                        val == null ||
                                val.length != 4 ||
                                !RegExp(r'^\d{4}$').hasMatch(val)
                            ? 'الرجاء تأكيد الرمز بأرقام فقط'
                            : null,
              ),
              const SizedBox(height: 30),
              _saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) _savePin();
                    },
                    icon: const Icon(Icons.lock),
                    label: const Text('حفظ'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
