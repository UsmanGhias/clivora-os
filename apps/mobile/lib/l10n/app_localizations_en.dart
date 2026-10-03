// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CLIVORA';

  @override
  String get dashboardGreeting => 'Your business command center';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navProjects => 'Projects';

  @override
  String get navCustomers => 'Clients';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navMore => 'More';

  @override
  String get searchWorkspace => 'Search workspace';

  @override
  String get quickActionClient => 'Client';

  @override
  String get quickActionProject => 'Project';

  @override
  String get quickActionInvoice => 'Invoice';

  @override
  String get quickActionTask => 'Task';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'Urdu';

  @override
  String get coachMarkStatsTitle => 'Your stats at a glance';

  @override
  String get coachMarkStatsBody =>
      'Revenue, clients, projects, and invoices update here as you work.';

  @override
  String get coachMarkQuickTitle => 'Quick actions';

  @override
  String get coachMarkQuickBody =>
      'Add a client, project, invoice, or task in one tap.';

  @override
  String get coachMarkSearchTitle => 'Search everything';

  @override
  String get coachMarkSearchBody =>
      'Find clients, projects, invoices, and messages from one place.';

  @override
  String get coachMarkDone => 'Got it';

  @override
  String get coachMarkNext => 'Next';

  @override
  String get offlineBanner =>
      'You are offline. Changes will sync when connected.';

  @override
  String get taskReminderTitle => 'Task due';

  @override
  String taskReminderBody(String taskTitle) {
    return '$taskTitle is due today';
  }
}
