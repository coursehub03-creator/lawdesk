import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../core/evidence_storage_service.dart';
import '../core/evidence_supabase_service.dart';
import '../core/sync_service.dart';
import '../database/evidence_db.dart';
import '../model/evidence_model.dart';
import 'add_evidence_screen.dart';

class EvidenceScreen extends StatefulWidget {
  final int caseId; // local case id
  final String caseTitle;
  final String? firebaseCaseId; // ✅ parent cloud id

  const EvidenceScreen({
    super.key,
    required this.caseId,
    required this.caseTitle,
    this.firebaseCaseId,
  });

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  Future<List<EvidenceModel>>? _future;

  String get _cloudCaseId => (widget.firebaseCaseId ?? '').trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _fetchOfflineFirst();
    });
  }

  Future<List<EvidenceModel>> _fetchOfflineFirst() async {
    // ✅ بدون parent cloud id لا نعرض الأدلة (منع Orphans + خلط)
    if (_cloudCaseId.isEmpty) return [];

    // تنظيف بيانات قديمة خاطئة (اختياري وآمن)
    try {
      await EvidenceDB.deleteOrphanEvidence();
    } catch (_) {}

    // ✅ local first
    final localBefore = await EvidenceDB.getEvidenceByFirebaseCaseId(_cloudCaseId);

    // sync all (uploads unsynced + imports) if available
    try {
      await SyncService.syncAll();
    } catch (_) {}

    // إذا كانت SyncService لا تستورد الأدلة، نستورد هنا بشكل آمن
    try {
      final remote = await EvidenceSupabaseService.fetchEvidenceByCaseId(_cloudCaseId);

      final localIds = <String>{
        for (final e in localBefore)
          if ((e.firebaseId ?? '').trim().isNotEmpty) (e.firebaseId ?? '').trim(),
      };

      for (final r in remote) {
        final rid = (r.firebaseId ?? '').trim();
        if (rid.isEmpty) continue;
        if (localIds.contains(rid)) continue;

        // اربط محلياً بالقضية الحالية
        final corrected = r.copyWith(
          caseId: widget.caseId,
          firebaseCaseId: _cloudCaseId,
          isSynced: true,
        );
        await EvidenceDB.importEvidenceIfNotExists(corrected);
      }
    } catch (_) {}

    final localAfter = await EvidenceDB.getEvidenceByFirebaseCaseId(_cloudCaseId);
    return localAfter.isNotEmpty ? localAfter : localBefore;
  }

  Future<void> _openEvidence(EvidenceModel e) async {
    try {
      final path = e.filePath;

      // 1) Local file path
      final localFile = File(path);
      if (await localFile.exists()) {
        await OpenFile.open(localFile.path);
        return;
      }

      // 2) Supabase storage path -> signed URL -> download temp -> open
      final signed = await EvidenceStorageService.createSignedUrl(storagePath: path);
      final suggested = path.split('/').isNotEmpty ? path.split('/').last : 'file';

      // Backward compatible: some code may use downloadToTemp
      final downloaded = await EvidenceStorageService.downloadSignedUrlToTemp(
        signedUrl: signed,
        suggestedFileName: suggested,
      );

      await OpenFile.open(downloaded);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الملف: $err')),
      );
    }
  }

  Future<void> _deleteEvidence(EvidenceModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا الدليل؟'),
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

    final fid = (e.firebaseId ?? '').trim();

    // Cloud first (if possible)
    try {
      if (e.isSynced && fid.isNotEmpty) {
        await EvidenceSupabaseService.deleteEvidence(fid);
      }
    } catch (_) {}

    // Local row
    if (e.localId != null) {
      await EvidenceDB.deleteEvidence(e.localId!);
    } else if (fid.isNotEmpty) {
      await EvidenceDB.deleteEvidenceByFirebaseId(fid);
    }

    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الأدلة: ${widget.caseTitle}'),
      ),
      body: _cloudCaseId.isEmpty
          ? const Center(child: Text('لا يمكن عرض الأدلة بدون معرف القضية السحابي.'))
          : FutureBuilder<List<EvidenceModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('لا توجد أدلة'));
                }

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final e = data[i];
                    final desc = (e.description ?? '').trim();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          e.type.toLowerCase() == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                        ),
                        title: Text(desc.isNotEmpty ? desc : 'دليل (${e.type})'),
                        subtitle: Text(e.uploadedAt),
                        onTap: () => _openEvidence(e),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'open') {
                              await _openEvidence(e);
                            } else if (v == 'delete') {
                              await _deleteEvidence(e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('فتح')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cloudCaseId.isEmpty
            ? null
            : () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEvidenceScreen(
                      caseId: widget.caseId,
                      firebaseCaseId: _cloudCaseId,
                    ),
                  ),
                );

                if (created == true) _load();
              },
        icon: const Icon(Icons.add),
        label: const Text('إضافة دليل'),
      ),
    );
  }
}
