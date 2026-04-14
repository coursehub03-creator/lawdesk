import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/evidence_storage_service.dart';
import '../core/evidence_supabase_service.dart';
import '../core/id.dart';
import '../database/evidence_db.dart' as local_db;
import '../model/evidence_model.dart';

class AddEvidenceScreen extends StatefulWidget {
  final int caseId; // Local SQLite case ID
  final String? firebaseCaseId; // Supabase case ID

  const AddEvidenceScreen({
    super.key,
    required this.caseId,
    this.firebaseCaseId,
  });

  @override
  State<AddEvidenceScreen> createState() => _AddEvidenceScreenState();
}

class _AddEvidenceScreenState extends State<AddEvidenceScreen> {
  final Logger _log = Logger();
  File? _selectedFile;

  final typeController = TextEditingController(text: 'document');
  final descriptionController = TextEditingController();

  String get _cloudCaseId => (widget.firebaseCaseId ?? '').trim();

  @override
  void dispose() {
    typeController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    setState(() => _selectedFile = File(path));
  }

  Future<File> _copyToAppFolder(File file, String evidenceId) async {
    // store next to DB path to keep it persistent across restarts (no temp)
    final dbPath = await getDatabasesPath();
    final dir = Directory(p.join(dbPath, 'lawdesk_files', 'evidence'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final base = p.basename(file.path);
    final target = File(p.join(dir.path, '${evidenceId}_$base'));
    if (await target.exists()) return target;

    return await file.copy(target.path);
  }

  Future<void> _saveEvidence() async {
    if (_cloudCaseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إضافة دليل بدون معرف القضية السحابي')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ملفًا أولاً')),
      );
      return;
    }

    final id = generateId();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // copy locally for persistence
    final localFile = await _copyToAppFolder(_selectedFile!, id);

    final localModel = EvidenceModel(
      firebaseId: id,
      caseId: widget.caseId,
      firebaseCaseId: _cloudCaseId,
      filePath: localFile.path, // local until uploaded
      type: typeController.text.trim().isEmpty ? 'document' : typeController.text.trim(),
      uploadedAt: now,
      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      isSynced: false,
    );

    // 1) local first
    final localId = await local_db.EvidenceDB.insertEvidence(localModel);
    if (localId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حفظ الدليل محليًا')),
      );
      return;
    }

    // 2) try upload file + metadata
    try {
      final upload = await EvidenceStorageService.uploadEvidenceFile(
        file: localFile,
        firebaseCaseId: _cloudCaseId,
        documentId: id,
      );

      final cloudModel = localModel.copyWith(filePath: upload.storagePath);

      final uploaded = await EvidenceSupabaseService.upsertEvidence(cloudModel);
      if (uploaded != null) {
        await local_db.EvidenceDB.updateEvidence(uploaded.copyWith(localId: localId, isSynced: true));
        await local_db.EvidenceDB.markEvidenceAsSynced(localId);
      } else {
        _log.w('رفع Metadata فشل - بقي محلي فقط');
      }
    } catch (e, st) {
      _log.e('رفع الدليل فشل (storage أو db)', error: e, stackTrace: st);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الدليل')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة دليل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: const Text('اختيار ملف'),
            ),
            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'الملف: ${p.basename(_selectedFile!.path)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: (typeController.text.isEmpty)
                  ? 'document'
                  : typeController.text,
              decoration: const InputDecoration(
                labelText: 'نوع الدليل',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'document', child: Text('مستند')),
                DropdownMenuItem(value: 'image', child: Text('صورة')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  typeController.text = v;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveEvidence,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الدليل'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
            Text(
              _cloudCaseId.isEmpty
                  ? '⚠ لا يوجد firebaseCaseId — لن يتم السماح بالحفظ لمنع Orphans.'
                  : 'سيتم الحفظ محليًا أولاً ثم محاولة الرفع للسحابة.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}