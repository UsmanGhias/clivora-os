import 'package:supabase_flutter/supabase_flutter.dart';

/// Monthly Connect credit costs (must match SQL connect_spend_credits).
class ConnectCreditCosts {
  static const proposal = 1;
  static const contact = 1;
  static const publishNeed = 3;
  static const publishProfile = 3;
}

class ConnectCreditSummary {
  const ConnectCreditSummary({
    required this.plan,
    required this.allowance,
    required this.balance,
    required this.periodStart,
    required this.periodEnd,
    required this.legacyUnlimited,
    this.grandfatherUntil,
  });

  final String plan;
  final int allowance;
  final int balance;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool legacyUnlimited;
  final DateTime? grandfatherUntil;

  factory ConnectCreditSummary.fromRow(Map<String, dynamic> row) {
    DateTime? parse(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return ConnectCreditSummary(
      plan: row['plan']?.toString() ?? 'free',
      allowance: (row['allowance'] as num?)?.toInt() ?? 0,
      balance: (row['balance'] as num?)?.toInt() ?? 0,
      periodStart: parse(row['period_start']),
      periodEnd: parse(row['period_end']),
      legacyUnlimited: row['legacy_unlimited'] == true,
      grandfatherUntil: parse(row['grandfather_until']),
    );
  }

  String get label {
    if (legacyUnlimited) {
      final until = grandfatherUntil;
      if (until == null) return 'Unlimited (grandfathered)';
      return 'Unlimited until ${until.toLocal().toIso8601String().split('T').first}';
    }
    return '$balance / $allowance credits';
  }
}

class ConnectCreditException implements Exception {
  ConnectCreditException(this.code, [this.detail]);
  final String code;
  final String? detail;

  String get message {
    switch (code) {
      case 'INSUFFICIENT_CREDITS':
        return 'Not enough Connect credits this month.';
      case 'PROFILE_INCOMPLETE':
        return 'Complete your Connect profile (60%+) and confirm email first.';
      case 'ACTION_NOT_ALLOWED':
        return 'This Connect action is not allowed.';
      case 'DUPLICATE_ACTION':
        return 'That action was already processed.';
      default:
        return detail ?? 'Connect action failed';
    }
  }

  @override
  String toString() => message;
}

ConnectCreditException mapConnectRpcError(Object error) {
  final raw = error is PostgrestException
      ? (error.message)
      : error.toString();
  final upper = raw.toUpperCase();
  for (final code in const [
    'INSUFFICIENT_CREDITS',
    'PROFILE_INCOMPLETE',
    'ACTION_NOT_ALLOWED',
    'DUPLICATE_ACTION',
    'AUTH_REQUIRED',
  ]) {
    if (upper.contains(code)) return ConnectCreditException(code, raw);
  }
  return ConnectCreditException('UNKNOWN', raw);
}
