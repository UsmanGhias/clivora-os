import 'package:flutter/material.dart';

import '../../shared/widgets/clivora_scaffold.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.updated,
    required this.body,
  });

  final String title;
  final String updated;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ClivoraScaffold(
      title: title,
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(updated, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}
