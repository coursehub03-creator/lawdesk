import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/witness_supabase_service.dart';
import '../database/witness_db.dart';
import '../model/witness_model.dart';

class AddWitnessForm extends StatefulWidget {
  final int caseId;
  final String firebaseCaseId;

  const AddWitnessForm({
    super.key,
    required this.caseId,
    required this.firebaseCaseId,
  });

  @override
  State<AddWitnessForm> createState() => _AddWitnessFormState();
}

class _AddWitnessFormState extends State<AddWitnessForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _notesController = TextEditingController();

  bool _saving = false;

  static const Uuid _uuid = Uuid();

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _relationshipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final witness = WitnessModel(
      firebaseId: _uuid.v4(),
      caseId: widget.caseId,
      firebaseCaseId: widget.firebaseCaseId,
      name: _nameController.text.trim(),
      role: _roleController.text.trim().isEmpty ? 'witness' : _roleController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      relationship: _relationshipController.text.trim().isEmpty ? null : _relationshipController.text.trim(),
      isSynced: false,
    );

    try {
      final localId = await WitnessDB.insertWitness(witness);

      // Try cloud upsert immediately (best UX). If it fails, it stays unsynced locally.
      try {
        await WitnessSupabaseService.upsertWitness(witness);
        await WitnessDB.markWitnessAsSynced(localId);
      } catch (_) {
        // Keep unsynced locally.
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ الشاهد محليًا: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'اسم الشاهد'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _roleController,
            decoration: const InputDecoration(labelText: 'الصفة / الدور'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'الدور مطلوب' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _relationshipController,
            decoration: const InputDecoration(labelText: 'العلاقة'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '...جارٍ الحفظ' : 'حفظ'),
          ),
        ],
      ),
    );
  }
}
