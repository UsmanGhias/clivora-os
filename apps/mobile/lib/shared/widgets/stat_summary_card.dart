import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';

class StatSummaryCard extends StatelessWidget {
  const StatSummaryCard({
    super.key,
    required this.items,
  });

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? ClivoraColors.borderLight
              : ClivoraColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: ClivoraColors.borderLight,
              ),
            Expanded(child: _StatColumn(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class StatItem {
  const StatItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.item});

  final StatItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 18, color: item.iconColor ?? ClivoraColors.primary),
          const SizedBox(height: 6),
        ],
        Text(
          item.value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: item.valueColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          item.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0.3,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
