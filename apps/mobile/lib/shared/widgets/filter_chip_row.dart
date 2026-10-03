import 'package:flutter/material.dart';

import '../../core/theme/clivora_tokens.dart';
import '../../core/theme/theme_context.dart';

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.clivoraColors;
    final layout = context.clivoraLayout;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: ClivoraSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(layout.chipRadius),
              child: AnimatedContainer(
                duration: ClivoraDurations.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? semantic.chipSelectedBg : semantic.chipBg,
                  borderRadius: BorderRadius.circular(layout.chipRadius),
                  border: Border.all(
                    color: isSelected
                        ? semantic.chipSelectedBorder
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _label(option),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? semantic.brand
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(String key) {
    switch (key) {
      case 'all':
        return 'All';
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'draft':
        return 'Draft';
      case 'sent':
        return 'Sent';
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      case 'outstanding':
        return 'Outstanding';
      case 'pending':
        return 'Pending';
      default:
        return key[0].toUpperCase() + key.substring(1);
    }
  }
}
