import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CLIVORA'**
  String get appTitle;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Your business command center'**
  String get dashboardGreeting;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get navCustomers;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @searchWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Search workspace'**
  String get searchWorkspace;

  /// No description provided for @quickActionClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get quickActionClient;

  /// No description provided for @quickActionProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get quickActionProject;

  /// No description provided for @quickActionInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get quickActionInvoice;

  /// No description provided for @quickActionTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get quickActionTask;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUrdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get languageUrdu;

  /// No description provided for @coachMarkStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your stats at a glance'**
  String get coachMarkStatsTitle;

  /// No description provided for @coachMarkStatsBody.
  ///
  /// In en, this message translates to:
  /// **'Revenue, clients, projects, and invoices update here as you work.'**
  String get coachMarkStatsBody;

  /// No description provided for @coachMarkQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get coachMarkQuickTitle;

  /// No description provided for @coachMarkQuickBody.
  ///
  /// In en, this message translates to:
  /// **'Add a client, project, invoice, or task in one tap.'**
  String get coachMarkQuickBody;

  /// No description provided for @coachMarkSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search everything'**
  String get coachMarkSearchTitle;

  /// No description provided for @coachMarkSearchBody.
  ///
  /// In en, this message translates to:
  /// **'Find clients, projects, invoices, and messages from one place.'**
  String get coachMarkSearchBody;

  /// No description provided for @coachMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get coachMarkDone;

  /// No description provided for @coachMarkNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get coachMarkNext;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Changes will sync when connected.'**
  String get offlineBanner;

  /// No description provided for @taskReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Task due'**
  String get taskReminderTitle;

  /// No description provided for @taskReminderBody.
  ///
  /// In en, this message translates to:
  /// **'{taskTitle} is due today'**
  String taskReminderBody(String taskTitle);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
