// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'کلیوورا';

  @override
  String get dashboardGreeting => 'آپ کا کاروباری مرکز';

  @override
  String get navDashboard => 'ڈیش بورڈ';

  @override
  String get navProjects => 'پروجیکٹس';

  @override
  String get navCustomers => 'کلائنٹس';

  @override
  String get navInvoices => 'انوائسز';

  @override
  String get navMore => 'مزید';

  @override
  String get searchWorkspace => 'ورک اسپیس تلاش کریں';

  @override
  String get quickActionClient => 'کلائنٹ';

  @override
  String get quickActionProject => 'پروجیکٹ';

  @override
  String get quickActionInvoice => 'انوائس';

  @override
  String get quickActionTask => 'ٹاسک';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get languageEnglish => 'انگریزی';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get coachMarkStatsTitle => 'آپ کے اعداد و شمار';

  @override
  String get coachMarkStatsBody =>
      'آمدنی، کلائنٹس، پروجیکٹس اور انوائسز یہاں اپ ڈیٹ ہوتے ہیں۔';

  @override
  String get coachMarkQuickTitle => 'فوری اقدامات';

  @override
  String get coachMarkQuickBody =>
      'ایک ٹیپ میں کلائنٹ، پروجیکٹ، انوائس یا ٹاسک شامل کریں۔';

  @override
  String get coachMarkSearchTitle => 'سب کچھ تلاش کریں';

  @override
  String get coachMarkSearchBody =>
      'کلائنٹس، پروجیکٹس، انوائسز اور پیغامات ایک جگہ سے تلاش کریں۔';

  @override
  String get coachMarkDone => 'سمجھ گیا';

  @override
  String get coachMarkNext => 'اگلا';

  @override
  String get offlineBanner =>
      'آپ آف لائن ہیں۔ کنکشن پر تبدیلیاں ہم آہنگ ہوں گی۔';

  @override
  String get taskReminderTitle => 'ٹاسک کی تاریخ';

  @override
  String taskReminderBody(String taskTitle) {
    return '$taskTitle آج واجب الادا ہے';
  }
}
