import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../model/session_model.dart';
import '../database/sessions_db.dart';
import '../core/session_supabase_service.dart';

final logger = Logger();

class AddSessionScreen extends StatefulWidget {
  final int caseId;
  final String? firebaseCaseId;

  const AddSessionScreen({
    super.key,
    required this.caseId,
    this.firebaseCaseId,
  });

  @override
  State<AddSessionScreen> createState() => AddSessionScreenState();
}

class AddSessionScreenState extends State<AddSessionScreen> {
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  void saveSession() async {
    if (dateController.text.trim().isEmpty ||
        timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال التاريخ والوقت')),
      );
      return;
    }

    final firebaseId = widget.firebaseCaseId;
    if (firebaseId == null || firebaseId.isEmpty) {
      logger.w('محاولة رفع جلسة بدون firebaseCaseId!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن رفع الجلسة بدون معرف القضية السحابي'),
        ),
      );
      return;
    }

    SessionModel session = SessionModel(
      localId: null,
      firebaseId: null,
      caseId: widget.caseId,
      firebaseCaseId: firebaseId,
      date: dateController.text.trim(),
      time: timeController.text.trim(),
      location: locationController.text.trim(),
      notes: notesController.text.trim(),
      isSynced: false,
    );

    try {
      logger.t('بيانات الجلسة قبل الإرسال: ${session.toMapSupabase()}');

      // ✅ Online-first + (المسؤولية عن الإدراج/التحديث المحلي داخل الخدمة)
      final saved = await SessionSupabaseService.addSession(session);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.isSynced
                ? 'تم حفظ الجلسة على السحابة والمحلي'
                : 'تم حفظ الجلسة محلياً وسيتم رفعها لاحقاً',
          ),
        ),
      );
    } catch (e, stackTrace) {
      logger.e('فشل في رفع الجلسة', error: e, stackTrace: stackTrace);
      logger.t('StackTrace: $stackTrace');

      // ✅ fallback محلي مرة واحدة فقط
      await SessionDB.insertSession(session.copyWith(isSynced: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ محليًا فقط، فشل في رفع الجلسة')),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة جلسة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildField(dateController, 'تاريخ الجلسة (مثال: 2024-12-31)'),
            _buildField(timeController, 'وقت الجلسة (مثال: 14:00)'),
            _buildField(locationController, 'مكان الجلسة'),
            _buildField(notesController, 'ملاحظات'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveSession,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
