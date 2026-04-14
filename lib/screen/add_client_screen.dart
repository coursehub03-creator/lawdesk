import 'package:flutter/material.dart';
import '../model/client_model.dart' as model;
import '../core/client_supabase_service.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => AddClientScreenState();
}

class AddClientScreenState extends State<AddClientScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();

  bool _isSaving = false;

  Future<void> saveClient() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final notes = notesController.text.trim();
    final address = addressController.text.trim();

    if (name.isEmpty) {
      _showMessage('الرجاء إدخال الاسم');
      return;
    }

    setState(() => _isSaving = true);

    final client = model.Client(
      // ✅ لا تولد UUID محلياً: Supabase هو مصدر الحقيقة وسيُرجع id.
      id: '',
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      address: address,
    );

    // ✅ Online-first (وإذا فشل يحفظ محلياً كـ Unsynced)
    final saved = await ClientSupabaseService.addClient(client);

    if (!mounted) return;
    _showMessage(saved.isSynced ? 'تم حفظ العميل على السحابة والمحلي' : 'تم حفظ العميل محليًا وسيُرفع لاحقاً');
    setState(() => _isSaving = false);
    Navigator.pop(context, true);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('إضافة عميل')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            _buildTextField(nameController, 'الاسم'),
            const SizedBox(height: 12),
            _buildTextField(phoneController, 'رقم الهاتف'),
            const SizedBox(height: 12),
            _buildTextField(emailController, 'البريد الإلكتروني'),
            const SizedBox(height: 12),
            _buildTextField(notesController, 'ملاحظات'),
            const SizedBox(height: 12),
            _buildTextField(addressController, 'العنوان'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : saveClient,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ العميل'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
