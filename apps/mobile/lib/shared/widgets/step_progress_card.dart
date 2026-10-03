import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';

class StepProgressCard extends StatelessWidget {
  const StepProgressCard({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.nextLabel,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: ClivoraColors.primaryLight,
                      color: ClivoraColors.primary,
                    ),
                    Text(
                      '$currentStep of $totalSteps',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ClivoraColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next: $nextLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ClivoraColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: ClivoraColors.primaryLight,
              color: ClivoraColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ClivoraFieldLabel extends StatelessWidget {
  const ClivoraFieldLabel({
    super.key,
    required this.label,
    this.required = false,
    this.trailing,
  });

  final String label;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ClivoraColors.labelGray,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: ClivoraColors.errorRed)),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Mockup-aligned field: uppercase label + rounded input with teal icon well.
class ClivoraTextField extends StatelessWidget {
  const ClivoraTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.trailing,
    this.prefixIcon,
    this.readOnly = false,
    this.onTap,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final IconData? prefixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          ClivoraFieldLabel(
            label: label!,
            required: required,
            trailing: trailing,
          ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: prefixIcon != null ? 12 : 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 10, right: 8),
                    child: _IconWell(icon: prefixIcon!),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 40),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: ClivoraColors.primary, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? ClivoraColors.darkBorder : ClivoraColors.borderLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ClivoraColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: ClivoraColors.primary),
    );
  }
}
