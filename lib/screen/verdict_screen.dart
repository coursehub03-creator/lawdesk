import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../database/verdict_db.dart' as local;
import '../model/verdict_model.dart' as model;
import '../core/verdict_supabase_service.dart';
import '../core/sync_service.dart';

class VerdictScreen extends StatefulWidget {
  final int sessionId;
  final String sessionData;
  final String? firebaseSessionId;

  const VerdictScreen({
    super.key,
    required this.sessionId,
    required this.sessionData,
    this.firebaseSessionId,
  });

  @override
  State<VerdictScreen> createState() => _VerdictScreenState();
}

class _VerdictScreenState extends State<VerdictScreen> {
  List<model.VerdictModel> _verdicts = [];
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadVerdicts();
  }

  
void _loadVerdicts() async {
  final cloudSessionId = (widget.firebaseSessionId ?? '').trim();

  // ✅ منع الخلط/Orphans: إن لم يوجد parent cloud id، لا نعرض شيئاً
  if (cloudSessionId.isEmpty) {
    setState(() {
      _verdicts = [];
    });
    return;
  }

  // ✅ Offline-first: اقرأ المحلي أولاً (مفلتر بالسحابي)
  final localBefore = await local.VerdictDB.getVerdictsByFirebaseSessionId(cloudSessionId);

  setState(() {
    _verdicts = localBefore;
    _controllers.clear();
    for (var verdict in localBefore) {
      if (verdict.localId != null) {
        _controllers[verdict.localId!] = TextEditingController(text: verdict.description);
      }
    }
  });

  // ✅ مزامنة ثم إعادة قراءة المحلي (بدون دمج قائمتي سحابة/محلي في UI)
  try {
    await SyncService.syncAll();
  } catch (_) {}

  final localAfter = await local.VerdictDB.getVerdictsByFirebaseSessionId(cloudSessionId);

  if (!mounted) return;
  setState(() {
    _verdicts = localAfter;
    _controllers.clear();
    for (var verdict in localAfter) {
      if (verdict.localId != null) {
        _controllers[verdict.localId!] = TextEditingController(text: verdict.description);
      }
    }
  });
}


  Future<void> _pickPDF() async {
    if (widget.firebaseSessionId == null || widget.firebaseSessionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ لا يمكن رفع منطوق الحكم بدون ربط الجلسة بالسحابة')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final createdAt = DateTime.now().toIso8601String();

      final verdict = model.VerdictModel(
        localId: null,
        firebaseId: null,
        sessionId: widget.sessionId,
        firebaseSessionId: widget.firebaseSessionId ?? '',
        pdfPath: filePath,
        description: '',
        createdAt: createdAt,
        isSynced: false,
      );

      // حفظ محلي مبدئي
      final localId = await local.VerdictDB.insertVerdict(verdict);

      // رفع إلى السحابة
      final uploaded = await VerdictSupabaseService.addVerdict(verdict);
if (uploaded != null) {
  final localVerdict = verdict.copyWith(firebaseId: uploaded.firebaseId);
  await local.VerdictDB.insertVerdict(localVerdict);
} else {
  await local.VerdictDB.insertVerdict(verdict);
}


      _loadVerdicts();
    }
  }

  Future<void> _saveDescription(int verdictId, String newDescription) async {
    final verdict = _verdicts.firstWhere((v) => v.localId == verdictId);
    await local.VerdictDB.updateDescription(verdictId, newDescription);
    if (verdict.firebaseId != null) {
      await VerdictSupabaseService.updateVerdict(verdict.firebaseId!, {
        'description': newDescription,
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الوصف')));
    _loadVerdicts();
  }

  Future<void> _deleteVerdict(int verdictId) async {
    final verdict = _verdicts.firstWhere((v) => v.localId == verdictId);
    if (verdict.firebaseId != null) {
      await VerdictSupabaseService.deleteVerdict(verdict.firebaseId!);
    }
    await local.VerdictDB.deleteVerdictById(verdictId);
    _controllers.remove(verdictId);
    _loadVerdicts();
  }

  Future<void> _openPDF(String filePath) async {
    if (File(filePath).existsSync()) {
      await OpenFile.open(filePath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملف غير موجود أو تم حذفه')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('منطوق الحكم')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickPDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('رفع منطوق الحكم PDF'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _verdicts.length,
                itemBuilder: (context, index) {
                  final verdict = _verdicts[index];
                  final controller = _controllers[verdict.localId]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            File(verdict.pdfPath).uri.pathSegments.last,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'الوصف',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _saveDescription(
                                  verdict.localId!,
                                  controller.text,
                                ),
                                icon: const Icon(Icons.save),
                                label: const Text('حفظ'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _openPDF(verdict.pdfPath),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('فتح الملف'),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteVerdict(verdict.localId!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
