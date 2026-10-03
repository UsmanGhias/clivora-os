import 'package:home_widget/home_widget.dart';

import '../utils/currency_formatter.dart';

/// Writes dashboard stats into the Android home-screen widget via [home_widget].
abstract final class HomeWidgetService {
  static const widgetName = 'ClivoraStatsWidget';
  static const keyOutstanding = 'outstanding_balance';
  static const keyOverdue = 'overdue_count';

  /// Best-effort update, never throws to callers.
  static Future<void> updateStats({
    required double outstanding,
    required int overdueCount,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        keyOutstanding,
        formatCurrency(outstanding),
      );
      await HomeWidget.saveWidgetData<String>(
        keyOverdue,
        '$overdueCount',
      );
      await HomeWidget.updateWidget(name: widgetName);
    } catch (_) {}
  }
}
