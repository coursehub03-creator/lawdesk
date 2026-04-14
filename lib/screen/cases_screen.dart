import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../model/case_model.dart';
import '../core/case_supabase_service.dart';
import '../database/cases_db.dart';
import '../core/sync_service.dart';
import 'add_case_screen.dart';
import 'sessions_screen.dart';
import 'evidence_screen.dart';
import 'witness_screen.dart';

class CasesScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  final String? firebaseClientId;

  const CasesScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.firebaseClientId,
  });

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final Logger _logger = Logger();
  List<CaseModel> cases = [];
  bool _isLoading = true;

  String get _cloudClientId => (widget.firebaseClientId ?? '').trim();

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<List<CaseModel>> _readLocalCases() async {
    // ✅ الفلترة الصحيحة لمنع الخلط:
    // إذا لدينا معرّف سحابي للعميل -> فلترة حسب firebase_client_id
    if (_cloudClientId.isNotEmpty) {
      return await CaseDB.getCasesByFirebaseClientId(_cloudClientId);
    }

    // fallback (حالة عميل لم يُزامَن بعد)
    return await CaseDB.getCasesByClientId(widget.clientId);
  }

  Future<void> _loadCases() async {
    try {
      // ✅ Offline-first: اعرض المحلي فوراً
      final localBefore = await _readLocalCases();
      if (mounted) {
        setState(() {
          cases = localBefore;
          _isLoading = false;
        });
      }

      // ✅ ثم حاول مزامنة/استيراد من السحابة (إذا عندنا client cloud id)
      if (_cloudClientId.isNotEmpty) {
        await SyncService.syncAll();
        final localAfter = await _readLocalCases();

        if (mounted) {
          setState(() {
            cases = localAfter;
          });
        }
      }
    } catch (e, stackTrace) {
      _logger.e("خطأ في تحميل القضايا", error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCase(CaseModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه القضية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // ✅ حذف محلياً أولاً
      if (c.localId != null) {
        await CaseDB.deleteCase(c.localId!);
      }

      // ✅ حذف سحابياً إن وُجد firebaseId
      final cloudId = (c.firebaseId ?? '').trim();
      if (cloudId.isNotEmpty) {
        await CaseSupabaseService.deleteCase(cloudId);
      }

      await _loadCases();
    } catch (e, st) {
      _logger.e("خطأ في حذف القضية", error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف القضية')),
      );
    }
  }

  Future<void> _editCase(CaseModel c) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCaseScreen(
          clientId: widget.clientId,
          firebaseClientId: widget.firebaseClientId,
          caseToEdit: c,
        ),
      ),
    );

    if (updated == true) {
      await _loadCases();
    }
  }

  void _openCaseScreen(String value, CaseModel c) {
    Widget screen;

    if (value == 'sessions') {
      screen = SessionsScreen(
        caseId: c.localId ?? 0,
        caseTitle: c.title,
        firebaseCaseId: c.firebaseId,
      );
    } else if (value == 'evidence') {
      screen = EvidenceScreen(
        caseId: c.localId ?? 0,
        caseTitle: c.title,
        firebaseCaseId: c.firebaseId,
      );
    } else {
      // witnesses
      screen = WitnessScreen(
        caseId: c.localId ?? 0,
        firebaseCaseId: c.firebaseId,
      );
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
        title: Text(
          'قضايا ${widget.clientName}',
          style: theme.appBarTheme.titleTextStyle ??
              const TextStyle(color: Colors.white),
        ),
        iconTheme: theme.iconTheme.copyWith(color: Colors.white),
        
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.06,
            child: Center(
              child: Image.asset('assets/images/logo_icon.png', width: 300),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : cases.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد قضايا',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final c = cases[index];

                        return Card(
                          color: theme.cardColor,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              c.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              'رقم الملف: ${c.fileNumber}\nالحالة: ${c.status}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit, color: Colors.white),
                                  onPressed: () => _editCase(c),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _editCase(c);
                                      return;
                                    }

                                    if (value == 'delete') {
                                      await _deleteCase(c);
                                      return;
                                    }

                                    _openCaseScreen(value, c);
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'sessions',
                                      child: Text('عرض الجلسات'),
                                    ),
                                    PopupMenuItem(
                                      value: 'evidence',
                                      child: Text('عرض الأدلة'),
                                    ),
                                    PopupMenuItem(
                                      value: 'witnesses',
                                      child: Text('عرض الشهود'),
                                    ),
                                    PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل القضية'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف القضية'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SessionsScreen(
                                    caseId: c.localId ?? 0,
                                    caseTitle: c.title,
                                    firebaseCaseId: c.firebaseId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: FloatingActionButton.extended(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.black,
          onPressed: () async {
            // ✅ منع إضافة قضية إذا العميل ما عنده cloud id (حتى لا يحصل Orphans وخلط)
            if (_cloudClientId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا يمكن إضافة قضية قبل مزامنة العميل (معرف سحابي غير موجود)'),
                ),
              );
              return;
            }

            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => AddCaseScreen(
                  clientId: widget.clientId,
                  firebaseClientId: widget.firebaseClientId,
                ),
              ),
            );

            if (created == true) {
              await _loadCases();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة قضية'),
        ),
      ),
    );
  }
}
