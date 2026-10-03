import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_prefs_service.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Per-category notification toggles (Messages, Billing, Contracts, Team).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _messages = true;
  bool _billing = true;
  bool _contracts = true;
  bool _team = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(notificationPrefsServiceProvider);
    final messages = await prefs.messagesEnabled();
    final billing = await prefs.billingEnabled();
    final contracts = await prefs.contractsEnabled();
    final team = await prefs.teamEnabled();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _billing = billing;
      _contracts = contracts;
      _team = team;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.read(notificationPrefsServiceProvider);
    return ClivoraScaffold(
      title: 'Notifications',
      showBackButton: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose which alerts you want to receive.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Messages notifications',
                  child: SwitchListTile(
                    title: const Text('Messages'),
                    subtitle: const Text('Chat and invite alerts'),
                    value: _messages,
                    onChanged: (v) async {
                      await prefs.setMessages(v);
                      setState(() => _messages = v);
                    },
                  ),
                ),
                Semantics(
                  label: 'Billing notifications',
                  child: SwitchListTile(
                    title: const Text('Billing'),
                    subtitle: const Text('Invoices, quotes, and payments'),
                    value: _billing,
                    onChanged: (v) async {
                      await prefs.setBilling(v);
                      setState(() => _billing = v);
                    },
                  ),
                ),
                Semantics(
                  label: 'Contracts notifications',
                  child: SwitchListTile(
                    title: const Text('Contracts'),
                    subtitle: const Text('Signature and agreement updates'),
                    value: _contracts,
                    onChanged: (v) async {
                      await prefs.setContracts(v);
                      setState(() => _contracts = v);
                    },
                  ),
                ),
                Semantics(
                  label: 'Team notifications',
                  child: SwitchListTile(
                    title: const Text('Team'),
                    subtitle: const Text('Team invites and collaboration'),
                    value: _team,
                    onChanged: (v) async {
                      await prefs.setTeam(v);
                      setState(() => _team = v);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
