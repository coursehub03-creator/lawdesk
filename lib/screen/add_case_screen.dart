import 'package:flutter/material.dart';
import '../database/cases_db.dart' as db;
import '../model/case_model.dart'; // يحتوي على الكلاس الصحيح CaseModel
import '../core/case_supabase_service.dart';
import '../core/id.dart';

class AddCaseScreen extends StatefulWidget {
  /// عند التعديل نمرّر القضية هنا (نفس شاشة الإضافة).
  final CaseModel? caseToEdit;
  final int clientId;
  final String? firebaseClientId;

  const AddCaseScreen({
    super.key,
    required this.clientId,
    this.firebaseClientId,
    this.caseToEdit,
  });

  bool get isEdit => caseToEdit != null;

  @override
  State<AddCaseScreen> createState() => _AddCaseScreenState();
}

class _AddCaseScreenState extends State<AddCaseScreen> {
  @override
  void initState() {
    super.initState();
    final c = widget.caseToEdit;
    if (c != null) {
      titleController.text = c.title;
      fileNumberController.text = c.fileNumber;
      caseTypeController.text = c.caseType ?? '';
      courtController.text = c.court ?? '';
      statusController.text = c.status;
      startDateController.text = c.startDate ?? '';
      notesController.text = c.notes ?? '';
    }
  }

  final titleController = TextEditingController();
  final fileNumberController = TextEditingController();
  final caseTypeController = TextEditingController();
  final courtController = TextEditingController();
  final statusController = TextEditingController();
  final startDateController = TextEditingController();
  final notesController = TextEditingController();

  void saveCase() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال عنوان القضية')),
      );
      return;
    }

    
final isEdit = widget.isEdit;
final existing = widget.caseToEdit;

final caseModel = CaseModel(
  localId: isEdit ? existing!.localId : null,
  // ✅ في التعديل نحتفظ بنفس id، وفي الإضافة نولّد id جديد.
  firebaseId: isEdit ? existing!.firebaseId : generateId(),
  title: titleController.text.trim(),
  fileNumber: fileNumberController.text.trim(),
  status: statusController.text.trim(),
  caseType: caseTypeController.text.trim().isEmpty ? null : caseTypeController.text.trim(),
  court: courtController.text.trim().isEmpty ? null : courtController.text.trim(),
  startDate: startDateController.text.trim().isEmpty ? null : startDateController.text.trim(),
  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
  clientId: widget.clientId,
  firebaseClientId: widget.firebaseClientId,
  isSynced: false,
);

// التخزين في SQLite أولاً كـ Unsynced// التخزين في SQLite أولاً كـ Unsynced
    final int localId;
    if (widget.isEdit && caseModel.localId != null) {
      localId = caseModel.localId!;
      await db.CaseDB.updateCase(caseModel.copyWith(localId: localId, isSynced: false));
    } else {
      localId = await db.CaseDB.insertCase(caseModel.copyWith(isSynced: false));
    }

    // ✅ محاولة رفع إلى Supabase. إذا كان firebaseClientId مفقود سنتركها Unsynced
    // وسيتم رفعها لاحقاً بعد مزامنة العميل (SyncService) عند توفر id العميل.
    if ((widget.firebaseClientId ?? '').trim().isNotEmpty) {
      final uploadedCase = await CaseSupabaseService.addCase(caseModel);

      if (uploadedCase != null) {
        // ✅ لا نُدخل مرة ثانية: نحدّث نفس السجل المحلي بالـ firebaseId + isSynced
        await db.CaseDB.updateCase(uploadedCase.copyWith(localId: localId, isSynced: true));
        await db.CaseDB.markCaseAsSynced(localId);
      } else {
        debugPrint('⚠ فشل في رفع القضية إلى Supabase');
      }
    } else {
      debugPrint('⚠ لم يتم رفع القضية الآن لأن معرف العميل السحابي مفقود. ستُرفع لاحقاً عبر المزامنة.');
    }

    if (localId != -1) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(widget.isEdit ? 'تم تعديل القضية بنجاح' : 'تمت إضافة القضية بنجاح'),
    ),
  );

  // ✅ هذا هو الحل: نرجّع true للشاشة السابقة لتعمل _loadCases تلقائياً
  Navigator.pop(context, true);
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('فشل في إضافة القضية')),
  );
}

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إضافة قضية جديدة'),
        backgroundColor: const Color(0xFF1C2A3A),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.05,
            child: Center(
              child: Image.asset('assets/images/logo_icon.png', width: 250),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInputField(titleController, 'عنوان القضية'),
                _buildInputField(fileNumberController, 'رقم الملف'),
                _buildInputField(caseTypeController, 'نوع القضية'),
                _buildInputField(courtController, 'المحكمة'),
                _buildInputField(statusController, 'الحالة'),
                _buildInputField(startDateController, 'تاريخ البدء'),
                _buildInputField(notesController, 'ملاحظات'),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  onPressed: saveCase,
                  child: const Text(
                    'حفظ',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          filled: true,
          fillColor: const Color(0xFF1C2A3A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
