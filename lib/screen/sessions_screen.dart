import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../model/session_model.dart';
import '../database/sessions_db.dart';
import '../core/session_supabase_service.dart';
import '../core/notification_supabase_service.dart';
import '../core/id.dart';
import '../core/sync_service.dart';
import 'export_sessions_pdf.dart';
import 'verdict_screen.dart';

final logger = Logger();

class SessionsScreen extends StatefulWidget {
  final int caseId;
  final String caseTitle;
  final String? firebaseCaseId;

  const SessionsScreen({
    super.key,
    required this.caseId,
    required this.caseTitle,
    this.firebaseCaseId,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  Future<List<SessionModel>>? _sessions;

  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  SessionModel? editingSession;

  String get _cloudCaseId => (widget.firebaseCaseId ?? '').trim();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _loadSessions() {
    setState(() {
      _sessions = _fetchSessions();
    });
  }

  Future<List<SessionModel>> _readLocalSessions() async {
    // ✅ قاعدة 1: الفلترة دائماً بمعرّف الأب السحابي (firebaseCaseId)
    // نستفيد من الدالة الموجودة لديك حالياً (getSessionsByCaseId مع firebaseCaseId)
    return SessionDB.getSessionsByCaseId(
      widget.caseId,
      firebaseCaseId: widget.firebaseCaseId,
    );
  }

  Future<List<SessionModel>> _fetchSessions() async {
    // ✅ قاعدة 3: منع Orphans — لا نعرض/نضيف جلسات بدون Parent cloud id
    if (_cloudCaseId.isEmpty) return [];

    // ✅ قاعدة 2: Offline-first — اعرض المحلي أولاً
    final localBefore = await _readLocalSessions();

    // ✅ ثم Sync (بدون دمج سحابي + محلي داخل الشاشة)
    try {
      await SyncService.syncAll();
    } catch (e) {
      logger.w('Sync failed (sessions): $e');
    }

    // ✅ بعد المزامنة نعيد قراءة المحلي بنفس الفلتر
    final localAfter = await _readLocalSessions();
    return localAfter.isNotEmpty ? localAfter : localBefore;
  }

  void _showSessionDialog({SessionModel? session}) {
    final theme = Theme.of(context);

    // ✅ منع الإضافة إن لم يوجد firebaseCaseId
    if (_cloudCaseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إضافة جلسة بدون معرف القضية السحابي. ارجع للقضايا وتأكد أنها تمت مزامنتها.'),
        ),
      );
      return;
    }

    if (session != null) {
      editingSession = session;
      dateController.text = session.date;
      timeController.text = session.time;
      locationController.text = session.location;
      notesController.text = session.notes;
    } else {
      editingSession = null;
      dateController.clear();
      timeController.clear();
      locationController.clear();
      notesController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.cardColor,
          title: Text(session == null ? 'إضافة جلسة' : 'تعديل الجلسة'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _customField(dateController, 'تاريخ الجلسة (yyyy-MM-dd)'),
                _customField(timeController, 'وقت الجلسة (HH:mm)'),
                _customField(locationController, 'الموقع'),
                _customField(notesController, 'ملاحظات'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final date = dateController.text.trim();
                final time = timeController.text.trim();
                final location = locationController.text.trim();
                final notes = notesController.text.trim();

                if (date.isEmpty || time.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال التاريخ والوقت')),
                  );
                  return;
                }

                // ✅ UUID محلي للجلسة (إن لم تكن موجودة)
                final sessionCloudId =
                    (editingSession?.firebaseId ?? '').trim().isNotEmpty
                        ? editingSession!.firebaseId!.trim()
                        : generateId();

                final newSession = SessionModel(
                  localId: editingSession?.localId,
                  firebaseId: sessionCloudId,
                  caseId: widget.caseId,
                  firebaseCaseId: _cloudCaseId,
                  date: date,
                  time: time,
                  location: location,
                  notes: notes,
                  isSynced: false,
                );

                try {
                  // 1) حفظ محلي أولاً
                  if (editingSession != null) {
                    await SessionDB.updateSession(
                      newSession.copyWith(isSynced: false),
                    );

                    // 2) تحديث سحابي (إن أمكن)
                    if ((newSession.firebaseId ?? '').trim().isNotEmpty) {
                      await SessionSupabaseService.updateSession(
                        newSession.firebaseId!,
                        newSession.toMapSupabase(),
                      );
                    }
                  } else {
                    // إدراج محلي أولاً (حتى تظهر فوراً)
                    await SessionDB.insertSession(
                      newSession.copyWith(isSynced: false),
                    );

                    // ثم محاولة رفع سحابي (Offline-first)
                    final saved = await SessionSupabaseService.addSession(newSession);
                    if (saved.firebaseId != null && saved.firebaseId!.isNotEmpty) {
                      // حدّث نفس السجل محلياً كمزامن إن كان عندك localId
                      // إذا لم يكن عندك طريقة markByFirebaseId، نتركه Unsynced وسيقوم SyncService بتسويته لاحقاً
                      // لكن الأفضل إذا SessionDB.updateSession يقبل نفس localId (غالباً نعم)
                    }

                    // تذكير (اختياري)
                    try {
                      final parsed = DateFormat('yyyy-MM-dd HH:mm')
                          .parse('${saved.date} ${saved.time}');

                      await NotificationSupabaseService.scheduleSessionReminder(
                        context: context,
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: 'تذكير الجلسة',
                        body: 'لديك جلسة في ${saved.location} - ${saved.date} ${saved.time}',
                        sessionDateTime: parsed,
                      );
                    } catch (e) {
                      logger.w('خطأ في تنسيق التاريخ أو الوقت: $e');
                    }
                  }
                } catch (e, st) {
                  logger.e('Save session failed', error: e, stackTrace: st);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل حفظ الجلسة')),
                  );
                  return;
                }

                if (!mounted) return;
                Navigator.pop(context);
                _loadSessions();
              },
              child: Text('حفظ', style: TextStyle(color: theme.colorScheme.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(SessionModel session) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من حذف هذه الجلسة؟'),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final sid = (session.firebaseId ?? '').trim();
                  if (sid.isNotEmpty) {
                    await SessionSupabaseService.deleteSession(sid);
                  }
                } catch (e) {
                  logger.e('فشل في حذف الجلسة من Supabase: $e');
                }

                if (session.localId != null) {
                  await SessionDB.deleteSession(session.localId!);
                }

                if (!mounted) return;
                Navigator.pop(ctx);
                _loadSessions();
              },
              child: const Text('نعم', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لا'),
            ),
          ],
        );
      },
    );
  }

  Widget _customField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: label.contains('تاريخ') || label.contains('وقت'),
        onTap: () async {
          if (label.contains('تاريخ')) {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (pickedDate != null) {
              controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
            }
          } else if (label.contains('وقت')) {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (pickedTime != null) {
              final now = DateTime.now();
              final dt = DateTime(
                now.year,
                now.month,
                now.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              controller.text = DateFormat('HH:mm').format(dt);
            }
          }
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جلسات: ${widget.caseTitle}')),
      body: FutureBuilder<List<SessionModel>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_cloudCaseId.isEmpty) {
            return const Center(
              child: Text('لا يمكن عرض الجلسات بدون معرف القضية السحابي.'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد جلسات'));
          }

          final sessions = snapshot.data!;
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${s.date} - ${s.time}'),
                  subtitle: Text('الموقع: ${s.location}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.gavel, color: Colors.amber),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VerdictScreen(
                                sessionId: s.localId ?? 0,
                                sessionData: s.date,
                                firebaseSessionId: s.firebaseId,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSessionDialog(session: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(s),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cloudCaseId.isEmpty ? null : () => _showSessionDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة جلسة'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => exportSessionsToPDF(
                  context,
                  widget.caseId,
                  widget.caseTitle,
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
