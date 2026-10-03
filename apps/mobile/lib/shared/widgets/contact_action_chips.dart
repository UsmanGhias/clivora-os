import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/clivora_colors.dart';

/// One-tap call, email, and WhatsApp actions for a customer row.
class ContactActionChips extends StatelessWidget {
  const ContactActionChips({
    super.key,
    required this.phone,
    required this.email,
    this.whatsapp,
  });

  final String phone;
  final String email;
  final String? whatsapp;

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ClivoraColors.chipBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: ClivoraColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ClivoraColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (phone.isNotEmpty) {
      chips.add(_pill(
        icon: Icons.phone_outlined,
        label: 'Call',
        onTap: () => _open(Uri(scheme: 'tel', path: phone)),
      ));
    }
    if (email.isNotEmpty) {
      chips.add(_pill(
        icon: Icons.email_outlined,
        label: 'Email',
        onTap: () => _open(Uri(scheme: 'mailto', path: email)),
      ));
    }
    final wa = (whatsapp ?? phone).replaceAll(RegExp(r'[^\d+]'), '');
    if (wa.isNotEmpty) {
      chips.add(_pill(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        onTap: () => _open(Uri.parse('https://wa.me/$wa')),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }
}
