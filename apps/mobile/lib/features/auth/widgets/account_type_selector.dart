import 'package:flutter/material.dart';

import '../../../core/auth/user_roles.dart';
import '../../../core/theme/clivora_colors.dart';

/// Freelancer vs Client role picker with checkmark, used on login and signup.
class AccountTypeSelector extends StatelessWidget {
  const AccountTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am using Clivora as a',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                title: 'Freelancer',
                subtitle: compact ? 'Run your business' : 'Manage clients, projects & invoices',
                icon: Icons.work_outline_rounded,
                accent: ClivoraColors.primary,
                selected: selected == kAccountFreelancer,
                compact: compact,
                onTap: () => onChanged(kAccountFreelancer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleOption(
                title: 'Client',
                subtitle: compact ? 'Track shared work' : 'View projects, hours & updates',
                icon: Icons.visibility_outlined,
                accent: ClivoraColors.clientAccent,
                selected: selected == kAccountClient,
                compact: compact,
                onTap: () => onChanged(kAccountClient),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.08) : Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? accent : ClivoraColors.textSecondary, size: 22),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accent : ClivoraColors.labelGray,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? accent : ClivoraColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 11 : 12,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
