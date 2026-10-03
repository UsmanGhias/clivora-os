import 'package:flutter/material.dart';

/// Shared outlined field decoration for CRM create/edit dialogs.
InputDecoration clivoraDialogFieldDecoration(
  BuildContext context,
  String label, {
  String? hintText,
}) {
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    filled: false,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

/// Vertical gap between dialog form fields (keeps labels from merging).
const double kDialogFieldGap = 14;

/// Wraps [children] with [kDialogFieldGap] between each non-null widget.
List<Widget> spacedDialogFields(List<Widget> children) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(const SizedBox(height: kDialogFieldGap));
    out.add(children[i]);
  }
  return out;
}
