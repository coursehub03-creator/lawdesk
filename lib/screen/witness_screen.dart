import 'package:flutter/material.dart';

import '../database/witness_db.dart';
import '../model/witness_model.dart';
import 'add_witness_screen.dart';

class WitnessScreen extends StatefulWidget {
  final int caseId;
  final String? firebaseCaseId;

  const WitnessScreen({
    super.key,
    required this.caseId,
    required this.firebaseCaseId,
  });

  @override
  State<WitnessScreen> createState() => _WitnessScreenState();
}

class _WitnessScreenState extends State<WitnessScreen> {
  List<WitnessModel> _witnesses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    if (widget.firebaseCaseId == null || widget.firebaseCaseId!.isEmpty) {
      setState(() {
        _witnesses = const [];
        _loading = false;
      });
      return;
    }

    final list = await WitnessDB.getWitnessesByFirebaseCaseId(widget.firebaseCaseId!);
    setState(() {
      _witnesses = list;
      _loading = false;
    });
  }

  Future<void> _deleteLocal(int localId) async {
    await WitnessDB.deleteByLocalId(localId);
    await _load();
  }

  Future<void> _editWitness(WitnessModel witness) async {
    final nameCtrl = TextEditingController(text: witness.name);
    final roleCtrl = TextEditingController(text: witness.role);
    final notesCtrl = TextEditingController(text: witness.notes ?? '');
    final phoneCtrl = TextEditingController(text: witness.phone ?? '');
    final addressCtrl = TextEditingController(text: witness.address ?? '');
    final relationshipCtrl = TextEditingController(text: witness.relationship ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل الشاهد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'الصفة/الدور'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationshipCtrl,
                  decoration: const InputDecoration(labelText: 'صلة القرابة/العلاقة'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || roleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الاسم والصفة مطلوبان')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (witness.localId == null) return;

    final updated = witness.copyWith(
      name: nameCtrl.text.trim(),
      role: roleCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      relationship: relationshipCtrl.text.trim().isEmpty ? null : relationshipCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      isSynced: false,
    );

                        // updateWitness expects a WitnessModel (not (localId, model)).
                        await WitnessDB.updateWitness(
                          updated.copyWith(localId: witness.localId),
                        );
    await _load();
  }

  void _showWitnessDetails(WitnessModel witness) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        Widget row(String label, String? value) {
          if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(value)),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  witness.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                row('الصفة', witness.role),
                row('الهاتف', witness.phone),
                row('العنوان', witness.address),
                row('العلاقة', witness.relationship),
                row('ملاحظات', witness.notes),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('تعديل'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _editWitness(witness);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                        onPressed: witness.localId == null
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await _deleteLocal(witness.localId!);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCloudCase = widget.firebaseCaseId != null && widget.firebaseCaseId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الشهود'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: hasCloudCase
            ? () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddWitnessScreen(
                      caseId: widget.caseId,
                      firebaseCaseId: widget.firebaseCaseId!,
                    ),
                  ),
                );
                if (added == true) {
                  await _load();
                }
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لا يمكن إضافة شاهد قبل مزامنة القضية إلى السحابة.'),
                  ),
                );
              },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasCloudCase
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('هذه القضية غير متزامنة بعد. قم بمزامنة القضية أولاً ثم أضف الشهود.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _witnesses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final w = _witnesses[index];
                      return ListTile(
                        title: Text(w.name),
                        subtitle: Text(w.role),
                        onTap: () => _showWitnessDetails(w),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editWitness(w),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: w.localId == null ? null : () => _deleteLocal(w.localId!),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
