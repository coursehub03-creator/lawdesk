import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import 'signup_screen.dart';
import 'password_reset_screen.dart';
import 'create_pin_screen.dart';
import 'pin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('يرجى إدخال البريد وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        _showMessage(
          'فشل تسجيل الدخول: المستخدم غير موجود أو كلمة المرور خاطئة',
        );
        return;
      }

      if (user.emailConfirmedAt == null) {
        _showMessage('يرجى تأكيد بريدك الإلكتروني أولاً');
        return;
      }

      final db = await DBHelper.database;
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [email],
      );

      // إذا لم يكن موجودًا، أضفه إلى جدول المستخدمين المحلي
      if (result.isEmpty) {
        await db.insert('users', {'username': email, 'pin': null});
        debugPrint('تم إدراج المستخدم في قاعدة البيانات المحلية');
      }

      // الانتقال حسب حالة رمز PIN
      final hasPin = result.isNotEmpty && result.first['pin'] != null;
      if (hasPin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CreatePinScreen(email: email)),
        );
      }
    } on AuthException catch (e) {
      _showMessage('فشل تسجيل الدخول: ${e.message}');
    } catch (e) {
      _showMessage('حدث خطأ غير متوقع: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PasswordResetScreen(
                              email: emailController.text.trim(),
                            ),
                      ),
                    ),
                child: const Text('هل نسيت كلمة المرور؟'),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const Text('تسجيل الدخول'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
              child: const Text('ليس لديك حساب؟ أنشئ حساب جديد'),
            ),
          ],
        ),
      ),
    );
  }
}
