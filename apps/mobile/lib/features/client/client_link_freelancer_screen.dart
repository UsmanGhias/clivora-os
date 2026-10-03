import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/freelancer_link_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../shared/widgets/clivora_scaffold.dart';

/// Client adds / invites their freelancer by email.
class ClientLinkFreelancerScreen extends ConsumerStatefulWidget {
  const ClientLinkFreelancerScreen({super.key});

  @override
  ConsumerState<ClientLinkFreelancerScreen> createState() => _ClientLinkFreelancerScreenState();
}

class _ClientLinkFreelancerScreenState extends ConsumerState<ClientLinkFreelancerScreen> {
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final error = await ref.read(freelancerLinkServiceProvider).linkFreelancerByEmail(
            _emailController.text,
          );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.link_rounded, color: ClivoraColors.clientAccent, size: 36),
          title: const Text('Request sent'),
          content: const Text(
            'Your freelancer will receive an in-app message and notification. '
            'Once they share a project with your email, it will appear in your portal.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClivoraScaffold(
      title: 'Add Freelancer',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ClivoraColors.clientAccentLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClivoraColors.clientAccent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connect with your freelancer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Enter the email they use on CLIVORA. They\'ll get a link request and can share projects with you.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'FREELANCER EMAIL',
              hintText: 'freelancer@business.com',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: ClivoraColors.clientAccent),
            child: _sending
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send connection request'),
          ),
        ],
      ),
    );
  }
}
