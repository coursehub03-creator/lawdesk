import 'package:flutter/material.dart';

import 'add_witness_form.dart';

class AddWitnessScreen extends StatelessWidget {
  final int caseId;
  final String firebaseCaseId;

  const AddWitnessScreen({
    super.key,
    required this.caseId,
    required this.firebaseCaseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة شاهد')),
      body: AddWitnessForm(caseId: caseId, firebaseCaseId: firebaseCaseId),
    );
  }
}
