import 'package:flutter/material.dart';
import 'dart:io';

import '../model/client_model.dart' as model;
import '../core/client_supabase_service.dart';
import '../database/client_db.dart' as local;
import '../local/local_db.dart';

class EditClientScreen extends StatefulWidget {
  final model.Client client;

  const EditClientScreen({super.key, required this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController notesController;
  late TextEditingController addressController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.client.name);
    phoneController = TextEditingController(text: widget.client.phone);
    emailController = TextEditingController(text: widget.client.email);
    notesController = TextEditingController(text: widget.client.notes);
    addressController = TextEditingController(text: widget.client.address);
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateClient() async {
  try {
    final updatedClient = model.Client(
      id: widget.client.id,
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      notes: notesController.text.trim(),
      address: addressController.text.trim(),
    );

    // تحديث محلي
    await local.ClientDB.updateClient(updatedClient);

    // تحديث على Supabase
    await ClientSupabaseService.updateClient(updatedClient);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث العميل بنجاح')),
    );
    Navigator.pop(context, true);
  } catch (e, stack) {
    debugPrint("❌ خطأ أثناء تحديث العميل: $e");
    debugPrint("StackTrace: $stack");

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشل تحديث العميل: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل العميل')),
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
              onPressed: _updateClient,
              icon: const Icon(Icons.save),
              label: const Text('تحديث البيانات'),
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
