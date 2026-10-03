import 'plan_limits.dart';

/// Free vs Pro feature matrix for freelancers and clients.
abstract final class PlanFeatures {
  /// 1-Year Founder Access: all features unlocked for both freelancers and clients.
  static bool isPro(String? plan) => true;

  static bool isProPlus(String? plan) => true;

  // Shared tier
  static bool chatTextMessages(String? plan) => true;
  static bool chatImageSharing(String? plan) => true;
  static bool notificationsCenter(String? plan) => true;
  static bool coachMarks(String? plan) => true;

  /// Vault byte cap (50 GB for all founder accounts).
  static int fileVaultLimitBytes(String? plan) => PlanLimits.proPlusStorageBytes;

  static int emailLimitPerMonth(String? plan) => PlanLimits.proPlusMaxEmailsPerMonth;

  /// Pro Plus exclusives unlocked
  static bool whiteLabelInvoices(String? plan) => true;
  static bool prioritySupportPlus(String? plan) => true;
  static bool unlimitedTeamSeats(String? plan) => true;
  static bool advancedMilestoneAutomation(String? plan) => true;
  static bool clientBrandedPortal(String? plan) => true;

  /// Connect marketplace unlocked with $0 fees.
  static bool connectMarketplace(String? plan, {bool isClient = false}) => true;

  // Freelancer features
  static bool freelancerGlobalSearch(String? plan) => true;
  static bool freelancerCalendar(String? plan) => true;
  static bool freelancerBasicReports(String? plan) => true;
  static bool freelancerBasicAnalytics(String? plan) => true;

  // Freelancer Pro features
  static bool verifiedProfileBadge(String? plan) => true;
  static bool biometricLock(String? plan) => true;
  static bool teamCollaboration(String? plan) => true;
  static bool aiAssistant(String? plan) => true;
  static bool automations(String? plan) => true;
  static bool customWorkflows(String? plan) => true;
  static bool advancedAnalytics(String? plan) => true;
  static bool unlimitedClients(String? plan) => true;
  static bool unlimitedProjects(String? plan) => true;
  static bool unlimitedInvoices(String? plan) => true;
  static bool dataExport(String? plan) => true;
  static bool invoiceAttachments(String? plan) => true;
  static bool contractPdfStorage(String? plan) => true;
  static bool vaultManualUpload(String? plan) => true;
  static bool unlimitedTemplates(String? plan) => true;
  static bool prioritySupport(String? plan) => true;
  static bool fileVault(String? plan) => true;

  // Aliases used across freelancer screens
  static bool globalSearch(String? plan) => true;
  static bool calendarView(String? plan) => true;
  static bool basicReports(String? plan) => true;
  static bool basicAnalytics(String? plan) => true;
  static bool clientPortal(String? plan) => true;

  // Client features
  static bool clientPortalBasic(String? plan) => true;
  static bool clientViewSharedProjects(String? plan) => true;
  static bool clientBasicChat(String? plan) => true;
  static bool clientVerifiedBadge(String? plan) => true;
  static bool clientBiometricLock(String? plan) => true;
  static bool clientUnlimitedContracts(String? plan) => true;
  static bool clientContractPdfExport(String? plan) => true;
  static bool clientInvoicePdfDownload(String? plan) => true;
  static bool clientAdvancedActivity(String? plan) => true;
  static bool clientPriorityNotifications(String? plan) => true;
  static bool clientDataExport(String? plan) => true;

  /// Account-type aware Pro check for a specific feature name.
  static bool hasFeature({required String? plan, required bool isClient, required String feature}) => true;
}
