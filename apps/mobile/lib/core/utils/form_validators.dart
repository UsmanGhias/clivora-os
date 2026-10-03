import 'package:flutter/material.dart';

abstract final class FormValidators {
  static String? requiredField(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? email(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Email is required' : null;
    }
    final pattern = RegExp(r'^[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    final digits = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? postalCode(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Postal code is required' : null;
    }
    if (trimmed.length < 3) {
      return 'Enter a valid postal code';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'Field'}) {
    if (value == null || value.trim().length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }
}

void showFormError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
