import 'package:flutter/material.dart';
import '../database/sessions_db.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
//import '../model/session_model.dart';

Future<void> exportSessionsToPDF(BuildContext context, int caseId, String caseTitle) async {
  final sessions = await SessionDB.getSessionsByCaseId(caseId);

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      build: (pw.Context context) => [
        pw.Text('قائمة الجلسات للقضية: $caseTitle', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        ...sessions.map((s) => pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('التاريخ: ${s.date} - ${s.time}'),
                  pw.Text('المحكمة: ${s.location}'),
                  pw.Text('الحالة: ${s.notes}'),
                  pw.Text('ملاحظات: ${s.notes}'),
                ],
              ),
            )),
      ],
    ),
  );

  final outputDir = await getTemporaryDirectory();
  final file = File("${outputDir.path}/جلسات_${caseTitle.replaceAll(' ', '_')}.pdf");
  await file.writeAsBytes(await pdf.save());

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الملف في: ${file.path}')));
}
