import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../model/verdict_model.dart';
import '../database/verdict_db.dart' as local;
import '../core/verdict_supabase_service.dart';
import '../core/id.dart';

class AddVerdictScreen extends StatefulWidget {
  final int sessionId;
  final String? firebaseSessionId;

  const AddVerdictScreen({
    super.key,
    required this.sessionId,
    this.firebaseSessionId,
  });

  @override
  State<AddVerdictScreen> createState() => _AddVerdictScreenState();
}

class _AddVerdictScreenState extends State<AddVerdictScreen> {
  final descriptionController = TextEditingController();
  File? selectedPDF;

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedPDF = File(result.files.single.path!);
      });
    }
  }

  
Future<void> _saveVerdict() async {
  if (selectedPDF == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يرجى اختيار ملف PDF')),
    );
    return;
  }

  // ✅ قاعدة 3: منع Orphans (لا Verdict بدون parent cloud id)
  final firebaseSessionId = (widget.firebaseSessionId ?? '').trim();
  if (firebaseSessionId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يمكن إضافة منطوق حكم بدون معرف الجلسة السحابي')),
    );
    return;
  }

  final description = descriptionController.text.trim();
  final filePath = selectedPDF!.path;
  final createdAt = DateTime.now().toIso8601String();

  // ✅ UUID محلي/سحابي موحّد
  final verdictId = generateId();

  // 1) حفظ محلي أولاً (Offline-first)
  final localVerdict = VerdictModel(
    localId: null,
    firebaseId: verdictId,
    sessionId: widget.sessionId,
    firebaseSessionId: firebaseSessionId,
    pdfPath: filePath,
    description: description,
    createdAt: createdAt,
    isSynced: false,
  );

  final localId = await local.VerdictDB.insertVerdict(localVerdict);

  // 2) محاولة رفع للسحابة بنفس id (upsert)
  final uploaded = await VerdictSupabaseService.addVerdict(localVerdict);

  if (uploaded != null && localId != -1) {
    await local.VerdictDB.updateVerdict(
      localVerdict.copyWith(localId: localId, isSynced: true),
    );
    await local.VerdictDB.markVerdictAsSynced(localId);
  }

  if (!mounted) return;
  Navigator.pop(context, true);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة منطوق حكم')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickPDF,
              icon: const Icon(Icons.attach_file),
              label: const Text('اختيار ملف PDF'),
            ),
            const SizedBox(height: 10),
            if (selectedPDF != null)
              Text(
                selectedPDF!.path.split('/').last,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف منطوق الحكم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveVerdict,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
