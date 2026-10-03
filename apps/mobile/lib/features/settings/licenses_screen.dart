import 'package:flutter/material.dart';

import '../../shared/widgets/clivora_scaffold.dart';

/// Open-source licenses for all bundled packages.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ClivoraScaffold(
      title: 'Open Source Licenses',
      showBackButton: true,
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'CLIVORA is built with open-source software. Tap a package below to read its license.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('View all licenses'),
            subtitle: const Text('Flutter, Drift, Supabase, and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'CLIVORA',
                applicationVersion: '2.5.0',
                applicationLegalese: 'Copyright CODCrafters and contributors. Licensed under AGPL-3.0.',
              );
            },
          ),
        ],
      ),
    );
  }
}
